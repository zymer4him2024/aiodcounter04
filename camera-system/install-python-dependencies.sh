#!/bin/bash
################################################################################
# Install All Python Dependencies for Camera Agent
# This installs Firebase, OpenCV, SQLAlchemy, and optionally Hailo/TFLite
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing Python Dependencies for Camera Agent               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "[1/6] Installing Firebase Admin SDK..."
sudo pip3 install --break-system-packages firebase-admin 2>&1 | tail -5

if python3 -c "import firebase_admin" 2>/dev/null; then
    echo "   ✓ firebase-admin installed"
else
    echo "   ✗ firebase-admin installation failed"
    exit 1
fi
echo ""

echo "[2/6] Installing OpenCV (if not already installed)..."
if python3 -c "import cv2" 2>/dev/null; then
    OPENCV_VERSION=$(python3 -c "import cv2; print(cv2.__version__)")
    echo "   ✓ OpenCV already installed: $OPENCV_VERSION"
else
    echo "   Installing OpenCV..."
    sudo apt-get install -y python3-opencv 2>&1 | grep -E "(Reading|Unpacking|Setting)" || true
    
    if python3 -c "import cv2" 2>/dev/null; then
        echo "   ✓ OpenCV installed"
    else
        echo "   Installing via pip..."
        sudo pip3 install --break-system-packages opencv-python-headless 2>&1 | tail -3
        if python3 -c "import cv2" 2>/dev/null; then
            echo "   ✓ OpenCV installed via pip"
        fi
    fi
fi
echo ""

echo "[3/6] Installing SQLAlchemy..."
sudo pip3 install --break-system-packages sqlalchemy 2>&1 | tail -3

if python3 -c "import sqlalchemy" 2>/dev/null; then
    echo "   ✓ SQLAlchemy installed"
else
    echo "   ✗ SQLAlchemy installation failed"
    exit 1
fi
echo ""

echo "[4/6] Checking for Hailo-8 support..."
if python3 -c "from hailo_platform import HEF, VDevice" 2>/dev/null; then
    echo "   ✓ Hailo-8 SDK already available"
    HAILO_AVAILABLE=true
else
    echo "   Hailo-8 SDK not found (optional - will use TFLite if available)"
    HAILO_AVAILABLE=false
fi
echo ""

echo "[5/6] Checking for TensorFlow Lite (fallback)..."
if python3 -c "import tflite_runtime.interpreter as tflite" 2>/dev/null; then
    echo "   ✓ TensorFlow Lite Runtime already installed"
    TFLITE_AVAILABLE=true
elif [ "$HAILO_AVAILABLE" = false ]; then
    echo "   Installing TensorFlow Lite Runtime (fallback)..."
    sudo pip3 install --break-system-packages tflite-runtime 2>&1 | tail -5
    
    if python3 -c "import tflite_runtime.interpreter as tflite" 2>/dev/null; then
        echo "   ✓ TensorFlow Lite Runtime installed"
        TFLITE_AVAILABLE=true
    else
        echo "   ⚠️  TensorFlow Lite installation failed (optional if using Hailo)"
        TFLITE_AVAILABLE=false
    fi
else
    echo "   ⚠️  Skipping TFLite (Hailo-8 available)"
    TFLITE_AVAILABLE=false
fi
echo ""

echo "[6/6] Installing additional utilities..."
sudo pip3 install --break-system-packages psutil 2>&1 | tail -2
echo "   ✓ Additional utilities installed"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Installation Summary                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Verify all critical dependencies
echo "Verifying installations..."
python3 << 'PYTHON_EOF'
import sys
errors = []

try:
    import firebase_admin
    print("✓ firebase_admin")
except ImportError:
    print("✗ firebase_admin")
    errors.append("firebase_admin")

try:
    import cv2
    print(f"✓ opencv-python (version {cv2.__version__})")
except ImportError:
    print("✗ opencv-python")
    errors.append("opencv")

try:
    import sqlalchemy
    print("✓ sqlalchemy")
except ImportError:
    print("✗ sqlalchemy")
    errors.append("sqlalchemy")

# Check optional dependencies
try:
    from hailo_platform import HEF, VDevice
    print("✓ hailo_platform (Hailo-8 support)")
except ImportError:
    print("⚠ hailo_platform (not installed - optional)")

try:
    import tflite_runtime.interpreter as tflite
    print("✓ tflite_runtime (fallback)")
except ImportError:
    print("⚠ tflite_runtime (not installed - optional if using Hailo)")

if errors:
    print(f"\n❌ Critical dependencies missing: {', '.join(errors)}")
    sys.exit(1)
else:
    print("\n✅ All critical dependencies installed!")
    sys.exit(0)
PYTHON_EOF

INSTALL_RESULT=$?

if [ $INSTALL_RESULT -eq 0 ]; then
    echo ""
    echo "You can now start the camera agent:"
    echo "  sudo systemctl restart camera-agent"
    echo "  sudo journalctl -u camera-agent -f"
    echo ""
else
    echo ""
    echo "Some dependencies failed to install. Please check the errors above."
    echo ""
fi

