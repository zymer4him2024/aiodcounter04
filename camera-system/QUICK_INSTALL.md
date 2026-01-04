# Quick Installation Guide

## One-Line Transfer and Install

From your laptop, run:

```bash
scp -r camera-system/ digioptics_od@ShawnRaspberryPi.local:/tmp/ && \
ssh digioptics_od@ShawnRaspberryPi.local "cd /tmp/camera-system && sudo bash install-camera-system.sh"
```

## Step-by-Step Installation

### 1. Transfer Files
```bash
scp -r camera-system/ digioptics_od@ShawnRaspberryPi.local:/tmp/
```

### 2. SSH into RPi
```bash
ssh digioptics_od@ShawnRaspberryPi.local
```

### 3. Run Installation
```bash
cd /tmp/camera-system
sudo bash install-camera-system.sh
```

### 4. Install Python Dependencies
```bash
pip3 install -r /tmp/camera-system/requirements.txt
```

### 5. Configure and Start
```bash
# Create config file (see README.md for example)
sudo nano /opt/camera-agent/config/config.json

# Start service
sudo systemctl start camera-agent
sudo systemctl status camera-agent
```

## Verify Installation

```bash
# Check files are in place
ls -la /opt/camera-agent/
ls -la /opt/camera-agent/plugins/

# Check service status
sudo systemctl status camera-agent

# View logs
sudo journalctl -u camera-agent -f
```






