#!/bin/sh

apk add xorg-server xf86-input-libinput xinit eudev mesa-dri-gallium "$@"

setup-devd udev