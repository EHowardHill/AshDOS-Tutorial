# Run QEMU with network options
qemu-system-x86_64 -m 4G \
  -kernel bzImage \
  -initrd initramfs.img \
  -append "console=tty0 init=/init nomodeset drm.debug=0x1e" \
  -device virtio-vga \
  -device e1000,netdev=net0 \
  -netdev user,id=net0 \
  -serial stdio