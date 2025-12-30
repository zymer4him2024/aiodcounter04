#!/bin/bash
################################################################################
# Install Hailo-8 Runtime and SDK for Raspberry Pi 5
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing Hailo-8 Runtime and SDK                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if Hailo device is detected
echo "[1/5] Checking for Hailo-8 device..."
if command -v hailortcli &> /dev/null; then
    echo "   Checking device status..."
    hailortcli device-info 2>&1 | head -10 || echo "   ⚠️  Device not detected yet (may need to install drivers)"
else
    echo "   ⚠️  hailortcli not found - will install"
fi
echo ""

echo "[2/5] Updating package list..."
sudo apt-get update -qq
echo "   ✓ Package list updated"
echo ""

echo "[3/5] Installing Hailo Runtime..."
sudo apt-get install -y hailort 2>&1 | grep -E "(Reading|Unpacking|Setting|E:|W:)" || true

if command -v hailortcli &> /dev/null; then
    echo "   ✓ Hailo Runtime installed"
    
    # Check device
    echo "   Checking Hailo device..."
    if hailortcli device-info &> /dev/null; then
        echo "   ✓ Hailo-8 device detected"
        hailortcli device-info | head -5
    else
        echo "   ⚠️  Hailo device not detected - check hardware connection"
    fi
else
    echo "   ⚠️  Hailo Runtime installation may have failed"
fi
echo ""

echo "[4/5] Installing Python Hailo SDK..."
# Try apt package first
if sudo apt-get install -y python3-hailo 2>&1 | grep -q "Setting up"; then
    echo "   ✓ Python SDK installed via apt"
else
    # Try pip
    echo "   Installing via pip..."
    sudo pip3 install --break-system-packages hailortcli 2>&1 | tail -5 || true
fi

# Verify Python import
python3 << 'PYTHON_EOF'
import sys
try:
    from hailo_platform import HEF, VDevice
    print("   ✓ Hailo Python SDK imported successfully")
    sys.exit(0)
except ImportError as e:
    print(f"   ⚠️  Failed to import Hailo SDK: {e}")
    print("   You may need to install manually:")
    print("   sudo pip3 install --break-system-packages hailortcli")
    sys.exit(1)
PYTHON_EOF

PYTHON_RESULT=$?
echo ""

echo "[5/5] Creating models directory..."
sudo mkdir -p /opt/camera-agent/models
sudo chmod 755 /opt/camera-agent/models
echo "   ✓ Models directory ready: /opt/camera-agent/models"
echo ""

if [ $PYTHON_RESULT -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Installation Complete!                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Download YOLO HEF model to /opt/camera-agent/models/"
    echo "2. Update config.json to use .hef model file"
    echo "3. Start camera agent: sudo systemctl start camera-agent"
    echo ""
    echo "To download a YOLOv8 model:"
    echo "  cd /opt/camera-agent/models"
    echo "  sudo wget <HEF_MODEL_URL>"
    echo ""
else
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  Installation Partial                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Hailo Runtime installed but Python SDK needs manual setup."
    echo "See HAILO_8_SETUP.md for detailed instructions."
    echo ""
fi

