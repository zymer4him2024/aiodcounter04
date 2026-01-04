#!/bin/bash
# Deploy Updated Provisioning Portal to Raspberry Pi
# This updates the portal with QR code activation improvements

set -e

# Try to detect RPi IP
RPI_HOST=""
if ping -c 1 -W 2 192.168.0.214 > /dev/null 2>&1; then
    RPI_HOST="digioptics_od@192.168.0.214"
elif ping -c 1 -W 2 192.168.0.213 > /dev/null 2>&1; then
    RPI_HOST="digioptics_od@192.168.0.213"
elif ping -c 1 -W 2 192.168.4.1 > /dev/null 2>&1; then
    RPI_HOST="digioptics_od@192.168.4.1"
else
    echo "❌ Cannot reach RPi. Please specify IP:"
    echo "   RPI_IP=<ip> ./deploy-portal-update.sh"
    exit 1
fi

PORTAL_FILE="camera-system/provisioning_portal.py"
RPI_TMP="/tmp/provisioning_portal.py"
RPI_DEST="/opt/camera-agent/provisioning_portal.py"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Updated Provisioning Portal                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: $RPI_HOST"
echo ""

# Check if file exists
if [ ! -f "$PORTAL_FILE" ]; then
    echo "❌ Portal file not found: $PORTAL_FILE"
    exit 1
fi

echo "[1/3] Copying portal file to RPi..."
scp -o ConnectTimeout=10 "$PORTAL_FILE" "${RPI_HOST}:${RPI_TMP}"

if [ $? -eq 0 ]; then
    echo "   ✅ File copied successfully"
else
    echo "   ✗ Failed to copy file"
    exit 1
fi
echo ""

echo "[2/3] Moving file to destination and setting permissions..."
ssh -o ConnectTimeout=10 "${RPI_HOST}" "
    sudo mv ${RPI_TMP} ${RPI_DEST} && \
    sudo chmod +x ${RPI_DEST} && \
    sudo chown root:root ${RPI_DEST} && \
    echo '✅ File installed successfully'
"

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to install file"
    exit 1
fi
echo ""

echo "[3/3] Restarting provisioning portal service..."
ssh -o ConnectTimeout=10 "${RPI_HOST}" "
    sudo systemctl daemon-reload && \
    sudo systemctl restart provisioning-portal && \
    sleep 2 && \
    sudo systemctl status provisioning-portal --no-pager -l | head -10
"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Portal updated with QR code activation improvements:"
echo "  ✅ Auto-fill token from QR code"
echo "  ✅ Skip WiFi step when QR has token"
echo "  ✅ Use backend_url and api_key from QR"
echo "  ✅ Simplified activation flow"
echo ""
echo "Test the portal:"
echo "  1. Connect phone to hotspot: AIOD-Camera-XXXXX"
echo "  2. Open browser: http://192.168.4.1"
echo "  3. Scan QR code to test activation"
echo ""

