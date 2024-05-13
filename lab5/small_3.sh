#!/bin/bash
declare -A TABLICA
TABLICA[plik]=""
TABLICA[katalog]=""
TABLICA[last_modified]=""
TABLICA[rozmiar]=""
TABLICA[owner]=""
TABLICA[rozmiar_pref]=""
TABLICA[last_modified_pref]=""
TABLICA[content]=""

settings() {
    if ! SETTINGS=$(
        zenity --list \
            --title="Choose an option" \
            --column="Option" --column="Description" \
            "Nazwa pliku" "${TABLICA[plik]}" \
            "Katalog" "${TABLICA[katalog]}" \
            "Właściciel" "${TABLICA[owner]}" \
            "Ostatnio modyfikowany" "${TABLICA[last_modified]} ${TABLICA[last_modified_pref]}" \
            "Rozmiar" "${TABLICA[rozmiar]} ${TABLICA[rozmiar_pref]}" \
            "Wyszukaj pliki zawierające" "${TABLICA[content]}" \
            --width 400 --height 400
    ); then
        menu
    fi

    case $SETTINGS in
    "Nazwa pliku")
        TABLICA[plik]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj nazwę pliku")
        ;;
    "Katalog")
        TABLICA[katalog]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj katalog")
        ;;
    "Właściciel")
        TABLICA[owner]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj właściciela")
        ;;
    "Ostatnio modyfikowany")
        case $(zenity --list --title="Wyszukiwaraka plików" --text="Wybierz opcję" --column="Menu" "Mniejsze niż" "Większe niż" "Równe") in
        "Mniejsze niż")
            TABLICA[last_modified_pref]="-lt"
            ;;
        "Większe niż")
            TABLICA[last_modified_pref]="-gt"
            ;;
        "Równe")
            TABLICA[last_modified_pref]="-eq"
            ;;
        *)
            TABLICA[last_modified_pref]=""
            ;;
        esac
        TABLICA[last_modified]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj datę")
        ;;
    "Rozmiar")
        case $(zenity --list --title="Wyszukiwaraka plików" --text="Wybierz opcję" --column="Menu" "Mniejsze niż" "Większe niż" "Równe") in
        "Mniejsze niż")
            TABLICA[rozmiar_pref]="-lt"
            ;;
        "Większe niż")
            TABLICA[rozmiar_pref]="-gt"
            ;;
        "Równe")
            TABLICA[rozmiar_pref]="-eq"
            ;;
        *)
            TABLICA[rozmiar_pref]=""
            ;;
        esac
        TABLICA[rozmiar]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj rozmiar")
        ;;
    "Wyszukaj pliki zawierające")
        TABLICA[content]=$(zenity --entry --title="Wyszukiwaraka plików" --text="Podaj zawartość")
        ;;
    esac

    settings
}

myFind() {
    local result
    local args=()

    if [[ -n "${TABLICA[plik]}" ]]; then
        args+=(-name "*${TABLICA[plik]}*")
    fi

    if [[ -n "${TABLICA[katalog]}" ]]; then
        args+=(-path "*${TABLICA[katalog]}*")
    fi

    if [[ -n "${TABLICA[owner]}" ]]; then
        args+=(-user "${TABLICA[owner]}")
    fi

    if [[ -n "${TABLICA[last_modified]}" ]]; then
        case "${TABLICA[last_modified_pref]}" in
        lt) args+=(-mtime +"${TABLICA[last_modified]}") ;;
        gt) args+=(-mtime -"${TABLICA[last_modified]}") ;;
        eq) args+=(-mtime "${TABLICA[last_modified]}") ;;
        esac
    fi

    if [[ -n "${TABLICA[rozmiar]}" ]]; then
        case "${TABLICA[rozmiar_pref]}" in
        -lt) args+=(-size -"${TABLICA[rozmiar]}k") ;;
        -gt) args+=(-size +"${TABLICA[rozmiar]}k") ;;
        -eq) args+=(-size "${TABLICA[rozmiar]}k") ;;
        esac
    fi

    if [[ -n "${TABLICA[content]}" ]]; then
        args+=(-exec grep -l "${TABLICA[content]}" {} \;)
    fi
    result=$(find ~ -type f "${args[@]}")
    if [[ -z "$result" ]]; then
        echo "No files found."
    else
        echo "$result"
    fi
}

findCommand() {
    result=$(myFind | head -n 1000)

    IFS=$'\n' read -rd '' -a file_paths <<<"$result"

    file=$(zenity --list --title="Wybierz plik do wyświetlenia" --column="Files" "${file_paths[@]}" --width 500 --height 400)

    if [ -n "$file" ]; then
        new_content=$(zenity --text-info --title="Content of $file" --filename="$file" --editable --text="$(cat "$file")" --width 800 --height 600)
        if [ -n "$new_content" ]; then
            echo "$new_content" >"$file"
        fi
    fi
}

menu() {
    if ! MENU=$(
        zenity --list \
            --title="Choose an option" \
            --column="Menu" \
            "Opcje" \
            "Wyszukaj" \
            "Wyjście" \
            --width 400 --height 400
    ); then
        exit
    fi

    case $MENU in
    "Opcje")
        settings
        ;;
    "Wyszukaj")
        findCommand
        ;;
    "Wyjście")
        exit
        ;;
    esac

    menu
}

menu
