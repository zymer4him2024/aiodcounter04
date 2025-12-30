# How to Get YOLOv8 HEF Model for Hailo-8

## Step-by-Step Instructions

### Step 1: Visit Hailo Model Zoo
1. Open your browser and go to: **https://hailo.ai/developer-zone/model-zoo/**
2. Click "Sign In" or "Register" (free account required)

### Step 2: Find YOLOv8 Models
1. Once logged in, search for "YOLOv8" or navigate to Object Detection models
2. Look for models like:
   - YOLOv8n (nano - smallest, fastest)
   - YOLOv8s (small)
   - YOLOv8m (medium)
   - YOLOv8l (large)
   - YOLOv8x (extra large)

### Step 3: Download the HEF File
1. Click on a YOLOv8 model (start with YOLOv8n for best performance)
2. Look for download options - select "HEF" format (Hailo Executable Format)
3. The file will download to your Downloads folder (e.g., `yolov8n.hef`)

### Step 4: Copy to Raspberry Pi
Once the file is in your Downloads folder, run:
```bash
scp ~/Downloads/yolov8n.hef digioptics_od@ShawnRaspberryPi.local:/tmp/
```

### Step 5: Move to Models Directory on RPi
```bash
ssh digioptics_od@ShawnRaspberryPi.local
sudo mv /tmp/yolov8n.hef /opt/camera-agent/models/
sudo chmod 644 /opt/camera-agent/models/yolov8n.hef
```

## Alternative: If You Can't Access Hailo Model Zoo

If you don't have access to Hailo Model Zoo yet, you can:

1. **Register for free account** - It's free and gives access to pre-compiled models
2. **Use TFLite temporarily** - Set up a TFLite model as fallback (lower performance)
3. **Check Hailo installation** - Some Hailo SDK installations include sample models

## Verify the File

After copying, verify it's there:
```bash
ls -lh /opt/camera-agent/models/*.hef
```

The file should be several MB in size (typically 5-20 MB depending on model size).

