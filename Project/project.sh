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

# ! check for dependencies
# nie może być chyba set -e bo yad się psuje
set -uf -o pipefail
LOGS="out.log"
echo "" >$LOGS
exec 2>>$LOGS
declare -a videos

supported_video_formats=("mp4" "mov" "avi" "webm")
supported_audio_formats=("mp3" "wav" "flac" "ogg")

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
        exit 1
        ;;
    esac
done

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
        videos+=("$i")
        added_file_flag=1
    fi
done
if [ "$added_file_flag" -eq 1 ]; then
    for file in "${videos[@]}"; do
        echo "$file"
    done
else
    echo "No video files were selected."
fi

# * The `getDetails()` function in the provided shell script is responsible for extracting specific
# * details about a video file. It takes two parameters: the index of the video file in the `videos`
# * array and the specific detail to retrieve (filename, extension, duration, or format).
getDetails() {
    local file="${videos[$1]}"
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
    esac
}

args=()
index=0
for file in "${videos[@]}"; do
    filename=$(getDetails "$index" filename)
    format=$(getDetails "$index" format)
    duration=$(getDetails "$index" duration)
    args+=("$index" "$filename" "$duration" "$format")
    index=$((index + 1))
done
convert() {
    trap 'cleanup_and_exit' SIGINT

    cleanup_and_exit() {
        echo "Przerwanie konwersji..."
        kill "$ffmpeg_pid" 2>/dev/null
        rm -f ffmpeg_progress.log
        rm -f "$output_file"
        yad --title="Błąd konwersji" --text="Wystąpił błąd podczas konwersji pliku." --button=gtk-stop:0
        exit 1
    }

    local file="${videos[$1]}"
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
        --width=300 --height=300 \
        --list --radiolist \
        --print-column=2 --separator= \
        --column=Select:BOOL \
        --column=Format:TEXT $format_options)

    if [ -z "$target_format" ] || [ "${file##*.}" = "$target_format" ]; then
        echo "No conversion needed."
        return
    fi

    local output_file="${file%.*}.$target_format"
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    duration=${duration%.*}
    ffmpeg -i "$file" "$output_file" -y 2>ffmpeg_progress.log &
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
        rm -f "$output_file"
        yad --title="Błąd konwersji" --text="Konwersja nie została zakończona pomyślnie." --button=gtk-exit:0
        exit 1
    fi

    if yad --title="Konwersja zakończona" --text="Plik został zapisany jako $output_file" --button=gtk-ok:0; then
        true # Placeholder for potential success operations
    else
        yad --title="Błąd konwersji" --text="Wystąpił błąd podczas konwersji pliku." --button=gtk-ok:0
    fi

    rm ffmpeg_progress.log
}

id=$(yad --list \
    --title="Lista wczytanych plików" \
    --width=600 --height=500 \
    --column=ID:NUM \
    --column=NAME:text \
    --column=Duration:text \
    --column=FORMAT:text \
    --button=gtk-ok:2 \
    --button=gtk-cancel:1 \
    --button=gtk-media-play:0 \
    --button=Convert:3 \
    --hide-column=1 \
    --print-column=1 --separator= \
    "${args[@]}")
case $? in
0)
    # ffplay -x 800 -y 600 "${videos[$id]}"
    mpv "${videos[$id]}" >>"$LOGS" 2>&1
    ;;
1)
    echo "CANCEL"
    ;;
2)
    echo "OK"
    ;;
3)
    convert "$id"
    ;;
esac
