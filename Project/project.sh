#!/bin/bash
# Author           : Wojciech Siwiec s197815....
# Created On       : 13.05.2024
# Last Modified By : Wojciech Siwiec s197815....
# Last Modified On : 13.05.2024
# Version          : 0.5
#
# Description      :
# Opis
#
# Licensed under the MIT License (see LICENSE.txt file in the project root for more details)

# * https://yad-guide.ingk.se/

# nie może być chyba set -e bo yad się psuje
set -uf -o pipefail
LOGS="out.log"
exec 2>>$LOGS

temp_dir=$(mktemp -d)

# declare -a videos
# declare -a audios
declare -a mediaFiles
supported_video_formats=("mp4" "mov" "avi" "webm")
supported_audio_formats=("mp3" "wav" "flac" "ogg")
declare -A media_types=(
    ["video-x-generic-symbolic"]="video"
    ["video"]="video-x-generic-symbolic"
    ["audio-x-generic-symbolic"]="audio"
    ["audio"]="audio-x-generic-symbolic"
)

isInArray() {
    local element=$1
    local array=("${@:2}")
    for e in "${array[@]}"; do
        if [ "$e" == "$element" ]; then
            return 0
        fi
    done
    return 1
}

OPTSTRING=":hv"
while getopts ${OPTSTRING} opt; do
    case ${opt} in
    h)
        echo "help"
        ;;
    v)
        echo "version"
        ;;
    ?)
        echo "Invalid option: -${OPTARG}."
        rm -rf "$temp_dir"
        exit 1
        ;;
    esac
done

addNewFiles() {
    selected_files=$(yad --title="Wybierz pliki" --file-selection --multiple \
        --file-filter="$(
            echo -n "Wideo | "
            for format in "${supported_video_formats[@]}"; do
                echo -n "*.$format "
            done
        )" \
        --file-filter="$(
            echo -n "Audio | "
            for format in "${supported_audio_formats[@]}"; do
                echo -n "*.$format "
            done
        )")

    IFS='|' read -ra ADDR <<<"$selected_files"
    added_file_flag=0
    for i in "${ADDR[@]}"; do
        if [ ! -d "$i" ]; then
            mediaFiles+=("$i")
            added_file_flag=1
        fi
    done
    if [ "$added_file_flag" -ne 1 ]; then
        yad --title="Błąd" --text="Nie wybrano plików wideo." --button=gtk-close:0
    fi
}

# * The `getDetails()` function in the provided shell script is responsible for extracting specific
# * details about a video file. It takes two parameters: the index of the video file in the `mediaFiles`
# * array and the specific detail to retrieve (filename, extension, duration, or format).
getDetails() {
    local file=$1
    local detail=$2
    case $detail in
    filename)
        basename -- "$file" | cut -f 1 -d '.'
        ;;
    extension)
        echo "${file##*.}"
        ;;
    duration)
        duration_seconds=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
        hours=$(echo "$duration_seconds" | awk '{printf "%02d", $1/3600}')
        minutes=$(echo "$duration_seconds" | awk '{printf "%02d", ($1%3600)/60}')
        seconds=$(echo "$duration_seconds" | awk '{printf "%02d", $1%60}')
        echo "$hours:$minutes:$seconds"
        ;;
    format)
        ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$file"
        ;;
    type)
        if ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file" | grep -q .; then
            echo "${media_types["video"]}"
        else
            echo "${media_types["audio"]}"
        fi
        ;;
    esac
}

convert() {
    trap 'cleanup_and_exit' SIGINT
    cleanup_and_exit() {
        echo "Przerwanie konwersji..."
        kill "$ffmpeg_pid" 2>/dev/null
        rm -f ffmpeg_progress.log
        rm -rf "$temp_dir"
        exit 1
    }

    local file=$1
    local target_format

    local format_options=""
    local first=true
    for format in "${supported_video_formats[@]}"; do
        if $first; then
            format_options+="TRUE $format "
            first=false
        else
            format_options+="FALSE $format "
        fi
    done
    # shellcheck disable=SC2086
    target_format=$(yad --title="Wybierz format" \
        --no-selection \
        --width=300 --height=300 \
        --list --radiolist \
        --print-column=2 --separator= \
        --column=Select:BOOL \
        --column=Format:TEXT $format_options)

    if [ $? -eq 1 ]; then
        echo "Cancel button was pressed."
        return
    fi
    echo "Selected format: $target_format"
    local temp_file
    temp_file=$(mktemp --suffix=".${target_format}" --tmpdir="$temp_dir")
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    duration=${duration%.*}
    ffmpeg -i "$file" "$temp_file" -y 2>ffmpeg_progress.log &
    ffmpeg_pid=$!
    local conversion_complete=0
    (
        while kill -0 $ffmpeg_pid 2>/dev/null; do
            current_time=$(grep -oP 'time=\K[\d:.]*' ffmpeg_progress.log | tail -1)
            hours=$(echo "$current_time" | cut -d':' -f1)
            minutes=$(echo "$current_time" | cut -d':' -f2)
            seconds=$(echo "$current_time" | cut -d':' -f3)
            current_seconds=$(echo "$hours*3600 + $minutes*60 + $seconds" | bc)
            progress=$(echo "scale=2; $current_seconds/$duration*100" | bc)
            echo "$progress"
            sleep 1
        done
        echo "# Konwersja zakończona"
        echo "100"
    ) | yad --progress --title="Postęp konwersji" --text="Trwa konwersja pliku..." --percentage=0 --auto-close && conversion_complete=1

    if [ $conversion_complete -ne 1 ]; then
        echo "Konwersja nie została zakończona pomyślnie."
        kill "$ffmpeg_pid" 2>/dev/null
        yad --title="Błąd konwersji" --text="Konwersja nie została zakończona pomyślnie." --button=gtk-close:0
        return
    fi
    local save_path
    save_path=$(yad --file --save --filename="${file%.*}.$target_format")
    if [ -z "$save_path" ]; then
        yad --title="Błąd konwersji" --text="Konwersja nie została zakończona pomyślnie." --button=gtk-close:0
        rm -rf "$temp_dir"
        exit 1
    fi

    mv "$temp_file" "$save_path"
    if ! isInArray "$save_path" "${mediaFiles[@]}"; then
        mediaFiles+=("$save_path")
    fi
    yad --title="Konwersja zakończona" --text="Plik został zapisany" --button=gtk-ok:0
    rm -f ffmpeg_progress.log
}

temp_files=()
composeMenu() {
    changed_files=()
    local composed_file
    composed_file=$(mktemp --suffix=".mp4" --tmpdir="$temp_dir")
    if [ ${#temp_files[@]} -eq 0 ]; then
        for file in "${mediaFiles[@]}"; do
            temp_files+=("$temp_dir/$(basename "$file")")
            cp "$file" "${temp_files[-1]}"
        done
    fi

    local args=()
    for file in "${temp_files[@]}"; do
        filename=$(getDetails "$file" filename)
        duration=$(getDetails "$file" duration)
        type=$(getDetails "$file" type)
        args+=("$file" "$type" "$filename" "$duration")
    done

    local file
    file=$(yad --list \
        --title="Lista wczytanych plików" \
        --width=700 --height=500 \
        --button=gtk-media-play:10 \
        --button=gtk-close:1 \
        --button=gtk-save:4 \
        --button=gtk-apply:6 \
        --button=gtk-undo:8 \
        --button=gtk-edit:0 \
        --column=FILE:HD \
        --column=TYPE:IMG \
        --column=NAME \
        --column=Duration \
        --print-column=1 \
        --separator= \
        "${args[@]}")
    local exit_code=$?

    case $exit_code in
    1)
        return
        ;;
    10)
        if [ "$(getDetails "$composed_file" duration)" = "00:00:00" ]; then
            yad --title="Błąd" --text="You have to make some changes..." --button=gtk-close:0
            composeMenu
        else
            celluloid "$composed_file"
            composeMenu
        fi
        ;;
    4)
        if [ "$(getDetails "$composed_file" duration)" = "00:00:00" ]; then
            yad --title="Błąd" --text="Try applying changes or selecting anything..." --button=gtk-close:0
            composeMenu
        else
            local save_path
            save_path=$(yad --file --save --filename="composed.mp4")
            if [ -z "$save_path" ]; then
                yad --title="Błąd" --text="Nie wybrano ścieżki zapisu." --button=gtk-close:0
                composeMenu
            else
                mv "$composed_file" "$save_path"
                yad --title="Zapisano" --text="Plik został zapisany." --button=gtk-close:0
                composeMenu
            fi
        fi
        ;;
    8)
        for file in "${temp_files[@]}"; do
            rm -f "$file"
        done
        temp_files=()
        composeMenu
        ;;

    0)
        if [ -z "$file" ]; then
            yad --title="Błąd" --text="Nie wybrano pliku." --button=gtk-close:0
            composeMenu
            return
        fi
        if [ "$(getDetails "$file" type)" = "video" ]; then
            editVideo "$file"
        else
            editAudio "$file"
        fi
        composeMenu
        ;;

    esac
}

menu() {
    local args=()
    local index=0

    for file in "${mediaFiles[@]}"; do
        filename=$(getDetails "$file" filename)
        format=$(getDetails "$file" format)
        duration=$(getDetails "$file" duration)
        extension=$(getDetails "$file" extension)
        type=$(getDetails "$file" type)
        args+=("$index" "$type" "$filename" "$extension" "$duration" "$format")
        index=$((index + 1))
    done

    local id
    local exit_code
    id=$(yad --list \
        --title="Lista wczytanych plików" \
        --button=gtk-add:10 \
        --button=gtk-remove:6 \
        --button=gtk-delete:8 \
        --button=gtk-new:2 \
        --button=Convert:4 \
        --button=gtk-media-play:0 \
        --button=gtk-close:1 \
        --width=700 --height=500 \
        --column=ID:HD \
        --column=TYPE:IMG \
        --column=NAME \
        --column=EXT \
        --column=Duration \
        --column=FORMAT \
        --print-column=1 \
        --separator= \
        "${args[@]}")

    exit_code=$?

    if [ "$index" -eq 0 ]; then
        case $exit_code in
        1)
            rm -rf "$temp_dir"
            exit 0
            ;;
        10)
            addNewFiles
            menu
            ;;
        0 | 2 | 4 | 6 | 8)
            yad --title="Błąd" --text="Nie wybrano plików." --button=gtk-close:0
            menu
            ;;

        esac
    else
        case $exit_code in
        0)
            celluloid "${mediaFiles[$id]}"
            # totem "${mediaFiles[$id]}"
            menu
            ;;
        1)
            rm -rf "$temp_dir"
            exit 0
            ;;
        2)
            echo "COMPOSE GO ON"
            composeMenu
            menu
            ;;
        4)
            convert "${mediaFiles[$id]}"
            menu
            ;;
        6)
            mediaFiles=("${mediaFiles[@]:0:$id}" "${mediaFiles[@]:$((id + 1))}")
            menu
            ;;
        8)
            if yad --title="Potwierdź usunięcie" --text="Czy na pewno chcesz usunąć plik?" --button=gtk-yes:0 --button=gtk-no:1; then
                rm -f "${mediaFiles[$id]}"
                mediaFiles=("${mediaFiles[@]:0:$id}" "${mediaFiles[@]:$((id + 1))}")
            fi
            menu
            ;;
        10)
            addNewFiles
            menu
            ;;

        esac
    fi

}

# about() {
#     yad --width=700 --height=500 --title="O programie" --text="Program do konwersji plików wideo" --button=gtk-new:0
#     menu
# }

# about

menu
