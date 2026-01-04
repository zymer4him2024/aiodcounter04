#!/bin/bash
################################################################################
# Check Config and Fix Issues
################################################################################

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Checking Camera Agent Configuration                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

CONFIG_FILE="/opt/camera-agent/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "[1/4] Current configuration:"
echo "═══════════════════════════════════════════════════════════════"
cat "$CONFIG_FILE" | python3 -m json.tool 2>/dev/null || cat "$CONFIG_FILE"
echo ""

echo "[2/4] Checking model file path:"
MODEL_PATH=$(grep -o '"modelPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
echo "   Config specifies: $MODEL_PATH"

if [ -f "$MODEL_PATH" ]; then
    echo "   ✓ Model file exists"
else
    echo "   ✗ Model file NOT found"
    echo ""
    echo "   Looking for available model files..."
    
    # Check for HEF files (Hailo-8)
    if ls /opt/camera-agent/models/*.hef 1> /dev/null 2>&1; then
        echo "   Found HEF model files:"
        ls -lh /opt/camera-agent/models/*.hef
        FIRST_HEF=$(ls /opt/camera-agent/models/*.hef | head -1)
        echo ""
        echo "   Should update config to use: $FIRST_HEF"
    else
        echo "   ⚠️  No HEF model files found in /opt/camera-agent/models/"
    fi
    
    # Check for TFLite files (fallback)
    if ls /opt/camera-agent/models/*.tflite 1> /dev/null 2>&1; then
        echo "   Found TFLite model files:"
        ls -lh /opt/camera-agent/models/*.tflite
    fi
    
    # Check root directory
    if ls /opt/camera-agent/*.{hef,tflite} 1> /dev/null 2>&1; then
        echo "   Found model files in /opt/camera-agent/:"
        ls -lh /opt/camera-agent/*.{hef,tflite} 2>/dev/null
    fi
fi
echo ""

echo "[3/4] Checking Firebase service account:"
SERVICE_ACCOUNT_PATH=$(grep -o '"serviceAccountPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
echo "   Config specifies: $SERVICE_ACCOUNT_PATH"

if [ -f "$SERVICE_ACCOUNT_PATH" ]; then
    echo "   ✓ Service account file exists"
else
    echo "   ✗ Service account file NOT found"
    echo ""
    echo "   Looking for service account files..."
    if ls /opt/camera-agent/*.json 1> /dev/null 2>&1; then
        echo "   Found JSON files in /opt/camera-agent/:"
        ls -lh /opt/camera-agent/*.json | grep -v config.json
        FIRST_JSON=$(ls /opt/camera-agent/*.json 2>/dev/null | grep -v config.json | head -1)
        if [ -n "$FIRST_JSON" ]; then
            echo ""
            echo "   Should update config to use: $FIRST_JSON"
        fi
    fi
    
    if ls /opt/camera-agent/config/*.json 1> /dev/null 2>&1; then
        echo "   Found JSON files in /opt/camera-agent/config/:"
        ls -lh /opt/camera-agent/config/*.json
    fi
fi
echo ""

echo "[4/4] Summary and recommendations:"
echo "═══════════════════════════════════════════════════════════════"

ISSUES=0

if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model file missing: $MODEL_PATH"
    ISSUES=$((ISSUES + 1))
    echo "   → For Hailo-8: Download a .hef model file"
    echo "   → Place it in /opt/camera-agent/models/"
    echo "   → Update config.json modelPath to point to the .hef file"
fi

if [ ! -f "$SERVICE_ACCOUNT_PATH" ]; then
    echo "❌ Service account file missing: $SERVICE_ACCOUNT_PATH"
    ISSUES=$((ISSUES + 1))
    echo "   → Copy your Firebase service account JSON file to RPi"
    echo "   → Update config.json serviceAccountPath to point to it"
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All required files are present!"
else
    echo ""
    echo "Fix these $ISSUES issue(s) before starting the camera agent."
fi
echo ""


