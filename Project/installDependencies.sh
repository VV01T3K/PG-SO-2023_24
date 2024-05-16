#!/bin/bash

LOGS="out.log"
exec >$LOGS 2>&1
if snap list | grep -qw "celluloid"; then
    echo "celluloid is already installed."
else
    echo "Installing celluloid..."
    sudo snap install celluloid
fi

required_packages=("yad" "ffmpeg" "gnome-icon-theme")
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
