#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y build-essential gcc g++ make libncurses-dev bison flex libssl-dev libelf-dev bc autoconf automake libtool git qemu-system-x86 cpio gzip gawk texinfo sudo
sudo apt install -y libcap-dev libarchive-dev libcurl4-openssl-dev libpolkit-agent-1-dev libfuse-dev libostree-dev libjson-glib-dev libappstream-dev libgpgme-dev
sudo apt install -y x11proto-core-dev libxkbfile-dev libxfont-dev libxcvt-dev libgl1-mesa-dri mesa-common-dev libdrm-dev xorg-dev

# ---------------------
# Pull Source Code
# ---------------------

#git clone https://github.com/torvalds/linux
#git clone https://github.com/bminor/glibc
#git clone https://github.com/mirror/busybox
#git clone https://github.com/flatpak/flatpak
#git clone https://github.com/kennylevinsen/seatd
#git clone https://github.com/eudev-project/eudev
#git clone https://gitlab.freedesktop.org/xorg/app/xinit
#git clone https://gitlab.freedesktop.org/xorg/driver/xf86-video-modesetting
#git clone https://gitlab.freedesktop.org/xorg/driver/xf86-input-evdev
#git clone https://gitlab.freedesktop.org/xorg/driver/xf86-input-libinput

# ---------------------
# Build from Source
# ---------------------

# Create a directory for the initial ramdisk
rm -rf initramfs/*
mkdir -p initramfs/{proc,sys,tmp,lib,dev,home,etc/network,usr/share/udhcpc}

# Step 1: Compile Linux Kernel
echo "Compiling Linux Kernel..."
#cd ./linux
#    make defconfig
#    make -j$(nproc) bzImage
#cd ..

# Step 2: Compile glibc
echo "Compiling glibc..."
#cd glibc
#    mkdir -p build
#    cd build
#        ../configure --prefix=/usr --disable-multilib
#        make -j$(nproc)
#        make DESTDIR=$(pwd)/install install
#    cd ..
#cd ..

# Step 3: Compile BusyBox with networking tools
echo "Compiling BusyBox..."
#cd ./busybox
#    make defconfig
#    make -j$(nproc)
#    make install
#cd ..

cd ./flatpak
    #meson setup builddir
    cd builddir
        #meson compile
        mkdir -p install
        meson install --destdir install
    cd ..
cd ..

#echo "Compiling eudev..."
#cd eudev
#    mkdir -p build
#    cd build
#        ../configure
#        make -j$(nproc)
#        make DESTDIR=$(pwd)/install install
#    cd ..
#cd ..

#echo "Compiling xinit..."
#cd xinit
#   ./autogen.sh
#    mkdir -p build
#    cd build
#        ../configure
#        make -j$(nproc)
#        make DESTDIR=$(pwd)/install install
#    cd ..
#cd ..

# Copy binaries
cp linux/arch/x86/boot/bzImage bzImage
cp -a glibc/build/install/* initramfs/
cp -a busybox/_install/* initramfs/
cp -a flatpak/builddir/install/* initramfs/
cp -a eudev/build/install/* initramfs/
cp -a xserver/builddir/install/* initramfs/
cp -a xinit/build/install/* initramfs/

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

    ln -s /lib64/ld-linux-x86-64.so.2 lib/ld-linux-x86-64.so.2
    ln -s /lib64/libm.so.6 lib/libm.so.6
    ln -s /lib64/libresolv.so.2 lib/libresolv.so.2
    ln -s /lib64/libc.so.6 lib/libc.so.6
cd ..

mkdir -p initramfs/etc/X11
mkdir -p initramfs/var/local/log
cat > initramfs/etc/X11/xorg.conf << 'EOF'
Section "Device"
    Identifier "Card0"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "Card0"
EndSection
EOF

# Create init script with networking setup
cat > initramfs/init << 'EOF'
#!/bin/sh

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Initialize networking
ifconfig lo up
ifconfig eth0 up
udhcpc -i eth0

/usr/local/bin/X
/bin/sh
EOF
chmod +x initramfs/init

# Setup DNS
cat > initramfs/etc/resolv.conf << EOF
nameserver 208.67.222.123
nameserver 208.67.220.123
EOF
chmod +x initramfs/etc/resolv.conf

# Set up DPKG
mkdir -p initramfs/var/lib/dpkg/info
cat > initramfs/var/lib/dpkg/status << EOF
Package: libc6
Status: install ok installed
Architecture: amd64
Version: 2.40-2

EOF

# Create the initramfs image
./rebuild-initramfs.sh