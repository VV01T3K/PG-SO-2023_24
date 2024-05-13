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
set -euf -o pipefail
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

args=()
for file in "${videos[@]}"; do
    filename=$(basename -- "$file")
    filename="${filename%.*}"
    extension="${file##*.}"
    path=$(dirname -- "$file")
    args+=("$filename" "$extension" "$path")
done
yad --list \
    --width=302 --height=123 \
    --column=Filename \
    --column=Extension \
    --column=Path \
    "${args[@]}"
