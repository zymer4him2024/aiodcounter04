#!/bin/bash
################################################################################
# Install TensorFlow Lite Runtime for Raspberry Pi
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing TensorFlow Lite Runtime for Raspberry Pi          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Detect Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "[1/4] Detected Python version: $PYTHON_VERSION"
echo ""

# Detect architecture
ARCH=$(uname -m)
echo "[2/4] Detected architecture: $ARCH"

# For Raspberry Pi, we typically need armv7l or aarch64
if [[ "$ARCH" == "armv7l" ]] || [[ "$ARCH" == "armv6l" ]]; then
    WHEEL_PLATFORM="linux_armv7l"
elif [[ "$ARCH" == "aarch64" ]]; then
    WHEEL_PLATFORM="linux_aarch64"
else
    echo "⚠️  Unknown architecture, trying generic installation..."
    WHEEL_PLATFORM=""
fi
echo ""

echo "[3/4] Installing TensorFlow Lite Runtime..."
echo "   This may take a few minutes..."

# Try installing from PyPI first (works for most Raspberry Pi models)
if sudo pip3 install --break-system-packages tflite-runtime 2>&1 | tee /tmp/tflite_install.log; then
    if python3 -c "import tflite_runtime" 2>/dev/null; then
        echo "   ✓ TensorFlow Lite Runtime installed successfully"
        INSTALLED=true
    else
        echo "   ⚠️  Installation completed but import failed"
        INSTALLED=false
    fi
else
    echo "   ⚠️  pip install failed, trying alternative method..."
    INSTALLED=false
fi

# If pip install failed, try installing specific wheel
if [ "$INSTALLED" != "true" ] && [ -n "$WHEEL_PLATFORM" ]; then
    echo "   Trying to install from specific wheel for $WHEEL_PLATFORM..."
    
    # Determine Python version for wheel naming
    PYTHON_MAJOR_MINOR=$(python3 -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}')")
    
    # Try installing a compatible version
    TFLITE_VERSION="2.14.0"
    WHEEL_URL="https://github.com/google-coral/pycoral/releases/download/v2.0.0/tflite_runtime-${TFLITE_VERSION}-cp${PYTHON_MAJOR_MINOR}-cp${PYTHON_MAJOR_MINOR}-linux_${ARCH}.whl"
    
    echo "   Attempting to install from: $WHEEL_URL"
    
    if wget -q "$WHEEL_URL" -O /tmp/tflite_runtime.whl 2>/dev/null; then
        sudo pip3 install --break-system-packages /tmp/tflite_runtime.whl
        rm /tmp/tflite_runtime.whl
        if python3 -c "import tflite_runtime" 2>/dev/null; then
            echo "   ✓ Installed from wheel successfully"
            INSTALLED=true
        fi
    fi
fi

# Final fallback: try apt-get if available
if [ "$INSTALLED" != "true" ]; then
    echo "   Trying system package manager..."
    if sudo apt-get install -y python3-tflite-runtime 2>/dev/null; then
        if python3 -c "import tflite_runtime" 2>/dev/null; then
            echo "   ✓ Installed via apt-get"
            INSTALLED=true
        fi
    fi
fi

echo ""

echo "[4/4] Verifying installation..."
python3 << 'PYTHON_EOF'
import sys
try:
    import tflite_runtime.interpreter as tflite
    print("✓ TensorFlow Lite Runtime imported successfully")
    print(f"  Module location: {tflite.__file__}")
    sys.exit(0)
except ImportError as e:
    print(f"✗ Failed to import tflite_runtime: {e}")
    sys.exit(1)
PYTHON_EOF

INSTALL_RESULT=$?

if [ $INSTALL_RESULT -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Installation Complete!                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "You can now start the camera agent:"
    echo "  sudo systemctl start camera-agent"
    echo ""
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ❌ Installation Failed                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Try installing manually:"
    echo "  sudo pip3 install --break-system-packages tflite-runtime"
    echo ""
    echo "Or check installation log:"
    echo "  cat /tmp/tflite_install.log"
    echo ""
fi

