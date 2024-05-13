#!/bin/bash

temp=$(mktemp)

grep "GET" cdlinux.www.log |
    grep "HTTP.* 200 " |
    cut -d "\"" -f 1,2 |
    cut -d " " -f 1,7 |
    cut -d ":" -f 2 |
    sort -u |
    grep "cdlinux-.*iso" -o >"$temp"

grep "OK DOWNLOAD" cdlinux.ftp.log |
    cut -d "\"" -f 2,4 |
    sort -u |
    grep "cdlinux-.*iso" -o >>"$temp"

sort <"$temp" |
    uniq -c |
    sort

rm "${temp}"
