#!/bin/bash
################################################################################
# Download YOLOv8 HEF Model for Hailo-8
# This script helps you download a HEF model from various sources
################################################################################

set -e

MODEL_DIR="/opt/camera-agent/models"
MODEL_NAME="yolov8n"
HEF_FILE="${MODEL_DIR}/${MODEL_NAME}.hef"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Downloading YOLOv8 HEF Model for Hailo-8                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Create models directory
sudo mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

echo "[1/5] Checking for existing HEF models..."
if ls *.hef 1> /dev/null 2>&1; then
    echo "   ✓ Found existing HEF files:"
    ls -lh *.hef
    echo ""
    echo "   Use existing model? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        EXISTING_HEF=$(ls *.hef | head -1)
        echo "   Using: $EXISTING_HEF"
        exit 0
    fi
fi
echo ""

echo "[2/5] Checking Hailo installation for sample models..."
if command -v hailortcli &> /dev/null; then
    echo "   Hailo Runtime installed:"
    hailortcli --version 2>/dev/null || echo "   (version check unavailable)"
    
    # Check for sample models in Hailo installation
    SAMPLE_MODELS=$(find /usr -name "*.hef" -o -name "*yolo*.hef" 2>/dev/null | head -5)
    if [ -n "$SAMPLE_MODELS" ]; then
        echo "   Found sample models in Hailo installation:"
        echo "$SAMPLE_MODELS"
        echo ""
        echo "   Copy one of these? Enter path or 'no':"
        read -r model_path
        if [ -n "$model_path" ] && [ "$model_path" != "no" ] && [ -f "$model_path" ]; then
            sudo cp "$model_path" "$HEF_FILE"
            echo "   ✓ Copied to: $HEF_FILE"
            exit 0
        fi
    fi
else
    echo "   ⚠️  Hailo Runtime not found - models may not work"
fi
echo ""

echo "[3/5] Attempting to download from known sources..."
echo "   Note: HEF models are proprietary to Hailo and typically require:"
echo "   1. Access to Hailo Model Zoo (https://hailo.ai/developer-zone/model-zoo/)"
echo "   2. Or conversion using Hailo Dataflow Compiler"
echo ""

# Try common Hailo Model Zoo URLs (these may require authentication)
HAILO_URLS=(
    "https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.14.0/yolov8n.hef"
    "https://hailo-csdata.s3.eu-west-2.amazonaws.com/resources/hefs/yolov8n.hef"
    "https://github.com/hailo-ai/hailo_model_zoo/releases/download/v2.14.0/yolov8n.hef"
)

DOWNLOADED=false
for url in "${HAILO_URLS[@]}"; do
    echo "   Trying: $url"
    if sudo wget --spider "$url" 2>&1 | grep -q "200 OK"; then
        echo "   ✓ URL accessible, downloading..."
        sudo wget -O "$HEF_FILE" "$url" 2>&1 | tail -3
        if [ -f "$HEF_FILE" ] && [ -s "$HEF_FILE" ]; then
            echo "   ✓ Downloaded successfully: $HEF_FILE"
            sudo chmod 644 "$HEF_FILE"
            DOWNLOADED=true
            break
        fi
    else
        echo "   ✗ URL not accessible (may require authentication or different URL)"
    fi
done

if [ "$DOWNLOADED" = true ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Model Downloaded!                         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Model file: $HEF_FILE"
    ls -lh "$HEF_FILE"
    echo ""
    exit 0
fi
echo ""

echo "[4/5] Manual download instructions..."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Since automatic download failed, please download manually:"
echo ""
echo "Option 1: Hailo Model Zoo (Recommended)"
echo "  1. Visit: https://hailo.ai/developer-zone/model-zoo/"
echo "  2. Sign in/Register for free account"
echo "  3. Search for 'YOLOv8' models"
echo "  4. Download a YOLOv8 model (HEF format)"
echo "  5. Copy to RPi:"
echo "     scp <downloaded-file>.hef digioptics_od@ShawnRaspberryPi.local:/tmp/"
echo "     ssh digioptics_od@ShawnRaspberryPi.local"
echo "     sudo mv /tmp/*.hef $HEF_FILE"
echo ""
echo "Option 2: Use Hailo Dataflow Compiler"
echo "  If you have a YOLO model, convert it using Hailo's tools"
echo ""
echo "Option 3: Temporary TFLite fallback"
echo "  Use a TFLite model until you get HEF (lower performance)"
echo ""

echo "[5/5] Checking if you want to set up TFLite fallback..."
echo "   Set up TFLite model as temporary solution? (y/n)"
read -r use_tflite

if [[ "$use_tflite" =~ ^[Yy]$ ]]; then
    echo "   Downloading TFLite YOLOv8 model (fallback)..."
    
    # Try to find a TFLite YOLOv8 download source
    # Note: Ultralytics doesn't directly provide TFLite, but we can try TensorFlow Hub
    TFLITE_FILE="${MODEL_DIR}/yolov8n.tflite"
    
    echo "   Note: Direct TFLite downloads may not be available."
    echo "   You may need to convert from PyTorch or download from another source."
    echo ""
    echo "   For now, updating config to check for TFLite..."
    
    # Update config to allow TFLite fallback
    sudo python3 << PYTHON_EOF
import json

config_file = "/opt/camera-agent/config.json"
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Update to check for TFLite
    config['detectionConfig']['modelPath'] = "$TFLITE_FILE"
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=4)
    
    print("   ✓ Config updated to use TFLite fallback")
except Exception as e:
    print(f"   ✗ Error: {e}")
PYTHON_EOF

    echo ""
    echo "   To complete TFLite setup:"
    echo "   1. Download a YOLOv8 TFLite model"
    echo "   2. Place it at: $TFLITE_FILE"
    echo "   3. Or convert from PyTorch using: https://github.com/ultralytics/ultralytics"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    Summary                                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Visit Hailo Model Zoo: https://hailo.ai/developer-zone/model-zoo/"
echo "2. Download a YOLOv8 HEF model"
echo "3. Copy to: $HEF_FILE"
echo "4. Update config.json modelPath to: $HEF_FILE"
echo "5. Restart camera-agent service"
echo ""

