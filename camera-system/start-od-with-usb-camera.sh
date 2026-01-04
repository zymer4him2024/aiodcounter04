#!/bin/bash
################################################################################
# Start Object Detection with USB Camera on Raspberry Pi
# This script verifies the USB camera, checks configuration, and starts the
# camera-agent service for object detection
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Starting Object Detection with USB Camera                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check USB camera
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
    echo -e "${RED}✗${NC} No USB camera detected in /dev/video*"
    echo "   Please connect a USB camera and try again"
    exit 1
fi
echo ""

# Step 2: Test camera with Python
echo "[2/6] Testing camera with OpenCV..."
python3 << 'PYTHON_EOF'
import cv2
import sys

try:
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Failed to open camera device 0")
        sys.exit(1)
    
    ret, frame = cap.read()
    if not ret:
        print("❌ Failed to capture frame from camera")
        cap.release()
        sys.exit(1)
    
    height, width = frame.shape[:2]
    print(f"✓ Camera opened successfully")
    print(f"  Resolution: {width}x{height}")
    print(f"  Frame captured: ✓")
    cap.release()
except Exception as e:
    print(f"❌ Error testing camera: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Camera test failed${NC}"
    exit 1
fi
echo ""

# Step 3: Check configuration file
echo "[3/6] Checking configuration file..."
CONFIG_FILE="/opt/camera-agent/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓${NC} Configuration file exists: $CONFIG_FILE"
    # Show camera ID from config
    CAMERA_ID=$(grep -o '"cameraId"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
    if [ -n "$CAMERA_ID" ]; then
        echo "   Camera ID: $CAMERA_ID"
    fi
else
    echo -e "${RED}✗${NC} Configuration file not found: $CONFIG_FILE"
    echo "   The camera must be activated via provisioning portal first"
    exit 1
fi
echo ""

# Step 4: Check if model file exists
echo "[4/6] Checking object detection model..."
MODEL_PATH=$(grep -o '"modelPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
if [ -z "$MODEL_PATH" ]; then
    # Try default paths
    MODEL_PATH="/opt/camera-agent/models/yolov8n.tflite"
fi

if [ -f "$MODEL_PATH" ]; then
    echo -e "${GREEN}✓${NC} Model file found: $MODEL_PATH"
    MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo "   Model size: $MODEL_SIZE"
else
    echo -e "${YELLOW}⚠${NC} Model file not found: $MODEL_PATH"
    echo "   Object detection may fail. Please ensure the model is installed."
    echo "   Expected locations:"
    echo "   - /opt/camera-agent/model.tflite"
    echo "   - /opt/camera-agent/models/yolov8n.tflite"
fi
echo ""

# Step 5: Check service status
echo "[5/6] Checking camera-agent service..."
if systemctl list-unit-files | grep -q "camera-agent.service"; then
    echo -e "${GREEN}✓${NC} camera-agent service is installed"
    
    SERVICE_STATUS=$(sudo systemctl is-active camera-agent 2>/dev/null || echo "inactive")
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${YELLOW}⚠${NC} Service is already running"
        read -p "Do you want to restart it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "   Restarting service..."
            sudo systemctl restart camera-agent
            sleep 2
        else
            echo "   Keeping current service running"
            SERVICE_STATUS=$(sudo systemctl is-active camera-agent)
        fi
    else
        echo "   Service is not running, starting it..."
        sudo systemctl start camera-agent
        sleep 2
        SERVICE_STATUS=$(sudo systemctl is-active camera-agent)
    fi
    
    if [ "$SERVICE_STATUS" = "active" ]; then
        echo -e "${GREEN}✓${NC} Service is now active"
    else
        echo -e "${RED}✗${NC} Failed to start service"
        echo "   Checking logs..."
        sudo journalctl -u camera-agent -n 20 --no-pager
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} camera-agent service not found"
    echo "   Installing service..."
    
    if [ -f "/etc/systemd/system/camera-agent.service" ]; then
        echo "   Service file exists, reloading systemd..."
        sudo systemctl daemon-reload
        sudo systemctl enable camera-agent
        sudo systemctl start camera-agent
        sleep 2
        
        if sudo systemctl is-active camera-agent > /dev/null; then
            echo -e "${GREEN}✓${NC} Service installed and started"
        else
            echo -e "${RED}✗${NC} Failed to start service"
            sudo journalctl -u camera-agent -n 20 --no-pager
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Service file not found at /etc/systemd/system/camera-agent.service"
        echo "   Please deploy the camera-agent.service file first"
        exit 1
    fi
fi
echo ""

# Step 6: Monitor initial logs
echo "[6/6] Checking service logs..."
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Recent camera-agent logs:"
echo "═══════════════════════════════════════════════════════════════"
sudo journalctl -u camera-agent -n 30 --no-pager | tail -20
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Setup Complete!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Object Detection Status:"
echo "  Camera: ${GREEN}✓${NC} Connected ($PRIMARY_CAMERA)"
echo "  Service: ${GREEN}✓${NC} Active"
echo ""
echo "Monitor logs in real-time with:"
echo "  sudo journalctl -u camera-agent -f"
echo ""
echo "Check service status with:"
echo "  sudo systemctl status camera-agent"
echo ""
echo "Stop the service with:"
echo "  sudo systemctl stop camera-agent"
echo ""


