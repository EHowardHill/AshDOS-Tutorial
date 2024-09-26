#!/bin/bash

BINARY=$1
INITRAMFS_LIB64_DIR="./initramfs/lib64"

ldd "$BINARY" | grep "=>" | awk '{print $3}' | while read -r lib; do
  if [ -f "$lib" ]; then
    cp "$lib" "$INITRAMFS_LIB64_DIR/"
    echo "Copied: $lib to $INITRAMFS_LIB64_DIR/"
  fi
done

echo "All libraries have been copied to $INITRAMFS_LIB64_DIR."