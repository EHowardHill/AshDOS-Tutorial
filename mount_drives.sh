#!/bin/sh

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Create /drives directory if it doesn't exist
mkdir -p /drives

# Get the list of all available hard drive partitions (excluding loopback and non-disk devices)
DRIVES=$(lsblk -rno NAME,TYPE | grep 'part$' | awk '{print "/dev/"$1}')

# Initialize a flag to track if /usr has been mounted
USR_MOUNTED=0

# Iterate through all detected drives
for DRIVE in $DRIVES; do
  # Check if the partition is already mounted
  if mount | grep -q "$DRIVE"; then
    echo "$DRIVE is already mounted."
    continue
  fi

  # If /usr is not mounted yet, mount the first partition as /usr
  if [ $USR_MOUNTED -eq 0 ]; then
    echo "Mounting $DRIVE as /usr..."
    mount "$DRIVE" /usr
    if [ $? -eq 0 ]; then
      USR_MOUNTED=1
    else
      echo "Failed to mount $DRIVE as /usr."
    fi
  else
    # Mount subsequent partitions under /drives
    MOUNT_POINT="/drives/$(basename $DRIVE)"
    echo "Mounting $DRIVE at $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
    mount "$DRIVE" "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
      echo "Failed to mount $DRIVE at $MOUNT_POINT."
    fi
  fi
done

echo "All available drives have been mounted."
