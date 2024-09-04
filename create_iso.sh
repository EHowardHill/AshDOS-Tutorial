#!/bin/bash
set -e

# Install required packages
sudo apt install -y syslinux isolinux genisoimage

# Create directories for ISO
mkdir -p iso/boot/isolinux

# Copy kernel and initramfs to ISO directory
cp linux/arch/x86/boot/bzImage iso/boot/vmlinuz
cp initramfs.img iso/boot/

# Copy isolinux binaries
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 iso/boot/isolinux/
cp /usr/lib/syslinux/modules/bios/libutil.c32 iso/boot/isolinux/
cp /usr/lib/ISOLINUX/isolinux.bin iso/boot/isolinux/
cp /usr/lib/syslinux/modules/bios/menu.c32 iso/boot/isolinux/

# Create isolinux configuration file
cat > iso/boot/isolinux/isolinux.cfg << EOF
DEFAULT linux
LABEL linux
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initramfs.img
PROMPT 1
TIMEOUT 50
EOF

# Create the bootable ISO image
mkisofs -o ashdos.iso -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "ASHDOS" iso/

# Clean up ISO directory (optional)
rm -rf iso
