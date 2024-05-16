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
exit_code_global=""
dane=""
declare -a mediaFiles
supported_video_formats=("mp4" "mov" "avi" "webm")
supported_audio_formats=("mp3" "wav" "flac" "ogg")
declare -A media_types=(
    ["video-x-generic-symbolic"]="video"
    ["video"]="video-x-generic-symbolic"
    ["audio-x-generic"]="audio"
    ["audio"]="audio-x-generic"
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
            echo -n "Media | "
            for format in "${supported_video_formats[@]}" "${supported_audio_formats[@]}"; do
                echo -n "*.$format "
            done
        )" \
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
            mediaFiles+=("$file")
            added_file_flag=1
        fi
    done
    if [ "$added_file_flag" -ne 1 ]; then
        yad --title="Błąd" --text="Nie wybrano plików wideo." --button=gtk-close:0
    fi
}
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
    path)
        dirname "$file"
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
openForm() {
    local file=$1
    local type="${media_types["$(getDetails "$file" type)"]}"
    local processed
    local supported_media_formats=()
    if [ "$type" = "video" ]; then
        supported_media_formats=("${supported_video_formats[@]}")
    else
        supported_media_formats=("${supported_audio_formats[@]}")
    fi
    local reordered_formats=("$(getDetails "$file" extension)")
    for format in "${supported_media_formats[@]}"; do
        if [[ "$format" != "$(getDetails "$file" extension)" ]]; then
            reordered_formats+=("$format")
        fi
    done
    printf -v media_formats "%s\\!" "${reordered_formats[@]}"
    local media_formats=${media_formats%\\!}
    form=(
        yad --form --title="Single File Edit" --text="You can make changes:"
        --button=gtk-save:2
        --button=gtk-cancel:1
        --field="Name" "$(getDetails "$file" filename)"
        --field="Format:CB" "$media_formats"
        --field="Duration:RO" "$(getDetails "$file" duration)"
        --field="Time [%] to cut from start:SCL" "0:100:1"
        --field="Time [%] to cut from end:SCL" "0:100:1"
        --field="Number of loops:NUM" "0..100..1"
    )
    if [ "$type" = "video" ]; then
        form+=(
            --field="Watermark Text" ""
            --field="Watermark Font Size:NUM" "16"
            --field="Watermark Color:CLR" "#000000"
        )
    fi
    dane=$("${form[@]}")
    exit_code_global=$?
}
openCombineForm() {
    local file=$1
    local type="${media_types["$(getDetails "$file" type)"]}"
    local processed
    local supported_media_formats=()
    if [ "$type" = "video" ]; then
        supported_media_formats=("${supported_video_formats[@]}")
    else
        supported_media_formats=("${supported_audio_formats[@]}")
    fi
    local reordered_formats=("$(getDetails "$file" extension)")
    for format in "${supported_media_formats[@]}"; do
        if [[ "$format" != "$(getDetails "$file" extension)" ]]; then
            reordered_formats+=("$format")
        fi
    done
    printf -v media_formats "%s\\!" "${reordered_formats[@]}"
    local media_formats=${media_formats%\\!}
    form=(
        yad --form --title="Single File Edit" --text="You can make changes:"
        --button=gtk-save:2
        --button=gtk-cancel:1
        --field="Format:CB" "$media_formats"
    )
    if [ "$type" = "video" ]; then
        form+=(
            --field="Watermark Text" ""
            --field="Watermark Font Size:NUM" "16"
            --field="Watermark Color:CLR" "#000000"
        )
    fi
    dane=$("${form[@]}")
    exit_code_global=$?
}

editMediaFile() {
    local file=$1
    local id=$2
    openForm "$file"
    case $exit_code_global in
    2)
        IFS='|' read -ra ADDR <<<"$dane"
        if [ "$(echo "${ADDR[3]} + ${ADDR[4]} >= 100" | bc)" -eq 1 ]; then
            yad --title="Błąd" --text="Suma czasów przycięcia nie może być większa niż 100%." --button=gtk-close:0
            editMediaFile "$file" "$id"
            return
        fi
        if [ "$type" = "video" ]; then
            processed=$(processMediaFile "$file" "${ADDR[1]}" "${ADDR[3]}" "${ADDR[4]}" "${ADDR[5]}" "${ADDR[6]}" "${ADDR[7]}" "${ADDR[8]}")
        else
            processed=$(processMediaFile "$file" "${ADDR[1]}" "${ADDR[3]}" "${ADDR[4]}" "${ADDR[5]}" "" "" "")
        fi
        if [ -z "$processed" ]; then
            return
        fi
        local save_path
        save_path=$(yad --save --file="$file" --filename="$(dirname "$file")/${ADDR[0]}.${ADDR[1]}")
        if [ -z "$save_path" ]; then
            rm -f "$processed"
            yad --title="Błąd konwersji" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
        else
            mv "$processed" "$save_path"
            mediaFiles+=("$save_path")
            yad --title="Przetwarzanie zakończone" --text="Plik został zapisany" --button=gtk-ok:0
        fi
        ;;
    esac
}

processMediaFile() {
    echo "" >$FFMPEG_LOGS
    local file=$1
    local type
    type="${media_types["$(getDetails "$file" type)"]}"
    local current_format="${file##*.}"
    local target_format=$2
    local cut_front_percentage=$3
    local cut_back_percentage=$4
    if [ "$(echo "$cut_front_percentage + $cut_back_percentage >= 100" | bc)" -eq 1 ]; then
        yad --title="Błąd" --text="Suma czasów przycięcia nie może być większa niż 100%." --button=gtk-close:0
        return
    fi
    local loop_number=$5
    local watermark_text=$6
    local watermark_font_size=$7
    local watermark_color=$8
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

    # Convert the video to the target format and watermark it
    local ffmpeg_pid=""
    local converted_file="${temp_file%.*}_converted.$target_format"
    if [ -n "$watermark_text" ] && [ "$type" = "video" ]; then
        ffmpeg -i "$temp_file" \
            -vf "drawtext=text='$watermark_text': \
            x=$watermark_font_size/3: \
            y=h-text_h-10: \
            fontsize=$watermark_font_size: \
            fontcolor=$watermark_color" \
            "$converted_file" -y \
            2>ffmpeg_progress.log &
        ffmpeg_pid=$!
    else
        if ! getDetails "$file" format | grep -q "$target_format"; then
            ffmpeg -i "$temp_file" "$converted_file" -y 2>ffmpeg_progress.log &
            ffmpeg_pid=$!
        fi
    fi
    if [ -n "$ffmpeg_pid" ]; then
        local conversion_complete=0
        (
            local convert_duration
            convert_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$temp_file")
            while kill -0 $ffmpeg_pid 2>/dev/null; do
                current_time=$(grep -oP 'time=\K[\d:.]*' ffmpeg_progress.log | tail -1)
                hours=$(echo "$current_time" | cut -d':' -f1)
                minutes=$(echo "$current_time" | cut -d':' -f2)
                seconds=$(echo "$current_time" | cut -d':' -f3)
                current_seconds=$(echo "$hours*3600 + $minutes*60 + $seconds" | bc)
                progress=$(echo "scale=2; $current_seconds/($convert_duration)*100" | bc)
                echo "$progress"
                sleep 1
            done
            echo " # Konwersja zakończona"
            echo "100"
        ) | yad --progress --title="Postęp przetwarzania" --text="Trwa przetwarzanie pliku..." --percentage=0 --auto-close && conversion_complete=1
        if [ $conversion_complete -ne 1 ]; then
            kill $ffmpeg_pid
            yad --title="Błąd przetwarzania" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
            return 0
        fi
        mv "$converted_file" "$temp_file"
    fi

    # Create a list file for concatenation with the video looped n times
    local list_file="${temp_file%.*}_list.txt"
    for ((i = 0; i < loop_number + 1; i++)); do
        echo "file '$temp_file'" >>"$list_file"
    done
    local looped_file="${temp_file%.*}_looped.$target_format"
    ffmpeg -f concat -safe 0 -i "$list_file" -c copy "$looped_file" -y >>$FFMPEG_LOGS 2>&1
    mv "$looped_file" "$temp_file"
    rm -f "$list_file"
    echo "$temp_file"
}

overlayMediaFiles() {
    local files=("$@")
    openCombineForm "${files[0]}"
    case $exit_code_global in
    1)
        return
        ;;
    2)
        IFS='|' read -ra ADDR <<<"$dane"
        local target_format=${ADDR[0]}
        ;;
    esac
    local output_file
    output_file=$(mktemp --suffix=".$target_format" --tmpdir="$temp_dir")
    max_duration=0
    converted_files=()
    for file in "${files[@]}"; do
        file=$(processMediaFile "$file" "$target_format" 0 0 0 "" "" "")
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
        if (($(echo "$duration > $max_duration" | bc -l))); then
            max_duration=$duration
        fi
        converted_files+=("$file")
    done

    # Initialize the filter_complex part of the command
    filter_complex=""

    # Loop through each file in the converted_files array to construct the filter_complex part
    for i in "${!converted_files[@]}"; do
        filter_complex+="[${i}:a:0]"
    done

    # Add the amix filter with the number of inputs equal to the number of files
    filter_complex+="amix=inputs=${#converted_files[@]}:duration=longest[aout]"

    # Construct and execute the ffmpeg command
    ffmpeg_command="ffmpeg"
    for file in "${converted_files[@]}"; do
        ffmpeg_command+=" -i \"$file\""
    done
    ffmpeg_command+=" -filter_complex \"$filter_complex\" -map \"[aout]\" \"$output_file\" -y 2>ffmpeg_progress.log &"

    eval "$ffmpeg_command"
    ffmpeg_pid=$!

    local conversion_complete=0
    (
        while kill -0 $ffmpeg_pid 2>/dev/null; do
            if grep -q "Conversion failed!" ffmpeg_progress.log; then
                kill $ffmpeg_pid
                yad --title="Błąd przetwarzania" --text="Przetwarzanie nie zostało zakończone pomyślnie. Conversion failed!" --button=gtk-close:0
                return
            fi
            current_time=$(grep -oP 'time=\K[\d:.]*' ffmpeg_progress.log | tail -1)
            hours=$(echo "$current_time" | cut -d':' -f1)
            minutes=$(echo "$current_time" | cut -d':' -f2)
            seconds=$(echo "$current_time" | cut -d':' -f3)
            current_seconds=$(echo "$hours*3600 + $minutes*60 + $seconds" | bc)
            progress=$(echo "scale=2; $current_seconds/($max_duration)*100" | bc)
            echo "$progress"
            sleep 1
        done
        echo " # Konwersja zakończona"
        echo "100"
    ) | yad --progress --title="Postęp przetwarzania" --text="Trwa przetwarzanie pliku..." --percentage=0 --auto-close && conversion_complete=1
    if [ $conversion_complete -ne 1 ]; then
        kill $ffmpeg_pid
        yad --title="Błąd przetwarzania" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
        return
    fi
    echo "$output_file"
}

concatMediaFiles() {
    local files=("$@")
    openCombineForm "${files[0]}"
    case $exit_code_global in
    1)
        return
        ;;
    2)
        IFS='|' read -ra ADDR <<<"$dane"
        local target_format=${ADDR[0]}
        if [[ "${media_types["$(getDetails "${files[0]}" type)"]}" == "video" ]]; then
            local watermark_text=${ADDR[1]}
            local watermark_font_size=${ADDR[2]}
            local watermark_color=${ADDR[3]}
        fi
        ;;
    esac
    local temp_file
    combined_duration=0
    temp_file=$(mktemp --suffix=".txt" --tmpdir="$temp_dir")
    local output_file
    output_file=$(mktemp --suffix=".$target_format" --tmpdir="$temp_dir")

    for file in "${files[@]}"; do
        file=$(processMediaFile "$file" "$target_format" 0 0 0 "" "" "")
        echo "file '$file'" >>"$temp_file"
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
        combined_duration=$(echo "$combined_duration + $duration" | bc)
    done

    # Step 3: Proceed with concatenation as before, using processed files
    if [[ "${media_types["$(getDetails "${files[0]}" type)"]}" == "video" ]]; then
        ffmpeg -f concat -safe 0 -i "$temp_file" \
            -vf "drawtext=text='$watermark_text': \
              x=$watermark_font_size/3: \
              y=h-text_h-10: \
              fontsize=$watermark_font_size: \
              fontcolor=$watermark_color" \
            "$output_file" -y 2>ffmpeg_progress.log &
        ffmpeg_pid=$!
    else
        ffmpeg -f concat -safe 0 -i "$temp_file" "$output_file" -y 2>ffmpeg_progress.log &
        ffmpeg_pid=$!
    fi

    local conversion_complete=0
    (
        while kill -0 $ffmpeg_pid 2>/dev/null; do
            if grep -q "Conversion failed!" ffmpeg_progress.log; then
                kill $ffmpeg_pid
                yad --title="Błąd przetwarzania" --text="Przetwarzanie nie zostało zakończone pomyślnie. Conversion failed!" --button=gtk-close:0
                return
            fi
            current_time=$(grep -oP 'time=\K[\d:.]*' ffmpeg_progress.log | tail -1)
            hours=$(echo "$current_time" | cut -d':' -f1)
            minutes=$(echo "$current_time" | cut -d':' -f2)
            seconds=$(echo "$current_time" | cut -d':' -f3)
            current_seconds=$(echo "$hours*3600 + $minutes*60 + $seconds" | bc)
            progress=$(echo "scale=2; $current_seconds/($combined_duration)*100" | bc)
            echo "$progress"
            sleep 1
        done
        echo " # Konwersja zakończona"
        echo "100"
    ) | yad --progress --title="Postęp przetwarzania" --text="Trwa przetwarzanie pliku..." --percentage=0 --auto-close && conversion_complete=1
    if [ $conversion_complete -ne 1 ]; then
        kill $ffmpeg_pid
        yad --title="Błąd przetwarzania" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
        return
    fi
    echo "$output_file"
}

combineMenu() {
    local table=()
    local video_count=0
    local audio_count=0
    for id in "${selected_files[@]}"; do
        file="${mediaFiles[$id]}"
        filename=$(getDetails "$file" filename)
        format=$(getDetails "$file" format)
        duration=$(getDetails "$file" duration)
        extension=$(getDetails "$file" extension)
        type=$(getDetails "$file" type)
        mediaTypeKey=$(getDetails "${mediaFiles[$id]}" type)
        if [[ "${media_types[$mediaTypeKey]}" == "video" ]]; then
            video_count=$((video_count + 1))
        else
            audio_count=$((audio_count + 1))
        fi
        table+=("$id" "$type" "$filename" "$extension" "$duration" "$format")
    done
    local mode="mixed"
    if [ "$video_count" -eq 0 ]; then
        mode="audio"
    fi
    if [ "$audio_count" -eq 0 ]; then
        mode="video"
    fi
    local files
    local exit_code
    local processed
    commd=(
        yad --list --editable --editable-cols=""
        --no-click --grid-lines=both --dclick-action=
        --title="Lista wczytanych plików"
        --width=700 --height=500
        --column=ID:HD
        --column=TYPE:IMG
        --column=NAME
        --column=EXT
        --column=Duration
        --column=FORMAT
        --print-all
        --separator=!
        "${table[@]}"
    )
    if [ "$mode" = "mixed" ]; then
        commd+=(--button=Compose:2)
    else
        commd+=(--button=Concat:4)
        if [ "$mode" = "audio" ]; then
            commd+=(--button=Overlap:6)
        fi
    fi
    commd+=(--button=gtk-close:1)
    all=$("${commd[@]}")
    exit_code=$?
    readarray -t selected_files < <(echo "$all" | grep -o '[0-9]\+!!' | cut -d'!' -f1)
    for id in "${selected_files[@]}"; do
        files+=("${mediaFiles[$id]}")
    done

    case $exit_code in
    1)
        menu
        ;;
    4)
        processed=$(concatMediaFiles "${files[@]}")
        if [ -z "$processed" ]; then
            rm -f "$processed"
            yad --title="Błąd konwersji" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
        else
            local save_path
            save_path=$(yad --save --file="$file" --filename="$(dirname "$file")/combined.${processed##*.}")
            if [ -z "$save_path" ]; then
                rm -f "$processed"
                yad --title="Błąd konwersji" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
            else
                mv "$processed" "$save_path"
                mediaFiles+=("$save_path")
                yad --title="Przetwarzanie zakończone" --text="Plik został zapisany" --button=gtk-ok:0
            fi
        fi
        menu
        ;;
    6)
        processed=$(overlayMediaFiles "${files[@]}")
        if [ -z "$processed" ]; then
            rm -f "$processed"
            yad --title="Błąd konwersji" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
        else
            local save_path
            save_path=$(yad --save --file="$file" --filename="$(dirname "$file")/combined.${processed##*.}")
            if [ -z "$save_path" ]; then
                rm -f "$processed"
                yad --title="Błąd konwersji" --text="Przetwarzanie nie zostało zakończone pomyślnie." --button=gtk-close:0
            else
                mv "$processed" "$save_path"
                mediaFiles+=("$save_path")
                yad --title="Przetwarzanie zakończone" --text="Plik został zapisany" --button=gtk-ok:0
            fi
        fi
        menu
        ;;
    esac
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
    id=$(yad --list --multiple --grid-lines=both \
        --title="Lista wczytanych plików" \
        --button=gtk-add:10 \
        --button=gtk-remove:6 \
        --button=gtk-delete:8 \
        --button=Combine:2 \
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
            input=$(echo "$id!" | tr -d '[:space:]')
            local array=()
            IFS='!' read -r -a array <<<"$input"
            local id
            local ids=()
            for element in "${array[@]}"; do
                ids+=($((element - 1)))
            done

            case $exit_code in
            0 | 4 | 8)
                yad --title="Błąd" --text="Wybrano wiecej niż jeden plik." --button=gtk-close:0
                menu
                ;;
            1)
                rm -rf "$temp_dir"
                exit 0
                ;;
            2)
                selected_files=("${ids[@]}")
                combineMenu
                menu
                ;;
            6)
                declare -a newMediaFiles=()
                for ((i = 0; i < ${#mediaFiles[@]}; i++)); do
                    matchFound=false
                    for id in "${ids[@]}"; do
                        if [[ $id -eq $i ]]; then
                            matchFound=true
                            break
                        fi
                    done
                    if [[ $matchFound == false ]]; then
                        newMediaFiles+=("${mediaFiles[i]}")
                    fi
                done
                mediaFiles=("${newMediaFiles[@]}")
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
            0)
                play "${mediaFiles[$id]}"
                menu
                ;;
            1)
                rm -rf "$temp_dir"
                exit 0
                ;;
            2)
                yad --title="Błąd" --text="Wybrano za mało plików." --button=gtk-close:0
                menu
                ;;
            4)
                local file="${mediaFiles[$id]}"
                editMediaFile "$file" "$id"
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
    fi

}

# about() {
#     yad --width=700 --height=500 --title="O programie" --text="Program do konwersji plików wideo" --button=gtk-new:0
#     menu
# }

# about

menu
