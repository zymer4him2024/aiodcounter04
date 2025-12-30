# Hailo-8 AI Accelerator Setup Guide

This guide helps you set up YOLO object detection on Raspberry Pi 5 with Hailo-8 HAT+.

## Prerequisites

- Raspberry Pi 5
- Hailo-8 AI HAT+ connected via PCIe
- USB camera connected
- Raspberry Pi OS (64-bit)

## Step 1: Install HailoRT

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Hailo Runtime
sudo apt-get install -y hailort

# Verify Hailo-8 is detected
hailortcli device-info
```

You should see output showing your Hailo-8 device.

## Step 2: Install Python Hailo SDK

```bash
# Install Hailo Python SDK
sudo pip3 install --break-system-packages hailortcli

# Or if available via apt
sudo apt-get install -y python3-hailo
```

## Step 3: Get YOLO Model for Hailo-8

You need a YOLO model in HEF (Hailo Executable Format). Options:

### Option A: Download Pre-compiled Model

```bash
# Create models directory
sudo mkdir -p /opt/camera-agent/models

# Download YOLOv8 model (example - adjust URL based on available models)
cd /opt/camera-agent/models
sudo wget https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.14.0/yolov8n.hef

# Or download from Hailo Model Zoo
# Visit: https://hailo.ai/developer-zone/model-zoo/
```

### Option B: Convert Your Own Model

If you have a YOLO model you want to use:

1. Install Hailo Dataflow Compiler (DFC)
2. Convert your model to HEF format
3. Place the `.hef` file in `/opt/camera-agent/models/`

## Step 4: Update Configuration

Update `/opt/camera-agent/config.json` to use HEF model:

```json
{
  "detectionConfig": {
    "modelPath": "/opt/camera-agent/models/yolov8n.hef",
    "objectClasses": ["person", "vehicle", "forklift"],
    "confidenceThreshold": 0.75,
    "detectionZones": []
  }
}
```

**Important:** The model file extension must be `.hef` for Hailo-8, not `.tflite`.

## Step 5: Verify Installation

```bash
# Test Hailo Python import
python3 -c "from hailo_platform import HEF, VDevice; print('✓ Hailo SDK installed')"

# Verify model file exists
ls -la /opt/camera-agent/models/*.hef

# Check Hailo device
hailortcli device-info
```

## Step 6: Start Camera Agent

```bash
# Start the camera agent service
sudo systemctl start camera-agent

# Check status
sudo systemctl status camera-agent

# Monitor logs
sudo journalctl -u camera-agent -f
```

## Troubleshooting

### Hailo device not detected
```bash
# Check PCIe connection
lspci | grep -i hailo

# Check kernel modules
lsmod | grep hailo

# Restart Hailo service
sudo systemctl restart hailort
```

### Model format error
- Ensure model file has `.hef` extension
- Verify model was compiled for Hailo-8
- Check model compatibility with your HailoRT version

### Import errors
```bash
# Reinstall Hailo SDK
sudo pip3 install --break-system-packages --upgrade hailortcli

# Or install from source if needed
# Check Hailo documentation for latest installation instructions
```

## Performance Notes

- Hailo-8 provides significantly faster inference than CPU-based TFLite
- Expected FPS: 30+ for YOLOv8n on Hailo-8
- Lower latency and better real-time performance

## Resources

- Hailo Documentation: https://hailo.ai/documentation/
- Model Zoo: https://hailo.ai/developer-zone/model-zoo/
- Hailo Community: https://community.hailo.ai/

