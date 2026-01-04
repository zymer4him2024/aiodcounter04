# Camera System Installation Guide

This directory contains the camera agent and plugins for the Raspberry Pi.

## Directory Structure

```
camera-system/
├── camera_agent.py          # Main camera agent script
├── install-camera-system.sh  # Installation script
├── requirements.txt          # Python dependencies
├── README.md                 # This file
└── plugins/
    ├── base_detector.py      # Base detector plugin interface
    └── traffic_monitor/       # Traffic monitoring plugin
        ├── __init__.py
        └── traffic_monitor.py
```

## Installation Steps

### 1. Transfer Files to Raspberry Pi

From your laptop:

```bash
scp -r camera-system/ digioptics_od@ShawnRaspberryPi.local:/tmp/
```

### 2. SSH into Raspberry Pi

```bash
ssh digioptics_od@ShawnRaspberryPi.local
```

### 3. Run Installation

```bash
cd /tmp/camera-system
sudo bash install-camera-system.sh
```

The script will:
- Create `/opt/camera-agent/` directory structure
- Copy all agent files and plugins
- Create systemd service file
- Enable the service (but won't start it yet)

### 4. Configure the Agent

Create the configuration file:

```bash
sudo nano /opt/camera-agent/config/config.json
```

Example configuration:

```json
{
  "cameraId": "CAM_XXXXXXXX",
  "siteId": "site-id",
  "orgId": "org-id",
  "firebaseConfig": {
    "projectId": "aiodcouter04"
  },
  "serviceAccountPath": "/opt/camera-agent/config/service-account.json",
  "detectionConfig": {
    "modelPath": "/opt/camera-agent/models/detection_model.tflite",
    "confidenceThreshold": 0.5,
    "objectClasses": ["person", "vehicle", "forklift"],
    "detectionZones": [
      {
        "name": "entrance",
        "polygon": [[0, 0], [100, 0], [100, 100], [0, 100]],
        "direction": "in"
      }
    ]
  },
  "transmissionConfig": {
    "aggregationInterval": 300,
    "maxRetries": 3
  }
}
```

### 5. Install Python Dependencies

```bash
pip3 install -r /tmp/camera-system/requirements.txt
```

Or manually:

```bash
pip3 install opencv-python numpy firebase-admin sqlalchemy tflite-runtime python-dotenv
```

### 6. Start the Service

```bash
sudo systemctl start camera-agent
sudo systemctl status camera-agent
```

## Service Management

- **Start**: `sudo systemctl start camera-agent`
- **Stop**: `sudo systemctl stop camera-agent`
- **Restart**: `sudo systemctl restart camera-agent`
- **Status**: `sudo systemctl status camera-agent`
- **Logs**: `sudo journalctl -u camera-agent -f`
- **Enable on boot**: `sudo systemctl enable camera-agent` (already done by install script)

## Troubleshooting

### Check if service is running
```bash
sudo systemctl status camera-agent
```

### View recent logs
```bash
sudo journalctl -u camera-agent -n 50
```

### Check file permissions
```bash
ls -la /opt/camera-agent/
ls -la /opt/camera-agent/plugins/
```

### Verify Python dependencies
```bash
python3 -c "import cv2, numpy, firebase_admin, sqlalchemy; print('All dependencies installed')"
```

## Manual Installation (Alternative)

If you prefer to install manually:

```bash
# Create directories
sudo mkdir -p /opt/camera-agent/plugins
sudo mkdir -p /opt/camera-agent/config
sudo mkdir -p /var/log/camera-agent
sudo mkdir -p /var/lib/camera-agent

# Copy files
sudo cp camera_agent.py /opt/camera-agent/
sudo cp plugins/base_detector.py /opt/camera-agent/plugins/
sudo cp -r plugins/traffic_monitor /opt/camera-agent/plugins/

# Set permissions
sudo chmod +x /opt/camera-agent/camera_agent.py
sudo chown -R pi:pi /opt/camera-agent
sudo chown -R pi:pi /var/log/camera-agent
sudo chown -R pi:pi /var/lib/camera-agent
```






