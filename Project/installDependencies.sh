#!/bin/bash

LOGS="out.log"
exec >$LOGS 2>&1

required_packages=("yad" "ffmpeg" "totem" "gnome-icon-theme")
echo "Updating package lists..."
sudo apt-get update

for package in "${required_packages[@]}"; do
    if dpkg -l | grep -qw "$package"; then
        echo "$package is already installed."
    else
        echo "Installing $package..."
        sudo apt-get install -y "$package"
    fi
done

echo "All required packages are installed."
