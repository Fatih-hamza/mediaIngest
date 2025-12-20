#!/bin/bash

# Concurrency Lock: Prevent multiple instances from running simultaneously
exec 200>/var/lock/usb-ingest.lock
flock -n 200 || { echo "Another USB ingest operation is already running. Exiting."; exit 1; }

DEVICE=$1
HOST_MOUNT="/mnt/usb-pass"
LXC_ID="__LXC_ID__"

# Safety Check
if [ -z "$DEVICE" ]; then 
    echo "No device specified."
    exit 1
fi

echo "=== USB Device Detected: $DEVICE ==="

# Determine the correct device to mount
# If DEVICE is a whole disk (e.g., /dev/sdb) without partitions, use it directly
# If DEVICE has partitions, use the first partition
MOUNT_DEVICE=""

if [ -b "$DEVICE" ]; then
    # Check if the device itself has a filesystem (whole-disk format)
    if blkid "$DEVICE" | grep -q "TYPE="; then
        echo "Detected whole-disk filesystem on $DEVICE"
        MOUNT_DEVICE="$DEVICE"
    # Otherwise, check for first partition
    elif [ -b "${DEVICE}1" ]; then
        echo "Detected partition at ${DEVICE}1"
        MOUNT_DEVICE="${DEVICE}1"
    else
        echo "No mountable filesystem found on $DEVICE"
        exit 1
    fi
else
    echo "Device $DEVICE does not exist"
    exit 1
fi

echo "Will mount: $MOUNT_DEVICE"

# Check if already mounted
if mount | grep -q "$HOST_MOUNT"; then
    echo "Already mounted at $HOST_MOUNT, running ingest..."
else
    # 1. Mount on Proxmox host - with dirty mount detection
    echo "Attempting to mount $MOUNT_DEVICE..."
    
    # Try ntfs3 first (kernel driver, faster)
    mount -t ntfs3 -o noatime "$MOUNT_DEVICE" "$HOST_MOUNT" 2>&1
    
    # Check if mount failed
    if [ $? -ne 0 ]; then
        echo "ntfs3 failed. Trying ntfs-3g (FUSE)..."
        mount -t ntfs-3g "$MOUNT_DEVICE" "$HOST_MOUNT" 2>&1
    fi
    
    # If still failed, check for dirty filesystem
    if [ $? -ne 0 ]; then
        echo "Mount failed. Checking if filesystem is dirty..."
        
        # Try ntfsfix to repair dirty NTFS filesystem
        if command -v ntfsfix &> /dev/null; then
            echo "Running ntfsfix to repair filesystem..."
            ntfsfix -d "$MOUNT_DEVICE"
            
            # Retry mount after ntfsfix
            echo "Retrying mount after ntfsfix..."
            mount -t ntfs-3g "$MOUNT_DEVICE" "$HOST_MOUNT" 2>&1
        fi
    fi
    
    # Verify Mount
    if ! mount | grep -q "$HOST_MOUNT"; then
        echo "Failed to mount $MOUNT_DEVICE"
        exit 1
    fi
    
    echo "Mounted successfully."
fi

echo "Mounted successfully. Triggering LXC Ingest..."

# 2. Run ingest script inside LXC
pct exec $LXC_ID -- /usr/local/bin/ingest-media.sh

# 3. Cleanup
echo "Ingest finished. Syncing data..."
sync

echo "Complete. Drive remains mounted for dashboard storage stats."
