#!/bin/bash
################################################################################
# Camera Master Image Deployment Script
# Deploys camera-master-v1.0.img.gz from Desktop to SD card
################################################################################

set -e

IMAGE_FILE="$HOME/Desktop/camera-master-v1.0.img.gz"
DISK_PREFIX=""

echo "===================================================================="
echo "  Camera Master Image Deployment"
echo "===================================================================="
echo ""

# Check if image file exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "❌ Error: Image file not found at $IMAGE_FILE"
    exit 1
fi

echo "✅ Found image file: $IMAGE_FILE"
echo "   Size: $(ls -lh "$IMAGE_FILE" | awk '{print $5}')"
echo ""

# List all disks
echo "Scanning for SD cards..."
echo ""

# Find SD card (external, physical disk that's not the main drive)
DISK_LIST=$(diskutil list | grep -E "^/dev/disk[0-9]+ \(" | grep -v "internal" | grep "physical" | head -1)

if [ -z "$DISK_LIST" ]; then
    echo "⚠️  No external SD card detected!"
    echo ""
    echo "Please:"
    echo "  1. Insert the SD card into your Mac"
    echo "  2. Wait a few seconds for it to mount"
    echo "  3. Run this script again"
    echo ""
    echo "Current disks:"
    diskutil list | grep -E "^/dev/disk[0-9]+"
    exit 1
fi

# Extract disk identifier (e.g., disk2)
DISK_ID=$(echo "$DISK_LIST" | awk '{print $1}' | sed 's|/dev/||')
DISK_SIZE=$(echo "$DISK_LIST" | awk '{print $NF}')

echo "📀 Detected SD card:"
echo "   Device: /dev/$DISK_ID"
echo "   Size: $DISK_SIZE"
echo ""

# Show partition info for confirmation
echo "Partitions on this disk:"
diskutil list "/dev/$DISK_ID" | tail -n +2
echo ""

# Safety check - ask for confirmation
read -p "⚠️  WARNING: This will ERASE all data on /dev/$DISK_ID. Continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Unmount the disk
echo "[1/4] Unmounting SD card..."
diskutil unmountDisk "/dev/$DISK_ID" || {
    # Try unmounting all volumes on the disk
    diskutil unmountDisk force "/dev/$DISK_ID" || true
}
echo "✅ Unmounted"
echo ""

# Deploy image
echo "[2/4] Deploying image to SD card..."
echo "   This may take several minutes (4.8GB compressed → ~16-32GB uncompressed)..."
echo ""

if command -v pv >/dev/null 2>&1; then
    # Use pv for progress if available
    echo "   Using pv for progress..."
    gunzip -c "$IMAGE_FILE" | pv | sudo dd of="/dev/r$DISK_ID" bs=4m status=none
else
    # Fallback to dd with status=progress
    gunzip -c "$IMAGE_FILE" | sudo dd of="/dev/r$DISK_ID" bs=4m status=progress
fi

echo ""
echo "✅ Image written successfully"
echo ""

# Sync to ensure all data is written
echo "[3/4] Syncing data to SD card..."
sudo sync
echo "✅ Sync complete"
echo ""

# Eject the disk
echo "[4/4] Ejecting SD card..."
diskutil eject "/dev/$DISK_ID"
echo "✅ Ejected"
echo ""

echo "===================================================================="
echo "  ✅ Deployment Complete!"
echo "===================================================================="
echo ""
echo "Next steps:"
echo "  1. Remove the SD card from your Mac"
echo "  2. Insert it into the Raspberry Pi"
echo "  3. Power on the Raspberry Pi"
echo "  4. On first boot, the camera will:"
echo "     - Start provisioning portal automatically"
echo "     - Create WiFi hotspot"
echo "     - Wait for activation"
echo ""



