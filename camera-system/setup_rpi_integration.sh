#!/bin/bash
################################################################################
# Raspberry Pi Firebase Integration Setup Script
# Run this on the RPi after deploying the camera master image
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Raspberry Pi Firebase Integration Setup                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
APP_DIR="/opt/camera-agent"
CONFIG_DIR="${APP_DIR}/config"
SERVICE_ACCOUNT_FILE="${CONFIG_DIR}/service-account.json"

# Create directories
echo "[1/6] Creating directories..."
sudo mkdir -p "${CONFIG_DIR}"
sudo mkdir -p "${APP_DIR}/models"
sudo mkdir -p /var/lib/camera_agent
echo "✅ Directories created"
echo ""

# Check for service account file
echo "[2/6] Checking service account file..."
if [ ! -f "${SERVICE_ACCOUNT_FILE}" ]; then
    echo "⚠️  Service account file not found: ${SERVICE_ACCOUNT_FILE}"
    echo ""
    echo "Please copy the service account JSON file to:"
    echo "  ${SERVICE_ACCOUNT_FILE}"
    echo ""
    echo "From your Mac, run:"
    echo "  scp aiodcouter04-firebase-adminsdk-fbsvc-2b39b335bc.json \\"
    echo "      digioptics_od@CameraUnit.local:${SERVICE_ACCOUNT_FILE}"
    echo ""
    read -p "Press Enter after copying the service account file..."
    
    if [ ! -f "${SERVICE_ACCOUNT_FILE}" ]; then
        echo "❌ Service account file still not found. Exiting."
        exit 1
    fi
fi

sudo chmod 600 "${SERVICE_ACCOUNT_FILE}"
echo "✅ Service account file configured"
echo ""

# Install Python dependencies
echo "[3/6] Installing Python dependencies..."
sudo pip3 install --upgrade firebase-admin opencv-python-headless tflite-runtime sqlalchemy psutil
echo "✅ Dependencies installed"
echo ""

# Generate configuration
echo "[4/6] Generating camera configuration..."
echo ""
read -p "Enter Camera ID from dashboard (e.g., CAM_ABC1234): " CAMERA_ID
read -p "Enter Site ID from dashboard: " SITE_ID
read -p "Enter Organization ID [aiodcouter04]: " ORG_ID
ORG_ID=${ORG_ID:-aiodcouter04}

if [ -z "$CAMERA_ID" ] || [ -z "$SITE_ID" ]; then
    echo "❌ Camera ID and Site ID are required"
    exit 1
fi

# Create config.json
sudo tee "${CONFIG_DIR}/config.json" > /dev/null <<EOF
{
  "cameraId": "${CAMERA_ID}",
  "siteId": "${SITE_ID}",
  "orgId": "${ORG_ID}",
  "serviceAccountPath": "${SERVICE_ACCOUNT_FILE}",
  "firebaseConfig": {
    "apiKey": "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
    "authDomain": "aiodcouter04.firebaseapp.com",
    "projectId": "aiodcouter04",
    "storageBucket": "aiodcouter04.firebasestorage.app",
    "messagingSenderId": "87816815492",
    "appId": "1:87816815492:web:849f2866d2fd63baf393d1"
  },
  "detectionConfig": {
    "modelPath": "${APP_DIR}/models/yolov8n.tflite",
    "objectClasses": ["person", "vehicle", "forklift"],
    "confidenceThreshold": 0.75,
    "detectionZones": []
  },
  "transmissionConfig": {
    "aggregationInterval": 300,
    "maxRetries": 3,
    "timeout": 10000
  }
}
EOF

sudo chmod 644 "${CONFIG_DIR}/config.json"
echo "✅ Configuration file created: ${CONFIG_DIR}/config.json"
echo ""

# Verify camera agent exists
echo "[5/6] Verifying camera agent..."
if [ ! -f "${APP_DIR}/camera_agent.py" ]; then
    echo "⚠️  Camera agent not found at ${APP_DIR}/camera_agent.py"
    echo "Please ensure camera agent is installed."
    read -p "Press Enter to continue anyway..."
else
    echo "✅ Camera agent found"
fi
echo ""

# Test configuration
echo "[6/6] Testing configuration..."
if [ -f "${APP_DIR}/camera_agent.py" ]; then
    echo "Testing config loading (Ctrl+C to cancel)..."
    timeout 5 sudo python3 "${APP_DIR}/camera_agent.py" "${CONFIG_DIR}/config.json" 2>&1 | head -5 || true
    echo ""
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Setup Complete!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Start camera agent service:"
echo "     sudo systemctl start camera-agent"
echo ""
echo "  2. Check service status:"
echo "     sudo systemctl status camera-agent"
echo ""
echo "  3. View logs:"
echo "     sudo journalctl -u camera-agent -f"
echo ""
echo "  4. Verify in dashboard:"
echo "     https://aiodcounter04-superadmin.web.app"
echo "     → Go to Live Counts tab"
echo "     → Select your camera"
echo "     → Verify status shows 'online'"
echo ""




