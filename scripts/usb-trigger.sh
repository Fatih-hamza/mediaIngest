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

# 1. Mount on Proxmox host - with dirty mount detection
echo "Attempting to mount $DEVICE..."
mount -t ntfs3 -o noatime "$DEVICE" "$HOST_MOUNT" 2>&1

# Check if mount failed due to dirty filesystem
if [ $? -ne 0 ]; then
    echo "Mount failed. Checking if filesystem is dirty..."
    
    # Try ntfsfix to repair dirty NTFS filesystem
    if command -v ntfsfix &> /dev/null; then
        echo "Running ntfsfix to repair filesystem..."
        ntfsfix -d "$DEVICE"
        
        # Retry mount after ntfsfix
        echo "Retrying mount after ntfsfix..."
        mount -t ntfs3 -o noatime "$DEVICE" "$HOST_MOUNT" 2>&1
    fi
    
    # Fallback to standard mount if ntfs3 still fails
    if [ $? -ne 0 ]; then
        echo "ntfs3 failed, trying standard mount..."
        mount "$DEVICE" "$HOST_MOUNT"
    fi
fi

# Verify Mount
if ! mount | grep -q "$HOST_MOUNT"; then
    echo "Failed to mount $DEVICE"
    exit 1
fi

echo "Mounted successfully. Triggering LXC Ingest..."

# 2. Run ingest script inside LXC
pct exec $LXC_ID -- /usr/local/bin/ingest-media.sh

# 3. Cleanup
echo "Ingest finished. Syncing data..."
sync

echo "Complete. Drive remains mounted for dashboard storage stats."
