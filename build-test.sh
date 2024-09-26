#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y build-essential gcc g++ make libncurses-dev bison flex libssl-dev libelf-dev bc autoconf automake libtool git qemu-system-x86 cpio gzip gawk texinfo sudo
sudo apt install -y libcap-dev libarchive-dev libcurl4-openssl-dev libpolkit-agent-1-dev libfuse-dev libostree-dev libjson-glib-dev libappstream-dev libgpgme-dev

# Install dependencies for Xorg Server
sudo apt install -y xorg-dev libx11-dev libxkbfile-dev libxfont-dev libpixman-1-dev libpciaccess-dev libudev-dev libdrm-dev libinput-dev

# ---------------------
# Pull Source Code
# ---------------------

#git clone https://github.com/torvalds/linux
#git clone https://github.com/bminor/glibc
#git clone https://github.com/mirror/busybox
#git clone https://github.com/flatpak/flatpak
#git clone https://gitlab.freedesktop.org/xorg/xserver.git

# ---------------------
# Build from Source
# ---------------------

# Create a directory for the initial ramdisk
rm -rf initramfs/*
mkdir -p initramfs/{proc,sys,tmp,lib,dev,home,etc/network,usr/share/udhcpc}

# Step 1: Compile Linux Kernel with framebuffer support
echo "Compiling Linux Kernel..."
cd ./linux
    make defconfig
    # Enable framebuffer support
    scripts/config --enable CONFIG_FB
    scripts/config --enable CONFIG_FB_VESA
    scripts/config --enable CONFIG_FB_EFI
    scripts/config --enable CONFIG_FB_VGA16
    scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
    scripts/config --enable CONFIG_VGA_CONSOLE
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
cd ./busybox
    make defconfig
    make -j$(nproc)
    make install
cd ..

cd ./flatpak
    #meson setup builddir
    cd builddir
        #meson compile
        mkdir -p install
        meson install --destdir install
    cd ..
cd ..

# Step 4: Compile Xorg Server with framebuffer support
echo "Compiling Xorg Server..."
cd xserver
    ./autogen.sh --prefix=/usr --disable-dri --disable-dri2 --disable-dri3 --disable-glamor --disable-glx --disable-xwayland --disable-xwin --disable-xvfb --disable-xnest --disable-xorg --enable-xfbdev
    make -j$(nproc)
    make DESTDIR=$(pwd)/install install
cd ..

# Copy binaries
cp linux/arch/x86/boot/bzImage bzImage
cp -a glibc/build/install/* initramfs/
cp -a busybox/_install/* initramfs/
cp -a flatpak/builddir/install/* initramfs/
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
    sudo mknod -m 666 dev/fb0 c 29 0  # Add framebuffer device

    ln -s /lib64/ld-linux-x86-64.so.2 lib/ld-linux-x86-64.so.2
    ln -s /lib64/libm.so.6 lib/libm.so.6
    ln -s /lib64/libresolv.so.2 lib/libresolv.so.2
    ln -s /lib64/libc.so.6 lib/libc.so.6
cd ..

# Create init script to start Xorg Server
cat > initramfs/init << 'EOF'
#!/bin/sh

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Start X framebuffer server
exec /usr/bin/Xfbdev
EOF
chmod +x initramfs/init

# Create the initramfs image
cd initramfs
    find . | cpio -o -H newc | gzip > ../initramfs.img
cd ..

# Run QEMU with graphical options
qemu-system-x86_64 -m 4G \
  -kernel bzImage \
  -initrd initramfs.img \
  -append "console=tty0 init=/init nomodeset drm.debug=0x1e" \
  -device virtio-vga \
  -device e1000,netdev=net0 \
  -netdev user,id=net0 \
  -serial stdio
