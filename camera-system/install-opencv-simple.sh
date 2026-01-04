#!/bin/bash
################################################################################
# Simple OpenCV Installation for Raspberry Pi
# Minimal installation - just what's needed
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Simple OpenCV Installation for Raspberry Pi                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "[1/3] Updating package list..."
sudo apt-get update

echo ""
echo "[2/3] Installing OpenCV (this may take a few minutes)..."
sudo apt-get install -y python3-opencv

echo ""
echo "[3/3] Verifying installation..."
python3 << 'PYTHON_EOF'
import sys
try:
    import cv2
    print(f"✓ OpenCV {cv2.__version__} installed successfully")
    
    # Test camera
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        print("✓ Camera can be opened")
        ret, frame = cap.read()
        if ret:
            print(f"✓ Camera is working: {frame.shape[1]}x{frame.shape[0]}")
        else:
            print("⚠ Camera opened but no frame captured (camera may not be connected)")
        cap.release()
    else:
        print("⚠ Could not open camera (camera may not be connected)")
    sys.exit(0)
except ImportError as e:
    print(f"✗ OpenCV not installed: {e}")
    sys.exit(1)
except Exception as e:
    print(f"⚠ Error testing: {e}")
    sys.exit(0)
PYTHON_EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Installation Complete!                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "You can now run:"
    echo "  sudo /tmp/start-od-with-usb-camera.sh"
    echo ""
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ❌ Installation Failed                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Try running manually:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y python3-opencv"
    echo ""
fi


