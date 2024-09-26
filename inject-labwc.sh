#!/bin/bash
set -e

# This script adjusts the initramfs folder to include LabWC (a Wayland window-stacking compositor)
# and all necessary dependencies, ensuring they are dynamically linked to the new system.
# It then calls rebuild-initramfs.sh to rebuild the initramfs image.

#!/bin/bash
set -e

# Reinstall official Wayland packages (if necessary)
sudo apt-get update
sudo apt-get install -y libwayland-dev libwayland-server0 libwayland-client0

# Install build dependencies
sudo apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libffi-dev \
    libexpat1-dev \
    libxml2-dev \
    doxygen \
    libdrm-dev \
    libxcb1-dev \
    libxcb-composite0-dev \
    libxcb-xfixes0-dev \
    libxcb-image0-dev \
    libxcb-render0-dev \
    libxcb-shape0-dev \
    libxcb-xinput-dev \
    libxcb-icccm4-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-res0-dev \
    libxcb-xkb-dev \
    libxcb-xinerama0-dev \
    libxkbcommon-dev \
    libpixman-1-dev \
    libinput-dev \
    libudev-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libpango1.0-dev \
    libcairo2-dev \
    libgdk-pixbuf2.0-dev \
    libgtk-3-dev \
    git \
    meson \
    ninja-build \
    xmlto \
    libdrm-dev \
    wayland-protocols \
    glslang-dev \
    glslang-tools \
    libxcb-dri3-dev \
    libxcb-present-dev \
    libxcb-util-dev \
    libxcb-render-util0-dev \
    libxcb-errors-dev

# Set custom installation prefixes
WAYLAND_PREFIX=/usr/local/wayland
WLR_PREFIX=/usr/local/wlroots
LABWC_PREFIX=/usr/local/labwc

# Build and install Wayland from source
echo "Building Wayland..."
mkdir -p ~/source-builds
cd ~/source-builds

#git clone https://gitlab.freedesktop.org/wayland/wayland.git
cd wayland
git checkout 1.23.0
meson setup build --prefix=$WAYLAND_PREFIX
ninja -C build
sudo ninja -C build install
cd ..

# Update environment variables
export PKG_CONFIG_PATH=$WAYLAND_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=$WAYLAND_PREFIX/lib:$LD_LIBRARY_PATH

# Verify Wayland version
echo "Wayland version: $(pkg-config --modversion wayland-server)"

# Build and install wlroots
echo "Building wlroots..."
#git clone https://github.com/swaywm/wlroots.git
cd wlroots

# Optionally, checkout a specific version
# git checkout 0.16.2  # Replace with a compatible version

# Clean previous build
rm -rf build

# Configure wlroots with DRM backend enabled
meson setup build \
    --prefix=$WLR_PREFIX \
    --pkg-config-path=$PKG_CONFIG_PATH \
    -Dbackends=drm,wayland,x11

ninja -C build
DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Update PKG_CONFIG_PATH for wlroots
export PKG_CONFIG_PATH=$WLR_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=$WLR_PREFIX/lib:$LD_LIBRARY_PATH

# Build and install LabWC
echo "Building LabWC..."
#git clone https://github.com/labwc/labwc.git
cd labwc

# Clean previous build
rm -rf build

meson setup build \
    --prefix=$LABWC_PREFIX \
    --pkg-config-path=$PKG_CONFIG_PATH

ninja -C build
DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Copy wlroots and LabWC into initramfs
cp -a wlroots/install/* initramfs/
cp -a labwc/install/* initramfs/

# Copy necessary libraries into initramfs
echo "Copying necessary libraries..."
binaries=(
    "initramfs$LABWC_PREFIX/bin/labwc"
)

copy_dependencies() {
    for bin in "${binaries[@]}"; do
        echo "Processing $bin"
        deps=$(ldd $bin | grep "=> /" | awk '{print $3}')
        for dep in $deps; do
            if [ -f "$dep" ]; then
                dest="initramfs${dep}"
                if [ ! -f "$dest" ]; then
                    mkdir -p "$(dirname "$dest")"
                    cp "$dep" "$dest"
                fi
            fi
        done
    done
}

copy_dependencies

# Create necessary device nodes
echo "Creating device nodes..."
sudo mknod -m 666 initramfs/dev/null c 1 3 || true
sudo mknod -m 666 initramfs/dev/zero c 1 5 || true
sudo mknod -m 666 initramfs/dev/tty c 5 0 || true
sudo mknod -m 666 initramfs/dev/tty0 c 4 0 || true
sudo mknod -m 666 initramfs/dev/urandom c 1 9 || true
sudo mknod -m 666 initramfs/dev/random c 1 8 || true
sudo mknod -m 666 initramfs/dev/input/event0 c 13 64 || true
sudo mknod -m 666 initramfs/dev/dri/card0 c 226 0 || true

# Adjust initramfs init script to start LabWC
echo "Configuring init script..."
cat > initramfs/init << EOF
#!/bin/sh

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
mkdir -p /run
mkdir -p /var/run
mkdir -p /dev/input
mkdir -p /dev/dri

# Create necessary device nodes
mknod -m 666 /dev/null c 1 3 || true
mknod -m 666 /dev/zero c 1 5 || true
mknod -m 666 /dev/tty c 5 0 || true
mknod -m 666 /dev/tty0 c 4 0 || true
mknod -m 666 /dev/urandom c 1 9 || true
mknod -m 666 /dev/random c 1 8 || true
mknod -m 666 /dev/input/event0 c 13 64 || true
mknod -m 666 /dev/dri/card0 c 226 0 || true

# Set environment variables
export XDG_RUNTIME_DIR=/run
export HOME=/root
export PATH=$LABWC_PREFIX/bin:$WLR_PREFIX/bin:$WAYLAND_PREFIX/bin:/usr/bin:/bin:/sbin:/usr/sbin
export LD_LIBRARY_PATH=$LABWC_PREFIX/lib:$WLR_PREFIX/lib:$WAYLAND_PREFIX/lib

# Start LabWC
exec $LABWC_PREFIX/bin/labwc
EOF
chmod +x initramfs/init

# Copy configuration files if necessary
echo "Copying configuration files..."
mkdir -p initramfs/etc/xdg/labwc
cp labwc/data/labwc.conf initramfs/etc/xdg/labwc/

# Rebuild the initramfs image
echo "Rebuilding initramfs image..."
./rebuild-initramfs.sh
