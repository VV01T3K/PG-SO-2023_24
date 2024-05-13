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
# New array to hold the details
declare -a videoDetails

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

# for file in "${videos[@]}"; do
#     # Get the file name without the extension
#     filename=$(basename -- "$file")
#     filename="${filename%.*}"
#     # Get the file extension
#     extension="${file##*.}"
#     # Get the file path
#     path=$(dirname -- "$file")
#     # Concatenate details into a string and add to the new array
#     videoDetails+=("$filename:$extension:$path")
# done

# # Loop through all video details instead of accessing them directly
# for detail in "${videoDetails[@]}"; do
#     IFS=':' read -r name ext path <<<"$detail"
#     echo "Name: $name, Extension: $ext, Path: $path"
#     yad --list \
#         --column=Name \
#         --column=Extension \
#         --column=Path \
#         William Bill 40 Richard Dick 69
# done
