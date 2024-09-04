#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y dosfstools

truncate -s 4G harddrive.img
mkfs.fat -F 32 harddrive.img