#!/bin/bash
################################################################################
# Update Flask Provisioning Portal on Raspberry Pi
# Run this script from your Mac (NOT on the RPi)
################################################################################

set -e

RPI_HOST="digioptics_od@ShawnRaspberryPi.local"
PROVISIONING_PORTAL_FILE="camera-system/provisioning_portal.py"
TARGET_PATH="/opt/camera-agent/provisioning_portal.py"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Updating Flask Provisioning Portal on Raspberry Pi           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if file exists
if [ ! -f "$PROVISIONING_PORTAL_FILE" ]; then
    echo "❌ Error: File not found: $PROVISIONING_PORTAL_FILE"
    exit 1
fi

echo "[1/3] Copying provisioning portal to RPi..."
scp "$PROVISIONING_PORTAL_FILE" "${RPI_HOST}:/tmp/provisioning_portal.py"

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy file. Check SSH connection."
    echo ""
    echo "Try:"
    echo "  ssh ${RPI_HOST}"
    exit 1
fi

echo "✅ File copied"
echo ""

echo "[2/3] Moving file to correct location and setting permissions..."
ssh "${RPI_HOST}" "sudo mv /tmp/provisioning_portal.py ${TARGET_PATH} && sudo chmod +x ${TARGET_PATH} && echo '✅ File installed'"

echo ""
echo "[3/3] Installing Flask dependencies..."
ssh "${RPI_HOST}" "sudo pip3 install flask flask-cors requests --break-system-packages"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Update Complete!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps on RPi:"
echo "  1. Create/update service file (see FLASK_PORTAL_TROUBLESHOOTING.md)"
echo "  2. Start service: sudo systemctl start provisioning-portal"
echo "  3. Enable service: sudo systemctl enable provisioning-portal"
echo "  4. Check status: sudo systemctl status provisioning-portal"
echo ""



