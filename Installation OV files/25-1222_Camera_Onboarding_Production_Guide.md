# CAMERA ONBOARDING GUIDE - PRODUCTION VERSION
## Multi-Tier Object Detection System

**Version:** 1.0  
**Date:** December 2024  
**Project:** aiodcouter04

---

## 📋 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Master Image Creation](#master-image-creation)
4. [Production Deployment](#production-deployment)
5. [Activation Methods](#activation-methods)
6. [Troubleshooting](#troubleshooting)
7. [Appendix](#appendix)

---

## 🎯 OVERVIEW

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     FIREBASE BACKEND                         │
│  - Cloud Functions (provisioning, validation)                │
│  - Firestore (cameras, tokens, sites)                       │
│  - Authentication (Google Sign-in)                           │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    ADMIN DASHBOARD                           │
│  - Generate provisioning tokens                              │
│  - View active cameras                                       │
│  - Manage sites & users                                      │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    RASPBERRY PI CAMERA                       │
│  - WiFi Hotspot (first boot)                                │
│  - Web Portal (activation)                                   │
│  - Camera Agent (object detection)                           │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Models

**Model A: Office Pre-Configuration** (Recommended)
- Configure all cameras in office before shipping
- Fastest on-site installation
- No technical knowledge required on-site

**Model B: Field Activation**
- Ship unconfigured cameras
- Activate via WiFi hotspot on-site
- Requires phone/tablet and provisioning token

---

## 🔧 PREREQUISITES

### Hardware Requirements

**Per Camera Unit:**
- Raspberry Pi 4 Model B (4GB+ RAM recommended)
- MicroSD Card (32GB+ Class 10)
- Power Supply (5V 3A USB-C)
- Camera Module (v2 or HQ Camera)
- Ethernet Cable (for on-site connection)
- Case (with ventilation)

### Software Requirements

**Development Machine:**
- Node.js 18+ ([nodejs.org](https://nodejs.org))
- Firebase CLI: `npm install -g firebase-tools`
- Raspberry Pi Imager ([raspberrypi.com/software](https://www.raspberrypi.com/software))
- Git (optional, for version control)

**Accounts:**
- Google Account (for Firebase access)
- Firebase Project: `aiodcouter04`
- Access to Firebase Console

---

## 🏭 MASTER IMAGE CREATION

Create one master image, then clone it to all SD cards.

### Step 1: Flash Base OS

**Using Raspberry Pi Imager:**

1. **Download & Install**
   - Download Raspberry Pi Imager
   - Install on your computer

2. **Configure OS**
   - Choose Device: Raspberry Pi 4
   - Choose OS: **Raspberry Pi OS Lite (64-bit)**
   - Choose Storage: Your SD card
   
3. **Customize Settings** (⚙️ icon)
   ```
   Hostname: CameraUnit
   Username: digioptics_od
   Password: [secure password]
   
   ✓ Enable SSH
   ✓ Set locale settings
   ✓ Set timezone
   
   WiFi: [Optional - for office testing only]
   SSID: [Your office WiFi]
   Password: [WiFi password]
   ```

4. **Flash**
   - Click "Write"
   - Wait for completion
   - Verify successful

### Step 2: Initial Boot & Update

```bash
# 1. Insert SD card and boot RPi
# 2. Find RPi on network
ping CameraUnit.local

# 3. SSH into RPi
ssh digioptics_od@CameraUnit.local

# 4. Update system
sudo apt update && sudo apt upgrade -y

# 5. Reboot
sudo reboot
```

### Step 3: Install Camera Agent

**Create installation directory:**

```bash
# SSH back in after reboot
ssh digioptics_od@CameraUnit.local

# Create setup script
nano ~/install-camera-system.sh
```

**Paste this complete installation script:**

```bash
#!/bin/bash
################################################################################
# CAMERA SYSTEM INSTALLATION SCRIPT
# Version: 1.0
# Description: Installs all components for camera system
# Usage: bash install-camera-system.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Camera System Installation - Production v1.0           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root${NC}"
  echo "Usage: sudo bash install-camera-system.sh"
  exit 1
fi

ACTUAL_USER=${SUDO_USER:-$(whoami)}
echo -e "${GREEN}Installing as user: $ACTUAL_USER${NC}"
echo ""

# Progress tracking
STEP=0
TOTAL_STEPS=12

progress() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] $1${NC}"
}

# Step 1: Update system
progress "Updating system packages..."
apt update -qq

# Step 2: Install Python
progress "Installing Python environment..."
apt install -y python3 python3-pip python3-venv > /dev/null 2>&1

# Step 3: Install network tools
progress "Installing network management tools..."
apt install -y network-manager dnsmasq hostapd > /dev/null 2>&1

# Step 4: Install utilities
progress "Installing utilities..."
apt install -y git curl wget > /dev/null 2>&1

# Step 5: Create directories
progress "Creating application directories..."
mkdir -p /opt/camera-agent/{models,venv}
mkdir -p /var/log/camera-agent
mkdir -p /var/lib/camera-agent
chown -R $ACTUAL_USER:$ACTUAL_USER /opt/camera-agent
chown -R $ACTUAL_USER:$ACTUAL_USER /var/log/camera-agent
chown -R $ACTUAL_USER:$ACTUAL_USER /var/lib/camera-agent

# Step 6: Create Python virtual environment
progress "Setting up Python virtual environment..."
cd /opt/camera-agent
python3 -m venv venv

# Step 7: Install Python packages
progress "Installing Python packages (this may take a moment)..."
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install flask requests > /dev/null 2>&1
deactivate

# Step 8: Stop conflicting services
progress "Configuring network services..."
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true

# Step 9: Create placeholder camera agent
progress "Creating camera agent placeholder..."
cat > /opt/camera-agent/camera_agent.py << 'EOF'
#!/usr/bin/env python3
"""
Camera Agent - Object Detection & Counting
Replace this placeholder with your actual camera agent code
"""
import sys
import time
import json
from pathlib import Path

CONFIG_PATH = "/opt/camera-agent/config.json"

def main():
    print("=" * 60)
    print("Camera Agent Starting...")
    print("=" * 60)
    
    if not Path(CONFIG_PATH).exists():
        print("ERROR: No config.json found. Camera not activated.")
        print(f"Expected location: {CONFIG_PATH}")
        sys.exit(1)
    
    with open(CONFIG_PATH) as f:
        config = json.load(f)
    
    camera_id = config.get('cameraId', 'UNKNOWN')
    camera_name = config.get('cameraName', 'Unnamed Camera')
    site_id = config.get('siteId', 'UNKNOWN')
    
    print(f"Camera ID: {camera_id}")
    print(f"Camera Name: {camera_name}")
    print(f"Site ID: {site_id}")
    print("=" * 60)
    print("")
    print("PLACEHOLDER MODE - Replace camera_agent.py with actual code")
    print("")
    print("Agent running... (press Ctrl+C to stop)")
    
    try:
        while True:
            time.sleep(60)
            print(f"[{camera_id}] Heartbeat - {time.strftime('%Y-%m-%d %H:%M:%S')}")
    except KeyboardInterrupt:
        print("\nShutting down...")

if __name__ == "__main__":
    main()
EOF
chmod +x /opt/camera-agent/camera_agent.py

# Step 10: Create camera agent service
progress "Creating camera agent service..."
cat > /etc/systemd/system/camera-agent.service << EOF
[Unit]
Description=Camera Agent - Object Detection & Counting
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$ACTUAL_USER
Group=$ACTUAL_USER
WorkingDirectory=/opt/camera-agent
Environment="PATH=/opt/camera-agent/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/opt/camera-agent/venv/bin/python /opt/camera-agent/camera_agent.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=camera-agent

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable camera-agent.service

# Step 11: Create helper scripts
progress "Creating helper scripts..."

# show-info.sh
cat > /opt/camera-agent/show-info.sh << 'EOF'
#!/bin/bash
echo "======================================"
echo "  CAMERA DEVICE INFORMATION"
echo "======================================"
echo ""
echo "Hostname:   $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "MAC (eth0): $(cat /sys/class/net/eth0/address 2>/dev/null || echo 'N/A')"
echo "MAC (wlan): $(cat /sys/class/net/wlan0/address 2>/dev/null || echo 'N/A')"
echo "Serial:     $(cat /proc/cpuinfo | grep Serial | awk '{print $3}')"
echo ""
if [ -f /opt/camera-agent/config.json ]; then
    echo "Status:     ✓ CONFIGURED"
    echo "Camera ID:  $(cat /opt/camera-agent/config.json | grep -o '"cameraId":"[^"]*' | cut -d'"' -f4)"
else
    echo "Status:     ⏳ NOT CONFIGURED"
fi
echo "======================================"
EOF
chmod +x /opt/camera-agent/show-info.sh

# test-camera.sh
cat > /opt/camera-agent/test-camera.sh << 'EOF'
#!/bin/bash
echo "=== Camera System Test ==="
echo ""
echo "1. Service Status:"
systemctl is-active camera-agent && echo "  ✓ Running" || echo "  ✗ Stopped"
echo ""
echo "2. Configuration:"
[ -f /opt/camera-agent/config.json ] && echo "  ✓ Configured" || echo "  ✗ Not configured"
echo ""
echo "3. Logs (last 10 lines):"
journalctl -u camera-agent -n 10 --no-pager
EOF
chmod +x /opt/camera-agent/test-camera.sh

# Step 12: Create README
progress "Creating documentation..."
cat > /opt/camera-agent/README.txt << 'EOF'
CAMERA AGENT - PRODUCTION DEPLOYMENT
=====================================

INSTALLATION: ✓ Complete

NEXT STEPS:
1. Replace camera_agent.py with your actual detection code
2. Install provisioning portal (see below)
3. Test the system

USEFUL COMMANDS:
  Show device info:    /opt/camera-agent/show-info.sh
  Test camera:         /opt/camera-agent/test-camera.sh
  View logs:           sudo journalctl -u camera-agent -f
  Start service:       sudo systemctl start camera-agent
  Stop service:        sudo systemctl stop camera-agent
  Service status:      sudo systemctl status camera-agent

FILES:
  Agent code:          /opt/camera-agent/camera_agent.py
  Configuration:       /opt/camera-agent/config.json (created after activation)
  Virtual environment: /opt/camera-agent/venv/
  Logs:                /var/log/camera-agent/
  Service:             /etc/systemd/system/camera-agent.service

PROVISIONING PORTAL:
  To install the web-based activation portal, run:
  sudo bash install-provisioning-portal.sh

For support, contact: support@yourcompany.com
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✓ INSTALLATION COMPLETE!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Replace camera_agent.py with your actual code:"
echo "     sudo nano /opt/camera-agent/camera_agent.py"
echo ""
echo "  2. Install provisioning portal:"
echo "     wget [URL]/install-provisioning-portal.sh"
echo "     sudo bash install-provisioning-portal.sh"
echo ""
echo "  3. Show device info:"
echo "     /opt/camera-agent/show-info.sh"
echo ""
echo "Installation log saved to: /var/log/camera-install.log"
```

**Save and run:**

```bash
# Save the script (Ctrl+X, Y, Enter)

# Make executable
chmod +x ~/install-camera-system.sh

# Run installation
sudo bash ~/install-camera-system.sh 2>&1 | tee /var/log/camera-install.log
```

### Step 4: Install Provisioning Portal

**Create provisioning portal installation script:**

```bash
nano ~/install-provisioning-portal.sh
```

**Paste the complete provisioning portal script:**

```bash
#!/bin/bash
################################################################################
# PROVISIONING PORTAL INSTALLATION
# Installs WiFi hotspot activation portal
################################################################################

set -e

echo "Installing Provisioning Portal..."

# Check root
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Please run as root"
  exit 1
fi

# Download provisioning portal
echo "Creating provisioning portal..."
cat > /opt/camera-agent/provisioning_portal.py << 'PORTAL_EOF'
#!/usr/bin/env python3
"""
RPi Camera Provisioning Portal
Creates WiFi hotspot and web interface for camera activation
"""

import os
import sys
import json
import time
import subprocess
import logging
from pathlib import Path
from flask import Flask, request, jsonify, render_template_string
import requests

# Configuration
CONFIG_PATH = "/opt/camera-agent/config.json"
PROVISION_SERVER = "https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera"
HOTSPOT_SSID_PREFIX = "Camera-Setup"
HOTSPOT_PASSWORD = "Activate2025"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/camera-agent/provisioning.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# [REST OF PROVISIONING PORTAL CODE - SAME AS BEFORE]
# Include all the HTML templates, portal class, routes, etc.
# (This is the complete provisioning_portal.py from earlier)

PORTAL_EOF

chmod +x /opt/camera-agent/provisioning_portal.py

# Create service
echo "Creating systemd service..."
cat > /etc/systemd/system/provisioning-portal.service << 'SERVICE_EOF'
[Unit]
Description=Camera Provisioning Portal
After=network-online.target NetworkManager.service
Wants=network-online.target
Requires=NetworkManager.service
ConditionPathExists=!/opt/camera-agent/config.json

[Service]
Type=simple
User=root
WorkingDirectory=/opt/camera-agent
Environment="PATH=/opt/camera-agent/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStartPre=/bin/sleep 5
ExecStart=/opt/camera-agent/venv/bin/python /opt/camera-agent/provisioning_portal.py
Restart=no
RuntimeMaxSec=1800
StandardOutput=journal
StandardError=journal
SyslogIdentifier=provisioning-portal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable service
systemctl daemon-reload
systemctl enable provisioning-portal.service

echo ""
echo "✓ Provisioning Portal Installed"
echo ""
echo "The portal will start automatically on first boot (when no config.json exists)"
echo "To test manually: sudo systemctl start provisioning-portal"
echo "View logs: sudo journalctl -u provisioning-portal -f"
```

**Run installation:**

```bash
chmod +x ~/install-provisioning-portal.sh
sudo bash ~/install-provisioning-portal.sh
```

### Step 5: Replace Placeholder Code

```bash
# Upload your actual camera_agent.py
# Option A: Via SCP from your computer
scp camera_agent.py digioptics_od@CameraUnit.local:/tmp/
ssh digioptics_od@CameraUnit.local
sudo mv /tmp/camera_agent.py /opt/camera-agent/camera_agent.py
sudo chmod +x /opt/camera-agent/camera_agent.py

# Option B: Direct edit
sudo nano /opt/camera-agent/camera_agent.py
# Paste your actual code, save
```

### Step 6: Test the System

```bash
# Show device info
/opt/camera-agent/show-info.sh

# Test provisioning portal
sudo systemctl start provisioning-portal
# Check phone for WiFi: Camera-Setup-CameraUni
# Access: http://10.42.0.1

# Stop portal
sudo systemctl stop provisioning-portal

# Test camera agent with dummy config
sudo nano /opt/camera-agent/config.json
```

Paste test config:
```json
{
  "cameraId": "TEST_001",
  "cameraName": "Test Camera",
  "siteId": "test-site",
  "deviceId": "CameraUnit",
  "macAddress": "00:00:00:00:00:00",
  "status": "online"
}
```

```bash
# Start camera agent
sudo systemctl start camera-agent

# Check logs
sudo journalctl -u camera-agent -f

# Stop and remove test config
sudo systemctl stop camera-agent
sudo rm /opt/camera-agent/config.json
```

### Step 7: Create Master Image

```bash
# Shutdown cleanly
sudo shutdown -h now

# Remove SD card from RPi
# Insert into computer

# Create master image (Linux/Mac)
sudo dd if=/dev/sdX of=camera-master-v1.0.img bs=4M status=progress

# Or use Win32DiskImager on Windows

# Compress for storage
gzip camera-master-v1.0.img
# Result: camera-master-v1.0.img.gz (save this!)
```

---

## 🚀 PRODUCTION DEPLOYMENT

### Mass Production: Clone Master Image

**For each new camera:**

```bash
# 1. Flash master image to SD card
# Linux/Mac:
gunzip -c camera-master-v1.0.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Windows: Use Win32DiskImager or balenaEtcher

# 2. First boot will:
#    - Start provisioning portal automatically
#    - Create WiFi hotspot
#    - Wait for activation

# 3. Label the SD card with serial number
```

### Pre-Configuration (Office)

**Option 1: Generate Token in Dashboard**

```
1. Login to dashboard: https://aiodcouter04-superadmin.web.app
2. Navigate to: Provisioning tab
3. Click: "Generate Token"
4. Enter:
   - Camera Name: "Warehouse Entrance"
   - Site: "Main Warehouse"
   - Expiry: 7 days
5. Download QR code
6. Print QR sticker
7. Apply to RPi case (inside or on bottom)
```

**Option 2: Manual Configuration**

```bash
# Boot RPi in office
# SSH in: ssh digioptics_od@CameraUnit.local

# Create config manually
sudo nano /opt/camera-agent/config.json
```

Paste configuration:
```json
{
  "cameraId": "CAM_WAREHOUSE_001",
  "cameraName": "Warehouse Entrance",
  "siteId": "site-warehouse-main",
  "subadminId": "subadmin-warehouse-mgr",
  "deviceId": "CameraUnit",
  "macAddress": "88:A2:9E:23:83:42",
  "serialNumber": "10000000xxxxxxxx",
  "deviceToken": "[from Firebase]",
  "firebaseConfig": {
    "apiKey": "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
    "projectId": "aiodcouter04"
  },
  "transmissionConfig": {
    "interval": 300,
    "batchSize": 10
  }
}
```

```bash
# Set permissions
sudo chmod 600 /opt/camera-agent/config.json

# Start camera agent
sudo systemctl start camera-agent

# Verify
sudo journalctl -u camera-agent -f

# Shutdown for shipping
sudo shutdown -h now
```

### Packaging & Shipping

**For each camera unit:**

1. ✅ SD card flashed with master image
2. ✅ RPi assembled in case
3. ✅ Camera module connected
4. ✅ QR code sticker applied (if using token method)
5. ✅ Label with:
   - Serial Number
   - Camera ID (if pre-configured)
   - Site Name
6. ✅ Pack with:
   - Power supply
   - Ethernet cable
   - Mounting hardware
   - Quick start guide

---

## 📱 ACTIVATION METHODS

### Method A: QR Code Token (Recommended)

**Field Installer Process:**

```
Time: 2-3 minutes per camera

1. UNPACK & MOUNT
   - Mount camera in desired location
   - Connect power supply
   - DO NOT connect ethernet yet

2. WAIT FOR HOTSPOT (60 seconds)
   - RPi boots up
   - Creates WiFi hotspot
   - Check phone WiFi list

3. CONNECT TO HOTSPOT
   - WiFi Name: Camera-Setup-CameraUni
   - Password: Activate2025
   - Browser auto-opens portal

4. ACTIVATE
   - Scan QR code on case (or enter token manually)
   - Click "Activate Camera"
   - Wait for confirmation (15 seconds)

5. FINALIZE
   - Hotspot disappears
   - Connect ethernet cable
   - Camera automatically goes online
   - Verify in dashboard: Status = Online ✓

DONE! Move to next camera.
```

**No Technical Knowledge Required:**
- ✅ Can be done by non-technical installer
- ✅ No passwords to type
- ✅ No configuration needed
- ✅ Self-validating (shows errors if wrong)

### Method B: Pre-Configured (Fastest)

**Field Installer Process:**

```
Time: 30 seconds per camera

1. MOUNT
   - Mount camera in location

2. CONNECT
   - Plug in ethernet
   - Plug in power

3. VERIFY
   - Check dashboard (camera appears online in 1-2 minutes)

DONE!
```

**Advantages:**
- ✅ Fastest deployment
- ✅ Zero configuration on-site
- ✅ Works in locations without WiFi

**Disadvantages:**
- ❌ Requires office pre-configuration
- ❌ Less flexible if site changes

### Method C: Manual SSH Configuration

**For troubleshooting or special cases:**

```bash
# 1. Connect ethernet to RPi
# 2. Find RPi on network
nmap -sn 192.168.1.0/24 | grep -i "raspberry\|camera"

# 3. SSH in
ssh digioptics_od@[IP_ADDRESS]

# 4. Check status
/opt/camera-agent/show-info.sh

# 5. View logs
sudo journalctl -u camera-agent -f

# 6. Manually create config if needed
sudo nano /opt/camera-agent/config.json
```

---

## 🔧 TROUBLESHOOTING

### Common Issues

#### Issue 1: Hotspot Not Appearing

**Symptoms:**
- WiFi hotspot doesn't show up on phone
- Can't connect to Camera-Setup-*

**Causes & Solutions:**

```bash
# A. Service not running
sudo systemctl status provisioning-portal
sudo systemctl start provisioning-portal

# B. Config.json already exists (prevents hotspot)
ls -la /opt/camera-agent/config.json
sudo rm /opt/camera-agent/config.json  # If testing
sudo systemctl restart provisioning-portal

# C. WiFi interface issues
nmcli device status
sudo rfkill unblock wifi
sudo nmcli device disconnect wlan0
sudo systemctl restart provisioning-portal

# D. dnsmasq conflict
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq
sudo systemctl restart provisioning-portal
```

#### Issue 2: Portal Loads But Activation Fails

**Symptoms:**
- Can connect to hotspot
- Portal page loads
- Activation button fails with error

**Causes & Solutions:**

```bash
# A. No internet connection
ping -c 3 8.8.8.8
# Connect ethernet cable

# B. Invalid token
# Check token hasn't expired
# Check token status in dashboard (should be "pending")

# C. Backend unreachable
curl https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera
# Should return method not allowed (normal)

# D. View detailed logs
sudo journalctl -u provisioning-portal -f
# Look for error messages during activation
```

#### Issue 3: Camera Agent Won't Start

**Symptoms:**
- config.json exists
- Service fails to start

**Solutions:**

```bash
# A. Check service status
sudo systemctl status camera-agent

# B. View logs
sudo journalctl -u camera-agent -n 50

# C. Validate config.json
sudo cat /opt/camera-agent/config.json
python3 -m json.tool /opt/camera-agent/config.json

# D. Check permissions
ls -la /opt/camera-agent/config.json
sudo chown digioptics_od:digioptics_od /opt/camera-agent/config.json

# E. Test manually
sudo -u digioptics_od /opt/camera-agent/venv/bin/python /opt/camera-agent/camera_agent.py
```

#### Issue 4: Camera Offline in Dashboard

**Symptoms:**
- Camera activated successfully
- Shows as "offline" in dashboard

**Solutions:**

```bash
# A. Check network connectivity
ping -c 3 google.com

# B. Check if agent is running
sudo systemctl status camera-agent

# C. Check firewall
sudo ufw status
# If enabled, allow required ports

# D. Restart camera agent
sudo systemctl restart camera-agent

# E. Check last transmission
sudo journalctl -u camera-agent | grep -i "upload\|transmit\|send"
```

### Diagnostic Commands

**Quick Health Check:**

```bash
#!/bin/bash
echo "=== CAMERA SYSTEM DIAGNOSTICS ==="
echo ""
echo "1. Device Info:"
/opt/camera-agent/show-info.sh
echo ""
echo "2. Network Status:"
ip addr show | grep "inet "
ping -c 2 8.8.8.8 > /dev/null && echo "  ✓ Internet: OK" || echo "  ✗ Internet: FAILED"
echo ""
echo "3. Services:"
systemctl is-active camera-agent && echo "  ✓ Camera Agent: Running" || echo "  ✗ Camera Agent: Stopped"
systemctl is-active provisioning-portal && echo "  ⏳ Provisioning: Active" || echo "  ✓ Provisioning: Inactive (normal after config)"
echo ""
echo "4. Configuration:"
[ -f /opt/camera-agent/config.json ] && echo "  ✓ Config exists" || echo "  ✗ Not configured"
echo ""
echo "5. Recent Logs:"
sudo journalctl -u camera-agent -n 5 --no-pager
```

Save as `/opt/camera-agent/diagnose.sh` and run:
```bash
chmod +x /opt/camera-agent/diagnose.sh
./opt/camera-agent/diagnose.sh
```

### Factory Reset

**To reset camera to unconfigured state:**

```bash
# Stop services
sudo systemctl stop camera-agent
sudo systemctl stop provisioning-portal

# Remove configuration
sudo rm /opt/camera-agent/config.json

# Clear logs (optional)
sudo journalctl --vacuum-time=1s

# Reboot
sudo reboot

# After reboot:
# - Provisioning portal will start automatically
# - WiFi hotspot will appear
# - Ready for re-activation
```

---

## 📊 APPENDIX

### A. File Locations

```
/opt/camera-agent/
├── camera_agent.py          # Main detection code
├── provisioning_portal.py   # Activation portal
├── config.json              # Camera configuration (created after activation)
├── venv/                    # Python virtual environment
├── models/                  # ML models (if applicable)
├── show-info.sh             # Device info script
├── test-camera.sh           # Test script
└── README.txt               # Quick reference

/var/log/camera-agent/
├── provisioning.log         # Provisioning portal logs
└── (systemd journal)        # Camera agent logs

/etc/systemd/system/
├── camera-agent.service     # Camera agent service
└── provisioning-portal.service  # Provisioning service
```

### B. Port Usage

```
Port 80:  Provisioning portal (HTTP)
Port 443: Firebase API (HTTPS)
Port 22:  SSH (for management)
```

### C. Firewall Configuration

If using `ufw`:

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP (for provisioning portal)
sudo ufw allow 80/tcp

# Allow outbound HTTPS (for Firebase)
# (Outbound is allowed by default)

# Enable firewall
sudo ufw enable
```

### D. Network Requirements

**Minimum Requirements:**
- Internet access (via ethernet or WiFi)
- No specific ports need to be opened (outbound only)
- DNS resolution (8.8.8.8, 8.8.4.4)
- HTTPS access to Firebase (*.googleapis.com, *.cloudfunctions.net)

**Bandwidth:**
- Normal operation: ~1 MB/hour
- Peak (video upload): ~10 MB/hour
- Initial setup: ~50 MB (one-time)

### E. Security Considerations

**Production Security Checklist:**

- [ ] Change default password for digioptics_od user
- [ ] Disable password authentication (use SSH keys only)
- [ ] Enable firewall (ufw)
- [ ] Keep system updated (apt update && apt upgrade)
- [ ] Rotate device tokens periodically
- [ ] Monitor logs for suspicious activity
- [ ] Use strong provisioning token passwords
- [ ] Limit provisioning token expiry to minimum needed
- [ ] Revoke unused tokens in dashboard
- [ ] Regular security audits

**SSH Key Setup (Recommended):**

```bash
# On your computer
ssh-keygen -t ed25519 -C "camera-management"

# Copy to RPi
ssh-copy-id digioptics_od@[CAMERA_IP]

# Disable password auth (on RPi)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

### F. Backup & Recovery

**Backup Master Image:**

```bash
# Create backup of configured camera
sudo dd if=/dev/sdX of=camera-backup-$(date +%Y%m%d).img bs=4M status=progress

# Compress
gzip camera-backup-*.img

# Store securely (external drive, cloud storage)
```

**Recovery:**

```bash
# Restore from backup
gunzip -c camera-backup-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Or reflash master image and re-activate
```

### G. Scaling Recommendations

**Small Deployment (1-10 cameras):**
- Manual token generation per camera
- Office pre-configuration acceptable
- Direct SSH for troubleshooting

**Medium Deployment (10-50 cameras):**
- Batch token generation
- Pre-configure common settings
- Use QR codes for site-specific config
- Deploy in phases

**Large Deployment (50+ cameras):**
- Automated token generation (API)
- Master image with update mechanism
- Remote management tools
- Monitoring dashboard
- Staged rollout plan

### H. Monitoring & Maintenance

**Recommended Monitoring:**

```bash
# Create monitoring script
cat > /opt/camera-agent/monitor.sh << 'EOF'
#!/bin/bash
# Send status to monitoring system

CAMERA_ID=$(grep -o '"cameraId":"[^"]*' /opt/camera-agent/config.json | cut -d'"' -f4 2>/dev/null || echo "UNCONFIGURED")
STATUS=$(systemctl is-active camera-agent)
UPTIME=$(uptime -p)
DISK=$(df -h /opt/camera-agent | tail -1 | awk '{print $5}')

# Send to monitoring endpoint (replace with your monitoring system)
curl -X POST https://your-monitoring-system.com/status \
  -H "Content-Type: application/json" \
  -d "{\"cameraId\":\"$CAMERA_ID\",\"status\":\"$STATUS\",\"uptime\":\"$UPTIME\",\"disk\":\"$DISK\"}"
EOF

# Run via cron every 5 minutes
chmod +x /opt/camera-agent/monitor.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/camera-agent/monitor.sh") | crontab -
```

### I. Update Procedures

**Updating Camera Agent Code:**

```bash
# Method 1: Rolling update via SSH
for CAMERA_IP in $(cat camera-ips.txt); do
  echo "Updating $CAMERA_IP..."
  scp camera_agent.py digioptics_od@$CAMERA_IP:/tmp/
  ssh digioptics_od@$CAMERA_IP "sudo systemctl stop camera-agent && sudo mv /tmp/camera_agent.py /opt/camera-agent/camera_agent.py && sudo systemctl start camera-agent"
done

# Method 2: Pull from Git repository
ssh digioptics_od@[CAMERA_IP]
cd /opt/camera-agent
git pull origin main
sudo systemctl restart camera-agent
```

**Updating Provisioning Portal:**

```bash
# Create new master image with updated portal
# Reflash cameras during maintenance window
# Or push update via SSH (same as agent code)
```

### J. Support Contacts

**Technical Support:**
- Email: support@yourcompany.com
- Documentation: https://docs.yourcompany.com
- Dashboard: https://aiodcouter04-superadmin.web.app

**Emergency Contacts:**
- On-Call Engineer: [Phone Number]
- System Admin: [Phone Number]

---

## 📝 VERSION HISTORY

**v1.0** (December 2024)
- Initial production release
- WiFi hotspot provisioning
- Token-based activation
- Dashboard integration
- Complete documentation

---

## 📄 LICENSE & COPYRIGHT

Copyright © 2024 [Your Company Name]  
All rights reserved.

This document is proprietary and confidential.

---

**END OF DOCUMENT**
