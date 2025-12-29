#!/bin/bash
# Quick deployment script - run this manually with sudo access

echo "===================================================================="
echo "  Camera Master Image Deployment"
echo "===================================================================="
echo ""
echo "Target: /dev/rdisk6 (64GB SD card)"
echo "Image: ~/Desktop/camera-master-v1.0.img.gz"
echo ""
echo "⚠️  This will ERASE all data on /dev/disk6"
echo ""
read -p "Type 'yes' to proceed: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "[1/3] Unmounting SD card..."
diskutil unmountDisk /dev/disk6 || diskutil unmountDisk force /dev/disk6

echo ""
echo "[2/3] Writing image to SD card..."
echo "This will take several minutes..."
cd ~/Desktop
gunzip -c camera-master-v1.0.img.gz | sudo dd of=/dev/rdisk6 bs=4m status=progress

echo ""
echo "[3/3] Syncing data..."
sudo sync

echo ""
echo "[4/4] Ejecting SD card..."
diskutil eject /dev/disk6

echo ""
echo "===================================================================="
echo "  ✅ Deployment Complete!"
echo "===================================================================="
echo ""
echo "Next steps:"
echo "  1. Remove the SD card from your Mac"
echo "  2. Insert it into the Raspberry Pi"
echo "  3. Power on the Raspberry Pi"
echo ""


