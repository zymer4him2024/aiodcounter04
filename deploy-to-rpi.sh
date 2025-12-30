#!/bin/bash
################################################################################
# Deploy Updated Files to Raspberry Pi
# Run this from your Mac to copy updated files to the RPi
################################################################################

set -e

RPI_HOST="digioptics_od@ShawnRaspberryPi.local"
TEMP_DIR="/tmp"
APP_DIR="/opt/camera-agent"
SYSTEMD_DIR="/etc/systemd/system"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Files to Raspberry Pi                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if files exist
echo "[1/5] Checking local files..."
FILES=(
    "camera-system/camera_agent.py"
    "camera-system/provisioning_portal.py"
    "camera-system/camera-agent.service"
    "camera-system/test-activation-flow.sh"
    "camera-system/install-camera-service.sh"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ Found: $file"
    else
        echo "   ✗ Missing: $file"
        exit 1
    fi
done

# Copy files to RPi
echo ""
echo "[2/5] Copying files to RPi..."
echo "   (You will be prompted for SSH password)"

scp "${FILES[0]}" "$RPI_HOST:$TEMP_DIR/camera_agent.py"
echo "   ✓ Copied camera_agent.py"

scp "${FILES[1]}" "$RPI_HOST:$TEMP_DIR/provisioning_portal.py"
echo "   ✓ Copied provisioning_portal.py"

scp "${FILES[2]}" "$RPI_HOST:$TEMP_DIR/camera-agent.service"
echo "   ✓ Copied camera-agent.service"

scp "${FILES[3]}" "$RPI_HOST:$TEMP_DIR/test-activation-flow.sh"
echo "   ✓ Copied test-activation-flow.sh"

scp "${FILES[4]}" "$RPI_HOST:$TEMP_DIR/install-camera-service.sh"
echo "   ✓ Copied install-camera-service.sh"

# Move files to correct locations on RPi
echo ""
echo "[3/5] Installing files on RPi..."
echo "   (You will be prompted for SSH and sudo passwords)"

ssh "$RPI_HOST" "sudo mv $TEMP_DIR/camera_agent.py $APP_DIR/camera_agent.py && \
                 sudo mv $TEMP_DIR/provisioning_portal.py $APP_DIR/provisioning_portal.py && \
                 sudo mv $TEMP_DIR/camera-agent.service $SYSTEMD_DIR/camera-agent.service && \
                 sudo mv $TEMP_DIR/test-activation-flow.sh $APP_DIR/test-activation-flow.sh && \
                 sudo mv $TEMP_DIR/install-camera-service.sh $APP_DIR/install-camera-service.sh && \
                 sudo chmod +x $APP_DIR/camera_agent.py && \
                 sudo chmod +x $APP_DIR/*.sh && \
                 sudo systemctl daemon-reload"

echo "   ✓ Files installed successfully"

# Verify service installation (service file already installed in step 3)
echo ""
echo "[4/5] Verifying service installation..."
ssh "$RPI_HOST" "sudo systemctl daemon-reload && sudo systemctl show camera-agent >/dev/null 2>&1 && echo '   ✓ Service file is valid' || echo '   ⚠ Service file may need verification'"

# Check for model file
echo ""
echo "[5/5] Checking for detection model file..."
ssh "$RPI_HOST" "if [ -f $APP_DIR/model.tflite ]; then \
                     echo '   ✓ Found model.tflite'; \
                 elif [ -f $APP_DIR/models/yolov8n.tflite ]; then \
                     echo '   ✓ Found models/yolov8n.tflite'; \
                 else \
                     echo '   ⚠ WARNING: No model file found!'; \
                     echo '   Expected: $APP_DIR/model.tflite or $APP_DIR/models/yolov8n.tflite'; \
                     echo '   Counting will not work without a model file.'; \
                 fi"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps on RPi:"
echo "  1. Run test script: sudo /opt/camera-agent/test-activation-flow.sh"
echo "  2. Or test manually via portal UI"
echo ""

