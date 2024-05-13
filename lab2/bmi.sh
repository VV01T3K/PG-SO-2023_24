#!/bin/bash
echo "Podaj mase ciała (kg)"
read masa
echo "Podaj wzrost (m)"
read wzrost

BMI=$(echo "$masa/($wzrost*$wzrost)" | bc)
echo "Twoje BMI to $BMI"

if [[ $BMI -lt 18 ]]; then echo "Niedowaga"
elif [[ $BMI -lt 25 ]]; then echo "Prawidłowa waga"
elif [[ $BMI -lt 30 ]]; then echo "Nadwaga"
else echo "Otyłość"
fi
