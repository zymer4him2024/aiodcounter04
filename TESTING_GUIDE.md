# Testing Guide for Latest Build

## Overview
This guide walks you through testing the complete activation flow: provisioning portal → activation → camera agent service → Firestore upload.

## Prerequisites

### On Your Mac:
1. **Deploy Firebase Functions First** (updates config structure):
   ```bash
   cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04
   ./deploy-functions.sh
   ```

### On Raspberry Pi:
1. **Copy updated files to RPi**:
   ```bash
   # From your Mac, copy files to RPi
   scp camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/
   scp camera-system/camera-agent.service digioptics_od@ShawnRaspberryPi.local:/tmp/
   scp camera-system/test-activation-flow.sh digioptics_od@ShawnRaspberryPi.local:/tmp/
   scp camera-system/install-camera-service.sh digioptics_od@ShawnRaspberryPi.local:/tmp/
   
   # On RPi, move to correct locations
   ssh digioptics_od@ShawnRaspberryPi.local
   sudo mv /tmp/provisioning_portal.py /opt/camera-agent/
   sudo mv /tmp/camera-agent.service /etc/systemd/system/
   sudo mv /tmp/test-activation-flow.sh /opt/camera-agent/
   sudo mv /tmp/install-camera-service.sh /opt/camera-agent/
   sudo chmod +x /opt/camera-agent/*.sh
   ```

## Running the Test

### Step 1: Run Comprehensive Test Script
On your Raspberry Pi:
```bash
cd /opt/camera-agent
sudo ./test-activation-flow.sh
```

This script will:
- ✅ Verify portal file has new activation logic
- ✅ Check service file installation
- ✅ Test config transformation logic
- ✅ Validate portal module imports
- ✅ Test service installation
- ✅ Verify config structure (if camera is activated)
- ✅ Check service status

### Step 2: Manual Activation Test (End-to-End)

If the camera is **not yet activated**:

1. **Ensure provisioning portal is ready**:
   ```bash
   # Remove config if exists (for fresh test)
   sudo rm /opt/camera-agent/config.json  # Only if you want to retest activation
   
   # Ensure portal service can run
   sudo systemctl stop provisioning-portal
   sudo systemctl start provisioning-portal
   ```

2. **Connect phone to camera WiFi**:
   - WiFi Name: `AIOD-Camera-<hostname>`
   - Password: `aiod2024`

3. **Open portal in browser**:
   - URL: `http://192.168.4.1`
   - Or with token: `http://192.168.4.1/?token=PT_YOUR_TOKEN`

4. **Get a provisioning token from dashboard**:
   - Log into superadmin dashboard
   - Go to "Provisioning" tab
   - Generate a new token (or use existing)
   - Copy the token (starts with `PT_`)

5. **Activate camera**:
   - Enter token in portal
   - Click "Activate Camera"
   - Wait for success message

6. **Verify activation worked**:
   ```bash
   # Check config was created
   sudo cat /opt/camera-agent/config.json | jq .
   
   # Check service is enabled
   sudo systemctl is-enabled camera-agent
   
   # Check service is running
   sudo systemctl status camera-agent
   
   # View service logs
   sudo journalctl -u camera-agent -f
   ```

### Step 3: Verify Firestore Data

1. **Check Firestore Console**:
   - Go to: https://console.firebase.google.com/project/aiodcouter04/firestore
   - Navigate to: `cameras/{cameraId}/counts/`
   - You should see count documents appearing

2. **Check Dashboard**:
   - Open web dashboard
   - Go to "Live Counts" tab
   - Select the activated camera
   - Should see count data (once camera agent starts processing)

## Troubleshooting

### Portal doesn't start
```bash
# Check if config exists (prevents portal from starting)
ls -la /opt/camera-agent/config.json

# Check portal logs
sudo journalctl -u provisioning-portal -f
```

### Service doesn't start after activation
```bash
# Check service logs
sudo journalctl -u camera-agent -n 50 --no-pager

# Common issues:
# - Missing service-account.json
# - Invalid config.json structure
# - Missing Python dependencies
```

### Config transformation issues
```bash
# Validate config structure
python3 -m json.tool /opt/camera-agent/config.json

# Check if required fields exist
python3 << 'EOF'
import json
with open('/opt/camera-agent/config.json') as f:
    c = json.load(f)
    print("aggregationInterval:", 'aggregationInterval' in c.get('transmissionConfig', {}))
    print("detectionZones:", 'detectionZones' in c.get('detectionConfig', {}))
    print("orgId:", 'orgId' in c)
EOF
```

### Service account missing
```bash
# Verify service account exists
ls -la /opt/camera-agent/service-account.json

# If missing, you need to add it to the RPi image
# It should be pre-installed in the master image
```

## Expected Flow

```
1. User scans QR code → Opens portal
2. User enters token → Clicks "Activate"
3. Portal calls Firebase function → Receives config
4. Portal transforms config → Saves to /opt/camera-agent/config.json
5. Portal enables camera-agent service → Starts service
6. Portal stops itself (no longer needed)
7. Camera agent service starts → Reads config
8. Camera agent initializes Firebase → Connects to Firestore
9. Camera agent starts counting → Uploads counts to Firestore
10. Dashboard displays counts in real-time
```

## Success Criteria

✅ All tests pass in `test-activation-flow.sh`
✅ Config file created with correct structure
✅ Service enabled and running
✅ Portal stopped after activation
✅ Firestore receives count data
✅ Dashboard displays counts

## Quick Test Commands

```bash
# Full test
sudo /opt/camera-agent/test-activation-flow.sh

# Check service status
sudo systemctl status camera-agent

# Check portal status (should be stopped after activation)
sudo systemctl status provisioning-portal

# View agent logs
sudo journalctl -u camera-agent -f

# View portal logs (historical)
sudo journalctl -u provisioning-portal -n 100
```


