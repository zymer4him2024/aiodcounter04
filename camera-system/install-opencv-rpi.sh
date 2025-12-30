#!/bin/bash
################################################################################
# Install OpenCV on Raspberry Pi for camera agent
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing OpenCV on Raspberry Pi                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on RPi
if [ ! -f /proc/cpuinfo ] || ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  This script is designed for Raspberry Pi"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "[1/4] Updating package list..."
sudo apt-get update -qq
echo "   ✓ Package list updated"
echo ""

echo "[2/4] Installing system dependencies..."
echo "   This may take a few minutes on Raspberry Pi..."

# Install essential packages first
sudo apt-get install -y python3-opencv python3-pip 2>&1 | grep -E "(Reading|Unpacking|Setting|E:|W:)" || true

if python3 -c "import cv2" 2>/dev/null; then
    echo "   ✓ OpenCV installed successfully via apt-get"
    OPENCV_INSTALLED=true
else
    echo "   ⚠️  System package installation may have issues, will try pip..."
    OPENCV_INSTALLED=false
fi
echo ""

echo "[3/4] Installing Python OpenCV package..."
if [ "$OPENCV_INSTALLED" = true ]; then
    echo "   ✓ OpenCV already installed via system package"
else
    echo "   Installing opencv-python-headless via pip..."
    echo "   (This may take 5-10 minutes on Raspberry Pi - please wait...)"
    
    sudo pip3 install --break-system-packages opencv-python-headless 2>&1 | tee /tmp/opencv_install.log | grep -E "(Collecting|Downloading|Installing|Successfully|ERROR)" || true
    
    if python3 -c "import cv2" 2>/dev/null; then
        echo "   ✓ OpenCV installed successfully via pip"
    else
        echo "   ⚠️  pip installation failed, checking error log..."
        echo "   Last 10 lines of install log:"
        tail -10 /tmp/opencv_install.log 2>/dev/null || true
        echo ""
        echo "   Trying minimal installation..."
        sudo apt-get install -y python3-opencv 2>&1 | tail -5 || true
    fi
fi
echo ""

echo "[4/4] Verifying OpenCV installation..."
python3 << 'PYTHON_EOF'
import cv2
import sys

print(f"   OpenCV version: {cv2.__version__}")

# Try to open camera
cap = cv2.VideoCapture(0)
if cap.isOpened():
    print("   ✓ Camera can be opened")
    ret, frame = cap.read()
    if ret:
        print(f"   ✓ Camera is capturing frames: {frame.shape[1]}x{frame.shape[0]}")
    else:
        print("   ⚠️  Camera opened but failed to capture frame")
    cap.release()
else:
    print("   ⚠️  Could not open camera (may not be connected)")
PYTHON_EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ OpenCV Installation Complete!            ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "You can now run the camera agent startup script:"
    echo "  sudo /tmp/start-od-with-usb-camera.sh"
    echo ""
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  Installation Completed with Warnings    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Please check the errors above and try again if needed."
    echo ""
fi

