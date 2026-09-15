#!/bin/bash

# Exit script on error
set -e

# Directory variables
SRC_DIR="$HOME/labwc_src"
BUILD_DIR="$HOME/labwc_build"
INSTALL_DIR="$HOME/labwc_static"

# Dependencies
DEPENDENCIES="meson ninja-build pkg-config gcc g++ cmake git wayland-protocols libpixman-1-dev libxcb-xkb-dev libxml2-dev"

# Install necessary dependencies
echo "Installing dependencies..."
sudo apt update
sudo apt install -y $DEPENDENCIES

# Create directories
mkdir -p $SRC_DIR $BUILD_DIR $INSTALL_DIR

# Download and build static dependencies
build_static_dependency() {
    REPO_URL=$1
    REPO_NAME=$(basename "$REPO_URL" .git)
    echo "Building static $REPO_NAME..."

    cd "$SRC_DIR"
    if [ ! -d "$REPO_NAME" ]; then
        git clone "$REPO_URL"
    fi

    cd "$REPO_NAME"
    git pull

    # Clean up previous builds
    rm -rf build
    meson setup build --prefix="$INSTALL_DIR" --buildtype=release -Ddefault_library=static
    meson compile -C build
    meson install -C build
}

# Build wlroots (LabWC dependency)
build_wlroots() {
    echo "Building static wlroots..."

    cd "$SRC_DIR"
    if [ ! -d "wlroots" ]; then
        git clone https://gitlab.freedesktop.org/wlroots/wlroots.git
    fi

    cd wlroots
    git pull

    # Clean up previous builds
    rm -rf build
    meson setup build --prefix="$INSTALL_DIR" --buildtype=release \
        -Ddefault_library=static -Dlibseat=disabled -Dxwayland=disabled -Denable-x11=false
    meson compile -C build
    meson install -C build
}

# Build LabWC itself
build_labwc() {
    echo "Building static LabWC..."

    cd "$SRC_DIR"
    if [ ! -d "labwc" ]; then
        git clone https://github.com/labwc/labwc.git
    fi

    cd labwc
    git pull

    # Clean up previous builds
    rm -rf build
    meson setup build --prefix="$INSTALL_DIR" --buildtype=release \
        -Ddefault_library=static -Dwlroots:default_library=static -Denable-x11=false
    meson compile -C build
    meson install -C build
}

# Build all static dependencies
build_static_dependency https://github.com/xkbcommon/libxkbcommon.git
build_static_dependency https://gitlab.freedesktop.org/wayland/wayland.git
build_wlroots

# Finally, build LabWC
build_labwc

echo "Static build of LabWC complete. Binary is in $INSTALL_DIR/bin"

# Move LabWC to portable location (optional)
PORTABLE_DIR="$HOME/labwc_portable"
mkdir -p "$PORTABLE_DIR"
cp -r "$INSTALL_DIR"/* "$PORTABLE_DIR/"

echo "LabWC has been installed to $PORTABLE_DIR"

