#!/bin/bash
set -e

# Update and install required packages
sudo apt update -y
sudo apt install -y \
    build-essential gcc g++ make libncurses-dev bison flex libssl-dev libelf-dev bc \
    autoconf automake libtool git qemu-system-x86 cpio gzip gawk texinfo sudo \
    libcap-dev libarchive-dev libcurl4-openssl-dev
sudo apt install -y \
    xorg xserver-xorg-core xinit xserver-xorg-video-fbdev qemu-system-x86 libx11-dev \
    libxext-dev libxrandr-dev libxkbfile-dev libxfont-dev
sudo apt install -y mesa-common-dev libepoxy-dev
sudo apt install -y libgl1-mesa-dev libegl1-mesa-dev libgbm-dev libx11-dev libxext-dev
sudo apt install -y rustc bindgen libclc-19-dev libllvmspirvlib-17-dev libclang-dev

# ---------------------
# Pull Source Code
# ---------------------

git clone https://github.com/torvalds/linux
git clone https://github.com/bminor/glibc
git clone https://github.com/mirror/busybox
git clone https://gitlab.freedesktop.org/mesa/mesa

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

# Step 4: Compile xserver
echo "Compiling xserver..."
cd xserver
    meson build --prefix=/usr
    ninja -C build
    DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Step 5: Compile xserver
echo "Compiling mesa..."
cd mesa
    meson build --prefix=/usr
    ninja -C build
    DESTDIR=$(pwd)/install ninja -C build install
cd ..

# Copy binaries and libraries to initramfs
cp linux/arch/x86/boot/bzImage bzImage
cp -a glibc/build/install/* initramfs/
cp -a busybox/_install/* initramfs/
cp -a xserver/install/* initramfs/

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

mkdir -p initramfs/etc/X11/
cat > initramfs/etc/X11/xorg.conf << 'EOF'
Section "Device"
    Identifier "Card0"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "Card0"
    DefaultDepth 24
EndSection

Section "Monitor"
    Identifier "Monitor0"
EndSection

Section "ServerLayout"
    Identifier "Layout0"
    Screen 0 "Screen0"
EndSection
EOF

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

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
Xorg &

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
  -device VGA \
  -device e1000,netdev=net0 \
  -netdev user,id=net0 \
  -serial stdio

# libGL.so.1
# libGLdispatch.so.0
# libGLX.so.0
# libdbus-1.so.3