convert() {
    # trap 'cleanup_and_exit' SIGINT
    # cleanup_and_exit() {
    #     echo "Przerwanie konwersji..."
    #     kill "$ffmpeg_pid" 2>/dev/null
    #     rm -f ffmpeg_progress.log
    #     rm -rf "$temp_dir"
    #     exit 1
    # }

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
        echo " # Konwersja zakończona"
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
