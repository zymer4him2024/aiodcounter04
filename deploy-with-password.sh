#!/bin/bash
# Deployment script that handles sudo password via osascript

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

# Unmount SD card
echo "[1/4] Unmounting SD card..."
diskutil unmountDisk /dev/disk6 2>/dev/null || diskutil unmountDisk force /dev/disk6 2>/dev/null || true

echo ""
echo "[2/4] Writing image to SD card..."
echo "This will take 5-15 minutes depending on SD card speed..."
echo ""

cd ~/Desktop

# Get password via AppleScript and pass to sudo
PASSWORD=$(osascript -e 'Tell application "System Events" to display dialog "Enter your password to deploy camera image:" default answer "" with hidden answer' -e 'text returned of result' 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    echo "❌ Password required. Please run manually in Terminal."
    exit 1
fi

# Export password for sudo -S
export SUDO_ASKPASS=/bin/echo
echo "$PASSWORD" | sudo -S dd if=<(gunzip -c camera-master-v1.0.img.gz) of=/dev/rdisk6 bs=4m status=progress 2>&1 || {
    echo ""
    echo "⚠️  Automated password failed. Please run manually:"
    echo ""
    echo "cd ~/Desktop"
    echo "gunzip -c camera-master-v1.0.img.gz | sudo dd of=/dev/rdisk6 bs=4m status=progress"
    exit 1
}

echo ""
echo "[3/4] Syncing data..."
echo "$PASSWORD" | sudo -S sync

echo ""
echo "[4/4] Ejecting SD card..."
diskutil eject /dev/disk6

echo ""
echo "===================================================================="
echo "  ✅ Deployment Complete!"
echo "===================================================================="




