# Download YOLOv8 HEF Model for Hailo-8

## Quick Start

Run the download script on your RPi:

```bash
# From your Mac, copy the script:
scp camera-system/download-hailo-yolo-model.sh digioptics_od@ShawnRaspberryPi.local:/tmp/

# On RPi, run it:
chmod +x /tmp/download-hailo-yolo-model.sh
sudo /tmp/download-hailo-yolo-model.sh
```

## Manual Download (Recommended)

### Step 1: Access Hailo Model Zoo

1. Visit: **https://hailo.ai/developer-zone/model-zoo/**
2. Sign in or create a free account
3. Navigate to Object Detection models
4. Find YOLOv8 models

### Step 2: Download HEF Model

Download a YOLOv8 model in HEF format (e.g., `yolov8n.hef` for nano, or larger variants).

### Step 3: Copy to Raspberry Pi

From your Mac:
```bash
# Replace <downloaded-file>.hef with the actual filename
scp ~/Downloads/yolov8n.hef digioptics_od@ShawnRaspberryPi.local:/tmp/

# SSH to RPi and move to models directory
ssh digioptics_od@ShawnRaspberryPi.local
sudo mv /tmp/yolov8n.hef /opt/camera-agent/models/
sudo chmod 644 /opt/camera-agent/models/yolov8n.hef
```

### Step 4: Update Configuration

```bash
# Update config.json to point to the HEF file
sudo python3 << 'EOF'
import json

config_file = "/opt/camera-agent/config.json"
with open(config_file, 'r') as f:
    config = json.load(f)

config['detectionConfig']['modelPath'] = "/opt/camera-agent/models/yolov8n.hef"

with open(config_file, 'w') as f:
    json.dump(config, f, indent=4)

print("✓ Config updated")
EOF
```

### Step 5: Restart Camera Agent

```bash
sudo systemctl restart camera-agent
sudo journalctl -u camera-agent -f
```

## Alternative: Use TFLite (Temporary Fallback)

If you need to start immediately while waiting for HEF model:

1. The camera agent supports TFLite as fallback
2. Update config to use a `.tflite` file
3. Note: Performance will be lower without Hailo-8 acceleration

## Verify Model File

```bash
# Check if model exists
ls -lh /opt/camera-agent/models/*.hef

# Verify it's a valid file
file /opt/camera-agent/models/*.hef
```

## Troubleshooting

- **Model not found**: Ensure file is in `/opt/camera-agent/models/` and has correct permissions
- **Wrong format**: Must be `.hef` for Hailo-8, not `.pt` or `.tflite`
- **Access denied**: Some Hailo models require account access - sign in to Model Zoo


