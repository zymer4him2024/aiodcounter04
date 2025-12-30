#!/bin/bash
################################################################################
# Create start-od-with-usb-camera.sh on Raspberry Pi
# Run this script to create the startup script directly on the RPi
################################################################################

cat << 'EOF' | ssh digioptics_od@ShawnRaspberryPi.local "cat > /tmp/start-od-with-usb-camera.sh && chmod +x /tmp/start-od-with-usb-camera.sh && echo 'Script created successfully' || echo 'Failed to create script'"
#!/bin/bash
################################################################################
# Start Object Detection with USB Camera on Raspberry Pi
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Starting Object Detection with USB Camera                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check USB camera
echo "[1/6] Checking USB camera..."
if ls /dev/video* 1> /dev/null 2>&1; then
    CAMERA_DEVICES=$(ls /dev/video*)
    echo -e "${GREEN}✓${NC} USB camera detected:"
    for dev in $CAMERA_DEVICES; do
        echo "   - $dev"
    done
    PRIMARY_CAMERA=$(ls /dev/video* | head -1)
    echo "   Using primary camera: $PRIMARY_CAMERA"
else
    echo -e "${RED}✗${NC} No USB camera detected"
    exit 1
fi
echo ""

# Test camera
echo "[2/6] Testing camera with OpenCV..."
python3 << 'PYTHON_EOF'
import cv2
import sys
try:
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Failed to open camera")
        sys.exit(1)
    ret, frame = cap.read()
    if not ret:
        print("❌ Failed to capture frame")
        cap.release()
        sys.exit(1)
    height, width = frame.shape[:2]
    print(f"✓ Camera: {width}x{height}")
    cap.release()
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

# Check config
echo "[3/6] Checking configuration..."
CONFIG_FILE="/opt/camera-agent/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗${NC} Config not found: $CONFIG_FILE"
    exit 1
fi
echo -e "${GREEN}✓${NC} Config found"
CAMERA_ID=$(grep -o '"cameraId"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
if [ -n "$CAMERA_ID" ]; then
    echo "   Camera ID: $CAMERA_ID"
fi
echo ""

# Check model
echo "[4/6] Checking model file..."
MODEL_PATH=$(grep -o '"modelPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
if [ -z "$MODEL_PATH" ]; then
    MODEL_PATH="/opt/camera-agent/models/yolov8n.tflite"
fi
if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${YELLOW}⚠${NC} Model not found: $MODEL_PATH"
else
    echo -e "${GREEN}✓${NC} Model found: $MODEL_PATH"
fi
echo ""

# Check and start service
echo "[5/6] Starting camera-agent service..."
SERVICE_STATUS=$(sudo systemctl is-active camera-agent 2>/dev/null || echo "inactive")
if [ "$SERVICE_STATUS" = "active" ]; then
    echo -e "${YELLOW}⚠${NC} Service already running, restarting..."
    sudo systemctl restart camera-agent
else
    sudo systemctl start camera-agent
fi
sleep 3

if sudo systemctl is-active camera-agent > /dev/null; then
    echo -e "${GREEN}✓${NC} Service is active"
else
    echo -e "${RED}✗${NC} Service failed to start"
    sudo journalctl -u camera-agent -n 20 --no-pager
    exit 1
fi
echo ""

# Show logs
echo "[6/6] Recent logs:"
echo "═══════════════════════════════════════════════════════════════"
sudo journalctl -u camera-agent -n 20 --no-pager | tail -15
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Object Detection Started!                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Monitor logs: sudo journalctl -u camera-agent -f"
echo "Check status: sudo systemctl status camera-agent"
EOF

