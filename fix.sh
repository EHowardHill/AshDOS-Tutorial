#!/bin/bash

# Update package lists
sudo apt update -y

# Get a list of all installed packages
installed_packages=$(dpkg-query -W -f='${binary:Package}\n')

# Downgrade each package to the latest version in the repository
for package in $installed_packages; do
    # Check if a downgrade is needed and perform it
    echo "$package"
    sudo aptitude install -y -f "$package"
done

# Optional: Clean up unnecessary packages
sudo apt autoremove
