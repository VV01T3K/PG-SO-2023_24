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
FFMPEG_LOGS="ffmpeg.log"
echo "" >$LOGS
echo "" >$FFMPEG_LOGS
exec 2>>$LOGS

temp_dir=$(mktemp -d)

declare -a mediaFiles
declare -a realFiles
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
    for file in "${ADDR[@]}"; do
        if [ ! -d "$file" ]; then
            realFiles+=("$file")
            mediaFiles+=("$temp_dir/$(basename "$file")")
            cp "$file" "${mediaFiles[-1]}"
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

play() {
    local file=$1
    local name
    name=$(getDetails "$file" filename)
    local extension="${file##*.}"
    mkdir "./playback"
    cp "$file" "./playback/$name.$extension"
    celluloid "./playback/$name.$extension"
    rm -rf "./playback"
}

editVideo() {
    local file=$1
    local id=$2
    local processed
    local vid
    local reordered_formats=("$(getDetails "$file" extension)")
    for format in "${supported_video_formats[@]}"; do
        if [[ "$format" != "$(getDetails "$file" extension)" ]]; then
            reordered_formats+=("$format")
        fi
    done
    printf -v video_formats "%s\\!" "${reordered_formats[@]}"
    local video_formats=${video_formats%\\!}
    local dane
    dane=$(
        yad --form --title="Single File Edit" --text="Please enter your details:" \
            --button=gtk-save:4 \
            --button=gtk-apply:2 \
            --button=gtk-cancel:1 \
            --field="Name" "$(getDetails "$file" filename)" \
            --field="Format:CB" "$video_formats" \
            --field="Duration:RO" "$(getDetails "$file" duration)" \
            --field="Time [%] to cut from start:SCL" "0:100:1" \
            --field="Time [%] to cut from end:SCL" "0:100:1" \
            --field="Number of loops:NUM" "0..100..1" \
            --field="Watermark Text"
    )

    local exit_code=$?
    case $exit_code in
    2)
        IFS='|' read -ra ADDR <<<"$dane"
        processed=$(processVideo "$file" "${ADDR[1]}" "${ADDR[3]}" "${ADDR[4]}" "${ADDR[5]}" "${ADDR[6]}")
        vid="$temp_dir/${ADDR[0]}.${ADDR[1]}"
        mv "$processed" "$vid"
        mediaFiles[id]="$vid"
        realFiles[id]=""
        yad --title="Przetwarzanie zakończone" --text="Plik został zaktualizowany" --button=gtk-ok:0
        ;;
    4)
        IFS='|' read -ra ADDR <<<"$dane"
        processed=$(processVideo "$file" "${ADDR[1]}" "${ADDR[3]}" "${ADDR[4]}" "${ADDR[5]}" "${ADDR[6]}")
        local save_path
        save_path=$(yad --save --file="$file" --filename="./${ADDR[0]}.${ADDR[1]}")
        if [ -z "$save_path" ]; then
            rm -f "$processed"
            yad --title="Błąd konwersji" --text="Konwersja nie została zakończona pomyślnie." --button=gtk-close:0
        else
            cp "$processed" "$save_path"
            realFiles+=("$save_path")
            local new_file
            new_file="${temp_dir}/$(getDetails "$save_path" filename).${ADDR[1]}"
            if [[ -f "$new_file" ]]; then
                local temp_subdir
                temp_subdir=$(mktemp -d -p "$temp_dir")
                vid="$temp_subdir/${ADDR[0]}.${ADDR[1]}"
                mv "$processed" "$vid"
                new_file="${temp_subdir}/$(getDetails "$save_path" filename).${ADDR[1]}"
                mediaFiles+=("$new_file")
                cp "$vid" "${mediaFiles[-1]}"
            else
                vid="$temp_dir/${ADDR[0]}.${ADDR[1]}"
                mv "$processed" "$vid"
                mediaFiles+=("$new_file")
                cp "$vid" "${mediaFiles[-1]}"
            fi
            yad --title="Przetwarzanie zakończone" --text="Plik został zapisany" --button=gtk-ok:0
        fi
        ;;
    esac
}

processVideo() {
    echo "" >$FFMPEG_LOGS
    local file=$1
    local current_format="${file##*.}"
    local target_format=$2
    local cut_front_percentage=$3
    local cut_back_percentage=$4
    if [ "$(echo "$cut_front_percentage + $cut_back_percentage >= 100" | bc)" -eq 1 ]; then
        yad --title="Błąd" --text="Suma czasów przycięcia nie może być większa niż 100%." --button=gtk-close:0
        return
    fi
    local loop_number=$5
    # local watermark=$6
    local temp_file
    temp_file=$(mktemp --suffix=".$current_format" --tmpdir="$temp_dir")

    # Get the duration of the video in seconds
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")

    # Calculate the cut times based on the duration and percentages
    local cut_front_seconds
    local cut_back_seconds
    local cut_duration
    cut_front_seconds=$(echo "$duration * $cut_front_percentage / 100" | bc -l)
    cut_back_seconds=$(echo "$duration * $cut_back_percentage / 100" | bc -l)
    cut_duration=$(echo "$duration - $cut_front_seconds - $cut_back_seconds" | bc -l)

    # Use the calculated cut times to trim the video
    ffmpeg -i "$file" -ss "$cut_front_seconds" -t "$cut_duration" -c copy "$temp_file" -y >>$FFMPEG_LOGS 2>&1

    # Convert the video to the target format
    local converted_file="${temp_file%.*}_converted.$target_format"
    if ! getDetails "$file" format | grep -q "$target_format"; then
        ffmpeg -i "$temp_file" "$converted_file" -y >>$FFMPEG_LOGS 2>&1
    else
        mv "$temp_file" "$converted_file"
    fi

    # Create a list file for concatenation with the video looped n times
    local list_file="${converted_file%.*}_list.txt"
    for ((i = 0; i < loop_number + 1; i++)); do
        echo "file '$converted_file'" >>"$list_file"
    done
    local looped_file="${temp_file%.*}_looped.$target_format"
    ffmpeg -f concat -safe 0 -i "$list_file" -c copy "$looped_file" -y >>$FFMPEG_LOGS 2>&1
    rm -f "$temp_file" "$converted_file" "$list_file"
    echo "$looped_file"
}

menu() {
    local table=()
    local index=1

    for file in "${mediaFiles[@]}"; do
        filename=$(getDetails "$file" filename)
        format=$(getDetails "$file" format)
        duration=$(getDetails "$file" duration)
        extension=$(getDetails "$file" extension)
        type=$(getDetails "$file" type)
        table+=("$index" "$type" "$filename" "$extension" "$duration" "$format")
        index=$((index + 1))
    done

    local id
    local exit_code
    id=$(yad --list --multiple \
        --title="Lista wczytanych plików" \
        --button=gtk-info:12 \
        --button=gtk-add:10 \
        --button=gtk-remove:6 \
        --button=gtk-delete:8 \
        --button=gtk-new:2 \
        --button=gtk-edit:4 \
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
        --separator=! \
        "${table[@]}")

    exit_code=$?
    id=${id%?}

    if [ $exit_code -eq 1 ] && [ $exit_code -eq 252 ]; then
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
        if [[ "$id" == *"!"* ]]; then
            case $exit_code in
            0 | 4 | 6 | 8)
                yad --title="Błąd" --text="Wybrano wiecej niż jeden plik." --button=gtk-close:0
                menu
                ;;
            1)
                rm -rf "$temp_dir"
                exit 0
                ;;
            2)
                echo "COMPOSE GO ON"
                menu
                ;;
            10)
                addNewFiles
                menu
                ;;
            esac
        else
            id=$((id - 1))
            if [ $exit_code -ne 1 ] && [ $exit_code -ne 10 ] && [ $exit_code -ne 252 ]; then
                if [ $id -eq -1 ]; then
                    yad --title="Błąd" --text="Nie wybrano pliku." --button=gtk-close:0
                    menu
                    return
                fi
            fi
            case $exit_code in
            12)
                echo "===================="
                echo "${mediaFiles[$id]}"
                echo "$(getDetails "${mediaFiles[$id]}" type) $(getDetails "${mediaFiles[$id]}" filename) $(getDetails "${mediaFiles[$id]}" extension) $(getDetails "${mediaFiles[$id]}" duration) $(getDetails "${mediaFiles[$id]}" format)"
                echo "${realFiles[$id]}"
                echo "===================="
                menu
                ;;
            0)
                play "${mediaFiles[$id]}"
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
                local file="${mediaFiles[$id]}"

                if [ "${media_types[$(getDetails "$file" type)]}" = "video" ]; then
                    editVideo "$file" "$id"
                else
                    editAudio "$file" "$id"
                fi
                menu
                ;;
            6)
                mediaFiles=("${mediaFiles[@]:0:$id}" "${mediaFiles[@]:$((id + 1))}")
                realFiles=("${realFiles[@]:0:$id}" "${realFiles[@]:$((id + 1))}")
                menu
                ;;
            8)
                if [ -z "${realFiles[$id]}" ]; then
                    yad --warning --text="File was modified so it isn't linked to the real file." --button=gtk-ok:0
                else
                    if yad --title="Potwierdź usunięcie" --text="Czy na pewno chcesz usunąć plik?" --button=gtk-yes:0 --button=gtk-no:1; then
                        rm -f "${realFiles[$id]}"
                        mediaFiles=("${mediaFiles[@]:0:$id}" "${mediaFiles[@]:$((id + 1))}")
                        realFiles=("${realFiles[@]:0:$id}" "${realFiles[@]:$((id + 1))}")
                    fi
                fi
                menu
                ;;
            10)
                addNewFiles
                menu
                ;;

            esac
        fi
    fi

}

# about() {
#     yad --width=700 --height=500 --title="O programie" --text="Program do konwersji plików wideo" --button=gtk-new:0
#     menu
# }

# about

menu
