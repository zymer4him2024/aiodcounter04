#!/bin/bash
################################################################################
# Deploy start-od-with-usb-camera.sh to Raspberry Pi and execute it
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying OD Startup Script to Raspberry Pi                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_PATH="camera-system/start-od-with-usb-camera.sh"
RPI_HOST="digioptics_od@ShawnRaspberryPi.local"
RPI_TMP="/tmp/start-od-with-usb-camera.sh"

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script not found: $SCRIPT_PATH"
    exit 1
fi

echo "[1/3] Copying script to Raspberry Pi..."
echo "   You will be prompted for your SSH password..."
scp "$SCRIPT_PATH" "${RPI_HOST}:${RPI_TMP}"

if [ $? -eq 0 ]; then
    echo "   ✓ Script copied successfully"
else
    echo "   ✗ Failed to copy script"
    exit 1
fi
echo ""

echo "[2/3] Making script executable on RPi..."
ssh "${RPI_HOST}" "chmod +x ${RPI_TMP} && echo '✓ Script is now executable'"

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to make script executable"
    exit 1
fi
echo ""

echo "[3/3] Running script on RPi..."
echo "   (You may be prompted for sudo password on RPi)"
echo ""
ssh -t "${RPI_HOST}" "sudo ${RPI_TMP}"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "If the service started successfully, you can monitor logs with:"
echo "  ssh ${RPI_HOST}"
echo "  sudo journalctl -u camera-agent -f"
echo ""


