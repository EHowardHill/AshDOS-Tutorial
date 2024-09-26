#!/bin/sh

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Detect the network interface (excluding loopback)
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

if [ -z "$INTERFACE" ]; then
  echo "No network interface detected."
  exit 1
fi

echo "Detected network interface: $INTERFACE"

# Bring the interface up
ip link set "$INTERFACE" up

# Use udhcpc to obtain an IP address dynamically
echo "Requesting an IP address via DHCP..."
udhcpc -i "$INTERFACE" -s /usr/share/udhcpc/default.script

if [ $? -eq 0 ]; then
  echo "Network configuration successful for interface $INTERFACE."
else
  echo "Failed to configure the network."
  exit 1
fi

# Display network interface status
ip addr show "$INTERFACE"
