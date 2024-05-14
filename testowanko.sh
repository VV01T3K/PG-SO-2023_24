#!/bin/bash
holidays=$(echo "Gold Coast,Bali,Phuket,Sydney,other")
yad --title="My YAD Test" --text="Please enter your details:" \
    --image="/usr/share/icons/hicolor/48x48/status/phone.png" \
    --form --date-format="%-d %B %Y" --separator="," --item-separator="," \
    --field="First Name" \
    --field="Last Name" \
    --field="Status":RO \
    --field="Date of birth":DT \
    --field="Last holiday":CBE \
    --field="List your 3 favourite foods:":TXT \
    "" "" "All round good guy" "Click calendar icon" "$holidays"
