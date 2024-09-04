#!/bin/bash
set -e

sudo apt update -y
sudo apt install -y build-essential gcc g++ make libncurses-dev bison flex libssl-dev libelf-dev bc autoconf automake libtool git qemu-system-x86 cpio gzip

git clone https://github.com/torvalds/linux
git clone https://github.com/bminor/glibc
git clone https://github.com/mirror/busybox

# Create a directory for the initial ramdisk
rm -rf initramfs/*
mkdir -p initramfs/{proc,sys,tmp,lib,dev,etc/network,usr/share/udhcpc}

# Step 1: Compile Linux Kernel
echo "Compiling Linux Kernel..."
cd ./linux
    make defconfig
    make -j$(nproc) bzImage
cd ..

# Step 2: Compile glibc
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

# Copy binaries
cp -a glibc/build/install/* initramfs/
cp -a busybox/_install/* initramfs/

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

# Create init script with networking setup
cat > initramfs/init << EOF
#!/bin/sh

# Set up initial configuration
mount -t proc proc /proc &
mount -t sysfs sysfs /sys &
mount -t devtmpfs devtmpfs /dev &

# Init messages
clear
echo "Welcome to AshDOS!"
date
free -h | grep Mem
echo ""

# Start task
setsid cttyhack sh
exec /bin/sh
poweroff -f
EOF
chmod +x initramfs/init

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
cd initramfs
    find . | cpio -o -H newc | gzip > ../initramfs.img
cd ..

cp linux/arch/x86/boot/bzImage bzImage

# Run QEMU with network options
qemu-system-x86_64 -m 2G -kernel bzImage -initrd initramfs.img -append "console=ttyS0 init=/init quiet loglevel=3" -nographic -net nic -net user