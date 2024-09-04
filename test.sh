#!/bin/bash
set -e

qemu-system-x86_64 -m 2G -kernel bzImage -initrd initramfs.img -append "console=ttyS0 init=/init" -nographic -drive file=harddrive.img,format=raw,index=0,media=disk
