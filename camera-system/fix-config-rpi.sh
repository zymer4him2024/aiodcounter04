#!/bin/bash
################################################################################
# Fix Camera Agent Configuration for Hailo-8
################################################################################

set -e

CONFIG_FILE="/opt/camera-agent/config.json"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%s)"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Fixing Camera Agent Configuration                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Backup current config
echo "[1/4] Backing up current config..."
sudo cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "   ✓ Backup created: $BACKUP_FILE"
echo ""

# Check for service account file
echo "[2/4] Checking for Firebase service account file..."
SERVICE_ACCOUNT_PATHS=(
    "/opt/camera-agent/service-account.json"
    "/opt/camera-agent/config/service-account.json"
    "/opt/camera-agent/*firebase*.json"
    "/opt/camera-agent/*admin*.json"
)

FOUND_SERVICE_ACCOUNT=""
for path in "${SERVICE_ACCOUNT_PATHS[@]}"; do
    if ls $path 1> /dev/null 2>&1; then
        FOUND_SERVICE_ACCOUNT=$(ls $path | head -1)
        echo "   ✓ Found service account: $FOUND_SERVICE_ACCOUNT"
        break
    fi
done

if [ -z "$FOUND_SERVICE_ACCOUNT" ]; then
    echo "   ⚠️  Service account file not found"
    echo "   → You'll need to copy it from your Mac or download it from Firebase Console"
    echo "   → Place it at: /opt/camera-agent/service-account.json"
    SERVICE_ACCOUNT_PATH="/opt/camera-agent/service-account.json"
else
    SERVICE_ACCOUNT_PATH="$FOUND_SERVICE_ACCOUNT"
fi
echo ""

# Check for model files
echo "[3/4] Checking for model files..."
MODEL_DIR="/opt/camera-agent/models"
sudo mkdir -p "$MODEL_DIR"

# Look for HEF files (Hailo-8)
FOUND_HEF=""
if ls "$MODEL_DIR"/*.hef 1> /dev/null 2>&1; then
    FOUND_HEF=$(ls "$MODEL_DIR"/*.hef | head -1)
    echo "   ✓ Found HEF model: $FOUND_HEF"
elif ls /opt/camera-agent/*.hef 1> /dev/null 2>&1; then
    FOUND_HEF=$(ls /opt/camera-agent/*.hef | head -1)
    echo "   ✓ Found HEF model: $FOUND_HEF"
fi

# Look for TFLite files (fallback)
FOUND_TFLITE=""
if ls "$MODEL_DIR"/*.tflite 1> /dev/null 2>&1; then
    FOUND_TFLITE=$(ls "$MODEL_DIR"/*.tflite | head -1)
    echo "   ✓ Found TFLite model: $FOUND_TFLITE"
elif ls /opt/camera-agent/*.tflite 1> /dev/null 2>&1; then
    FOUND_TFLITE=$(ls /opt/camera-agent/*.tflite | head -1)
    echo "   ✓ Found TFLite model: $FOUND_TFLITE"
fi

# Determine which model to use (prefer HEF for Hailo-8)
if [ -n "$FOUND_HEF" ]; then
    MODEL_PATH="$FOUND_HEF"
    echo "   → Will use HEF model (for Hailo-8): $MODEL_PATH"
elif [ -n "$FOUND_TFLITE" ]; then
    MODEL_PATH="$FOUND_TFLITE"
    echo "   → Will use TFLite model (fallback): $MODEL_PATH"
    echo "   ⚠️  Note: For Hailo-8, you should use a .hef model file for better performance"
else
    echo "   ⚠️  No model files found!"
    echo "   → For Hailo-8: Download a YOLO .hef model to $MODEL_DIR/"
    echo "   → Example: yolov8n.hef"
    echo ""
    echo "   You can download from Hailo Model Zoo:"
    echo "   https://hailo.ai/developer-zone/model-zoo/"
    MODEL_PATH="/opt/camera-agent/models/yolov8n.hef"
    echo "   → Will set placeholder path: $MODEL_PATH"
fi
echo ""

# Update config
echo "[4/4] Updating configuration..."
sudo python3 << PYTHON_EOF
import json
import sys
from pathlib import Path

config_file = Path("${CONFIG_FILE}")
model_path = "${MODEL_PATH}"
service_account_path = "${SERVICE_ACCOUNT_PATH}"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Update model path
    config['detectionConfig']['modelPath'] = model_path
    print(f"   Updated modelPath: {model_path}")
    
    # Update service account path
    config['serviceAccountPath'] = service_account_path
    print(f"   Updated serviceAccountPath: {service_account_path}")
    
    # Ensure orgId is set correctly (use siteId if orgId is missing or wrong)
    if 'orgId' not in config or config.get('orgId') == config.get('siteId'):
        config['orgId'] = 'aiodcouter04'
        print(f"   Updated orgId: aiodcouter04")
    
    # Write updated config
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=4)
    
    print("   ✓ Configuration updated successfully")
    sys.exit(0)
    
except Exception as e:
    print(f"   ✗ Error updating config: {e}")
    sys.exit(1)
PYTHON_EOF

UPDATE_RESULT=$?

if [ $UPDATE_RESULT -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Configuration Updated!                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ ! -f "$MODEL_PATH" ]; then
        echo "⚠️  Model file still missing: $MODEL_PATH"
        echo "   Download a YOLO HEF model for Hailo-8:"
        echo "   cd /opt/camera-agent/models"
        echo "   sudo wget <HEF_MODEL_URL>"
        echo ""
    fi
    
    if [ ! -f "$SERVICE_ACCOUNT_PATH" ]; then
        echo "⚠️  Service account file still missing: $SERVICE_ACCOUNT_PATH"
        echo "   Copy your Firebase service account JSON file to:"
        echo "   $SERVICE_ACCOUNT_PATH"
        echo ""
    fi
    
    echo "Updated config:"
    cat "$CONFIG_FILE" | python3 -m json.tool | head -20
    echo ""
else
    echo ""
    echo "✗ Failed to update configuration"
    echo "   Restoring backup..."
    sudo cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi


