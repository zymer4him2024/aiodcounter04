#!/bin/bash
# Deploy Hotspot Fix to Raspberry Pi via Hotspot Connection
# Use this when RPi is in hotspot mode (192.168.4.1)

set -e

RPI_HOTSPOT="digioptics_od@192.168.4.1"
RPI_WIFI="digioptics_od@192.168.0.214"
SCRIPT_PATH="camera-system/fix-hotspot.sh"
RPI_TMP="/tmp/fix-hotspot.sh"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Hotspot Fix via Hotspot Connection                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  Make sure you are connected to the RPi hotspot WiFi first!"
echo "   SSID: AIOD-Camera-XXXXX"
echo "   Password: aiod2024"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Try hotspot IP first, then WiFi IP
RPI_HOST=""
if ping -c 1 -W 2 192.168.4.1 > /dev/null 2>&1; then
    echo "✅ RPi hotspot is reachable (192.168.4.1)"
    RPI_HOST="$RPI_HOTSPOT"
elif ping -c 1 -W 2 192.168.0.214 > /dev/null 2>&1; then
    echo "✅ RPi WiFi is reachable (192.168.0.214)"
    RPI_HOST="$RPI_WIFI"
else
    echo "❌ Cannot reach RPi at either 192.168.4.1 or 192.168.0.214"
    echo ""
    echo "Please:"
    echo "  1. Connect your Mac to the RPi hotspot WiFi"
    echo "  2. Or ensure RPi is connected to your WiFi network"
    echo "  3. Then run this script again"
    exit 1
fi

echo ""
echo "[1/3] Copying fix script to Raspberry Pi..."
echo "   Target: $RPI_HOST"

scp -o ConnectTimeout=10 "$SCRIPT_PATH" "${RPI_HOST}:${RPI_TMP}"

if [ $? -eq 0 ]; then
    echo "   ✅ Script copied successfully"
else
    echo "   ✗ Failed to copy script"
    echo ""
    echo "Trying alternative method: direct SSH command..."
    # Alternative: copy script content via SSH
    ssh -o ConnectTimeout=10 "$RPI_HOST" "cat > ${RPI_TMP}" < "$SCRIPT_PATH"
    if [ $? -eq 0 ]; then
        echo "   ✅ Script copied via alternative method"
    else
        echo "   ✗ All copy methods failed"
        exit 1
    fi
fi
echo ""

echo "[2/3] Making script executable on RPi..."
ssh -o ConnectTimeout=10 "${RPI_HOST}" "chmod +x ${RPI_TMP} && echo '✓ Script is now executable'"

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to make script executable"
    exit 1
fi
echo ""

echo "[3/3] Running hotspot fix on RPi..."
echo "   (This may take a minute...)"
echo ""
ssh -t -o ConnectTimeout=10 "${RPI_HOST}" "sudo ${RPI_TMP}"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Connect your phone to the hotspot WiFi"
echo "  2. Open browser: http://192.168.4.1"
echo ""

