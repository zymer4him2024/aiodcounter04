#!/bin/bash
################################################################################
# Camera Master Image Deployment - READY TO RUN
# Just execute: ./DEPLOY.sh
################################################################################

set -e

IMAGE="$HOME/Desktop/camera-master-v1.0.img.gz"
TARGET_DISK="rdisk6"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Camera Master Image Deployment                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Verify image exists
if [ ! -f "$IMAGE" ]; then
    echo "❌ ERROR: Image file not found at: $IMAGE"
    exit 1
fi

echo "✅ Image file: $IMAGE"
echo "   Size: $(ls -lh "$IMAGE" | awk '{print $5}')"
echo ""

# Verify SD card is present
if ! diskutil list "/dev/disk6" &>/dev/null; then
    echo "❌ ERROR: SD card not detected at /dev/disk6"
    echo ""
    echo "Please:"
    echo "  1. Insert the SD card"
    echo "  2. Wait a few seconds"
    echo "  3. Run this script again"
    exit 1
fi

echo "✅ SD card detected: /dev/disk6"
DISK_SIZE=$(diskutil info /dev/disk6 | grep "Disk Size" | awk '{print $3, $4}')
echo "   Size: $DISK_SIZE"
echo ""

# Show what will happen
echo "⚠️  WARNING: This will ERASE all data on /dev/disk6"
echo ""
echo "The deployment will:"
echo "  1. Unmount the SD card"
echo "  2. Write the compressed image (will prompt for sudo password)"
echo "  3. Sync data to ensure write completion"
echo "  4. Eject the SD card"
echo ""
read -p "Type 'DEPLOY' (all caps) to proceed: " confirm

if [ "$confirm" != "DEPLOY" ]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Unmount
echo "[1/4] Unmounting SD card..."
diskutil unmountDisk /dev/disk6 2>/dev/null || \
diskutil unmountDisk force /dev/disk6 2>/dev/null || \
echo "   (Already unmounted)"
echo "✅ Unmounted"
echo ""

# Step 2: Write image
echo "[2/4] Writing image to SD card..."
echo "   ⏱️  This will take 5-15 minutes..."
echo "   📝 You will be prompted for your sudo password"
echo ""
cd ~/Desktop

# This is where you'll enter your password
gunzip -c "$IMAGE" | sudo dd of="/dev/$TARGET_DISK" bs=4m status=progress

WRITE_EXIT=$?
if [ $WRITE_EXIT -ne 0 ]; then
    echo ""
    echo "❌ ERROR: Failed to write image (exit code: $WRITE_EXIT)"
    exit 1
fi

echo ""
echo "✅ Image written successfully"
echo ""

# Step 3: Sync
echo "[3/4] Syncing data..."
sudo sync
echo "✅ Sync complete"
echo ""

# Step 4: Eject
echo "[4/4] Ejecting SD card..."
diskutil eject /dev/disk6
echo "✅ Ejected"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ DEPLOYMENT COMPLETE!                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Remove the SD card from your Mac"
echo "  2. Insert it into the Raspberry Pi"
echo "  3. Power on the Raspberry Pi"
echo ""
echo "On first boot, the camera will:"
echo "  • Start provisioning portal automatically"
echo "  • Create WiFi hotspot"
echo "  • Wait for activation"
echo ""


