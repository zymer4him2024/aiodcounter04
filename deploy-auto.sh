#!/bin/bash
# Deployment script - auto-confirms, but will prompt for sudo password

set -e

echo "===================================================================="
echo "  Camera Master Image Deployment"
echo "===================================================================="
echo ""
echo "Target: /dev/rdisk6 (64GB SD card)"
echo "Image: ~/Desktop/camera-master-v1.0.img.gz"
echo ""
echo "⚠️  This will ERASE all data on /dev/disk6"
echo ""
echo "Proceeding in 2 seconds..."
sleep 2

echo ""
echo "[1/4] Unmounting SD card..."
diskutil unmountDisk /dev/disk6 2>/dev/null || diskutil unmountDisk force /dev/disk6 2>/dev/null || echo "Already unmounted or failed (continuing...)"

echo ""
echo "[2/4] Writing image to SD card..."
echo "⚠️  You will be prompted for your sudo password"
echo "This will take 5-15 minutes depending on SD card speed..."
echo ""
cd ~/Desktop

# Write the image (will prompt for sudo password)
gunzip -c camera-master-v1.0.img.gz | sudo dd of=/dev/rdisk6 bs=4m status=progress

echo ""
echo "[3/4] Syncing data to ensure write completion..."
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
echo "  4. On first boot, the camera will:"
echo "     - Start provisioning portal automatically"
echo "     - Create WiFi hotspot"
echo "     - Wait for activation"
echo ""




