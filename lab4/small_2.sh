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
TABLICA[exit]=false

getName() {
	echo 'Podaj nazwe pliku:'
	read -r input
	TABLICA[plik]=$input
}

getDir() {
	echo 'Podaj nazwe katalogu:'
	read -r input
	TABLICA[katalog]=$input
}

getOwner() {
	echo 'Podaj nazwe właściciela:'
	read -r input
	TABLICA[owner]=$input
}

getContent() {
	echo 'Podaj zawartość pliku:'
	read -r input
	TABLICA[content]=$input
}

getSize() {
	echo 'Podaj rozmiar pliku[kB]:'
	read -r input
	TABLICA[rozmiar]=$input
	echo 'Podaj preferencje (mniejszy -> lt, wiekszy -> gt, rowny -> eq):'
	read -r input
	TABLICA[rozmiar_pref]=""
	if [[ -n $input ]]; then
		TABLICA[rozmiar_pref]="-$input"
	fi
}

getLastModified() {
	echo 'Podaj ilość dni od ostatniej modyfikacji:'
	read -r input
	TABLICA[last_modified]=$input
	echo 'Podaj preferencje (mniejszy -> lt, wiekszy -> gt, rowny -> eq):'
	read -r input
	TABLICA[last_modified_pref]=""
	if [[ -n $input ]]; then
		TABLICA[last_modified_pref]="-$input"
	fi
}

exitScript() {
	echo 'Are you sure you want to exit? y/n'
	read -r input
	case $input in
	y | Y | T) TABLICA["exit"]="true" ;;
	n | N) TABLICA["exit"]="false" ;;
	*) echo "Invalid input" ;;
	esac
}

trim() {
	local var="$*"
	echo "$var" | tr -d '[:space:]'
}

myfind() {
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
	result=$(find . -type f "${args[@]}")
	if [[ -z "$result" ]]; then
		echo "No files found."
	else
		echo "$result"
	fi
}

showContent() {
	local result
	result=$(myfind)
	if [[ -z "$result" ]]; then
		echo "No files found."
	else
		for file in $result; do
			if [ -s "$file" ]; then
				echo ""
				echo "--$file--"
				cat "./$file"
				echo ""
				echo "--EOF--"
			else
				echo "File $file is empty"
			fi
		done
	fi
	echo ""
	echo "Press any key to continue..."
	read -r input
}

findCommand() {
	myfind
	echo "Press any key to continue..."
	read -r input
}

prompt() {
	clear
	echo "
1. Nazwa pliku: ${TABLICA[plik]}
2. Katalog: ${TABLICA[katalog]}
3. Właściciel: ${TABLICA[owner]}
4. Ostatnio modyfikowany: ${TABLICA[last_modified_pref]} ${TABLICA[last_modified]}
5. Rozmiar: ${TABLICA[rozmiar_pref]} ${TABLICA[rozmiar]}
6. Wyszukaj pliki zawierające: ${TABLICA[content]}
7. Szukaj
8. Wypisz zawartość znalezionych plików
9. Koniec
"
	read -r input
	case $input in
	1) getName ;;
	2) getDir ;;
	3) getOwner ;;
	4) getLastModified ;;
	5) getSize ;;
	6) getContent ;;
	7) findCommand ;;
	8) showContent ;;
	9) exitScript ;;
	q) TABLICA["exit"]="true" ;;
	esac
}

until [[ ${TABLICA[exit]} == "true" ]]; do
	prompt
done

clear
