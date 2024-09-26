#!/bin/bash

cd initramfs
    find . | cpio -o -H newc | gzip > ../initramfs.img
cd ..