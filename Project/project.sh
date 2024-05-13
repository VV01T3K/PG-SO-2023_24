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
LOGS="logs.txt"
echo "" >$LOGS
exec 2>>$LOGS
declare -a videos

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

selected_files=$(yad --title="Wybierz pliki" --file-selection --multiple --file-filter='Wideo | *.mp4 *.avi')
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

id=$(yad --list \
    --title="Lista plików" \
    --width=502 --height=523 \
    --column=ID:NUM \
    --column=NAME:text \
    --column=Duration:text \
    --column=FORMAT:text \
    --button=gtk-ok:0 \
    --button=gtk-cancel:1 \
    --button=Preview:2 \
    --hide-column=1 \
    --print-column=1 \
    "${args[@]}" | sed 's/.$//')
case $? in
0)
    echo "OK"
    ;;
1)
    echo "CANCEL"
    ;;
2)
    # ffplay -x 800 -y 600 "${videos[$id]}"
    mpv "${videos[$id]}" >>"$LOGS" 2>&1
    ;;
esac
