#!/bin/bash
set -e

# Update and install required packages
sudo apt update -y
sudo apt install -y \
    build-essential gcc g++ make libncurses-dev bison flex libssl-dev libelf-dev bc \
    autoconf automake libtool git qemu-system-x86 cpio gzip gawk texinfo sudo \
    libcap-dev libarchive-dev libcurl4-openssl-dev libpolkit-agent-1-dev libfuse-dev \
    libostree-dev libjson-glib-dev libappstream-dev libgpgme-dev \
    meson ninja-build pkg-config libwayland-dev wayland-protocols \
    libdrm-dev libgbm-dev libinput-dev libxkbcommon-dev libudev-dev \
    libpixman-1-dev libcairo2-dev libpango1.0-dev libva-dev libpipewire-0.3-dev \
    freerdp2-dev libx11-xcb-dev libegl-dev libcairo2-dev libgles2 \
    libglfw3-dev libgles2-mesa-dev libgbm-dev libjpeg-dev

# ---------------------
# Pull Source Code
# ---------------------

#git clone https://github.com/torvalds/linux
#git clone https://github.com/bminor/glibc
#git clone https://github.com/mirror/busybox
#git clone https://github.com/flatpak/flatpak
#git clone https://gitlab.freedesktop.org/wayland/weston.git
#git clone https://github.com/swaywm/wlroots

# ---------------------
# Build from Source
# ---------------------

# Create a directory for the initial ramdisk
rm -rf initramfs/*
mkdir -p initramfs/{proc,sys,tmp,lib,lib64,dev,home,etc/network,usr/share/udhcpc}

# Step 1: Compile Linux Kernel with DRM/KMS support
echo "Compiling Linux Kernel..."
cd linux
    make defconfig
    # Enable DRM/KMS support
    scripts/config --enable CONFIG_DRM
    scripts/config --enable CONFIG_DRM_VIRTIO_GPU
    scripts/config --enable CONFIG_DRM_KMS_HELPER
    scripts/config --enable CONFIG_DRM_VIRTIO_GPU
    scripts/config --enable CONFIG_FB
    scripts/config --enable CONFIG_FB_VESA
    scripts/config --module CONFIG_VIRTIO
    scripts/config --enable CONFIG_INPUT_EVDEV
    scripts/config --enable CONFIG_VIRTIO_INPUT
    scripts/config --enable CONFIG_VIRTIO_CONSOLE
    make -j$(nproc) bzImage
cd ..

# Step 2: Compile glibc
echo "Compiling glibc..."
cd glibc
    mkdir -p build
    cd build
        ../configure --prefix=/usr --disable-multilib
        make -j$(nproc)
        make DESTDIR=$(pwd)/install install
    cd ..
cd ..

# Step 3: Compile BusyBox with networking tools
echo "Compiling BusyBox..."
cd busybox
    make defconfig
    make -j$(nproc)
    make CONFIG_PREFIX=$(pwd)/_install install
cd ..

# Step 4: Compile wlroots
echo "Compiling wlroots..."
cd wlroots
    meson build --prefix=/usr -Dlibseat=false
    ninja -C build
    DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Step 5: Compile weston
echo "Compiling weston..."
cd weston
    meson build --prefix=/usr
    ninja -C build
    DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Copy binaries and libraries to initramfs
cp linux/arch/x86/boot/bzImage bzImage
cp -a glibc/build/install/* initramfs/
cp -a busybox/_install/* initramfs/
cp -a weston/install/* initramfs/
cp -a wlroots/install/* initramfs/

# Copy necessary shared libraries
echo "Copying necessary libraries..."
ldd weston/install/usr/local/bin/weston | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' initramfs/lib64/

# Create necessary device nodes
cd initramfs
    sudo mknod -m 622 dev/console c 5 1
    sudo mknod -m 666 dev/null c 1 3
    sudo mknod -m 666 dev/zero c 1 5
    sudo mknod -m 666 dev/tty c 5 0
    sudo mknod -m 666 dev/tty0 c 4 0
    sudo mknod -m 666 dev/random c 1 8
    sudo mknod -m 666 dev/urandom c 1 9
    sudo mknod -m 600 dev/eth0 c 10 1

    # Create /dev/dri and device nodes
    mkdir -p dev/dri
    sudo mknod dev/dri/card0 c 226 0
    sudo mknod dev/dri/renderD128 c 226 128

    # Create input devices
    mkdir -p dev/input
    sudo mknod dev/input/event0 c 13 64
    sudo mknod dev/input/event1 c 13 65
    sudo mknod dev/input/mouse0 c 13 32

    # Create symlinks for libraries
    ln -s /lib64/ld-linux-x86-64.so.2 lib/ld-linux-x86-64.so.2
    ln -s /lib64/libc.so.6 lib/libc.so.6
cd ..

# Create init script with networking setup and starting LabWC
cat > initramfs/init << 'EOF'
#!/bin/sh

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run

# Initialize networking
ifconfig lo up
ifconfig eth0 up
udhcpc -i eth0

# Set environment variables for Wayland
mkdir -p /run/user/0
export XDG_RUNTIME_DIR=/run/user/0
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
export LIBSEAT_BACKEND=direct

# Start Weston
# weston --tty=1 &

# Keep the shell open
/bin/sh
EOF
chmod +x initramfs/init

# Create the initramfs image
cd initramfs
    find . | cpio -o -H newc | gzip > ../initramfs.img
cd ..

# Run QEMU with network options and graphical output
qemu-system-x86_64 -m 4G \
  -kernel bzImage \
  -initrd initramfs.img \
  -append "console=tty0 init=/init drm.debug=0x1e" \
  -device e1000,netdev=net0 \
  -netdev user,id=net0 \
  -serial stdio
