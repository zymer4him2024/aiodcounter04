#!/bin/bash
################################################################################
# Check camera-agent service errors and logs
################################################################################

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Checking Camera Agent Service Errors                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "[1/4] Service Status:"
sudo systemctl status camera-agent --no-pager -l | head -15
echo ""

echo "[2/4] Recent Error Logs (last 50 lines):"
echo "═══════════════════════════════════════════════════════════════"
sudo journalctl -u camera-agent -n 50 --no-pager
echo ""

echo "[3/4] Checking configuration file:"
CONFIG_FILE="/opt/camera-agent/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo "✓ Config file exists: $CONFIG_FILE"
    echo "   Camera ID: $(grep -o '"cameraId"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
    echo "   Model path: $(grep -o '"modelPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
else
    echo "✗ Config file not found: $CONFIG_FILE"
fi
echo ""

echo "[4/4] Testing camera agent manually:"
echo "═══════════════════════════════════════════════════════════════"
cd /opt/camera-agent
sudo /usr/bin/python3 camera_agent.py config.json 2>&1 | head -30
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Diagnostic Complete                                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Look for error messages above to identify the issue."
echo "Common issues:"
echo "  - Missing model file"
echo "  - Missing Python dependencies (cv2, tflite_runtime)"
echo "  - Invalid configuration"
echo "  - Missing Firebase credentials"
echo ""

