#!/bin/bash
# Deploy hotspot visibility fix to RPi
# This ensures the hotspot is visible on phones

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
    echo "   RPI_IP=<ip> ./deploy-ensure-hotspot.sh"
    exit 1
fi

SCRIPT_PATH="camera-system/ensure-hotspot-visible.sh"
RPI_TMP="/tmp/ensure-hotspot-visible.sh"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Ensuring RPi Hotspot is Visible                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: $RPI_HOST"
echo ""

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script not found: $SCRIPT_PATH"
    exit 1
fi

echo "[1/3] Copying script to RPi..."
scp -o ConnectTimeout=10 "$SCRIPT_PATH" "${RPI_HOST}:${RPI_TMP}"

if [ $? -eq 0 ]; then
    echo "   ✅ Script copied"
else
    echo "   ✗ Failed to copy"
    exit 1
fi

echo ""
echo "[2/3] Making executable..."
ssh -o ConnectTimeout=10 "${RPI_HOST}" "chmod +x ${RPI_TMP}"

echo ""
echo "[3/3] Running hotspot fix..."
ssh -t -o ConnectTimeout=10 "${RPI_HOST}" "sudo ${RPI_TMP}"

echo ""
echo "✅ Complete! Check your phone's WiFi list for the hotspot."
echo ""

