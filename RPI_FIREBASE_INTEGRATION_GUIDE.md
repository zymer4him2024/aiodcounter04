# Raspberry Pi to Firebase Integration Guide

Complete guide to integrate deployed Raspberry Pi cameras with `aiodcounter04-superadmin.web.app` and `aiodcouter04.web.app`.

## 📋 Overview

This guide covers the complete integration workflow:
1. Camera registration in dashboard
2. Service account setup on RPi
3. Camera configuration generation
4. Camera agent deployment
5. Data flow verification

---

## 🏗️ Architecture

### Data Flow
```
Raspberry Pi Camera
    ↓ (detects objects)
Camera Agent (Python)
    ↓ (writes to Firestore)
Firestore Database
    ↓ (real-time updates)
Web Dashboard (React)
    ↓
Superadmin/Subadmin/Viewer
```

### Firestore Structure
```
/cameras/{cameraId}
    ├── name: string
    ├── siteId: string
    ├── subadminId: string
    ├── status: "online" | "offline"
    ├── lastSeen: Timestamp
    ├── fps?: number
    ├── frameCount?: number
    ├── detectorStatus?: {...}
    ├── systemHealth?: {...}
    └── /counts/{timestamp}
        ├── timestamp: Timestamp
        ├── cameraId: string
        ├── siteId: string
        ├── counts: object (flattened zone_class counts)
        └── metadata: object
```

---

## 🚀 Step-by-Step Integration

### Step 1: Register Camera in Dashboard

#### 1.1 Login to Superadmin Dashboard
- Navigate to: `https://aiodcounter04-superadmin.web.app`
- Login with your Google account (must be superadmin)

#### 1.2 Create Site (if not exists)
1. Go to **Sites** tab
2. Click **Create Site**
3. Fill in:
   - Site Name: e.g., "Main Warehouse"
   - Location: e.g., "123 Main St, City"
   - Assign to Subadmin (select from dropdown)
4. Click **Create**

#### 1.3 Approve Pending Camera
1. Go to **Cameras** tab
2. Find the camera in **Pending Cameras** section
3. Click **Approve**
4. Fill in:
   - Camera Name: e.g., "Warehouse Entrance"
   - Site: Select the site created above
5. Click **Approve Camera**

**Note:** The camera appears in pending when the RPi first boots and registers itself.

#### 1.4 Generate Provisioning Token (Alternative Method)
If you want to pre-provision cameras:

1. Go to **Provisioning** tab
2. Click **Generate Token**
3. Fill in:
   - Camera Name
   - Site
   - Expiry Days (default: 7)
4. Click **Generate**
5. Download/print the QR code
6. Place QR code on RPi case or scan during first boot

---

### Step 2: Set Up Service Account on RPi

#### 2.1 Download Service Account Key
The service account key is in your project root:
- File: `aiodcouter04-firebase-adminsdk-fbsvc-2b39b335bc.json`

#### 2.2 Copy to Raspberry Pi

**Option A: Using SCP (from your Mac)**
```bash
scp aiodcouter04-firebase-adminsdk-fbsvc-2b39b335bc.json \
    digioptics_od@CameraUnit.local:/opt/camera-agent/config/service-account.json
```

**Option B: Manual Copy**
1. SSH into RPi: `ssh digioptics_od@CameraUnit.local`
2. Create directory: `sudo mkdir -p /opt/camera-agent/config`
3. Create file: `sudo nano /opt/camera-agent/config/service-account.json`
4. Paste the entire JSON content from the service account file
5. Set permissions: `sudo chmod 600 /opt/camera-agent/config/service-account.json`

---

### Step 3: Generate Camera Configuration

#### 3.1 Get Camera Details from Dashboard

1. Login to dashboard: `https://aiodcounter04-superadmin.web.app`
2. Go to **Cameras** tab
3. Find your camera and note:
   - **Camera ID** (e.g., `CAM_ABC1234`)
   - **Site ID** (from the camera details)
   - **Subadmin ID** (from the site details)

#### 3.2 Create Configuration File

SSH into your RPi and create the config:

```bash
sudo nano /opt/camera-agent/config/config.json
```

Paste the following template and fill in your values:

```json
{
  "cameraId": "CAM_ABC1234",
  "siteId": "your-site-id",
  "orgId": "aiodcouter04",
  "serviceAccountPath": "/opt/camera-agent/config/service-account.json",
  "firebaseConfig": {
    "apiKey": "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
    "authDomain": "aiodcouter04.firebaseapp.com",
    "projectId": "aiodcouter04",
    "storageBucket": "aiodcouter04.firebasestorage.app",
    "messagingSenderId": "87816815492",
    "appId": "1:87816815492:web:849f2866d2fd63baf393d1"
  },
  "detectionConfig": {
    "modelPath": "/opt/camera-agent/models/yolov8n.tflite",
    "objectClasses": ["person", "vehicle", "forklift"],
    "confidenceThreshold": 0.75,
    "detectionZones": []
  },
  "transmissionConfig": {
    "aggregationInterval": 300,
    "maxRetries": 3,
    "timeout": 10000
  }
}
```

**Important Fields:**
- `cameraId`: From dashboard (CAM_XXX format)
- `siteId`: From dashboard camera details
- `orgId`: Always "aiodcouter04" for this project
- `serviceAccountPath`: Path to service account JSON

---

### Step 4: Deploy Camera Agent

#### 4.1 Verify Agent Files
```bash
# Check camera agent exists
ls -la /opt/camera-agent/camera_agent.py

# Check dependencies
pip3 list | grep -E "firebase-admin|opencv|tflite"
```

#### 4.2 Install Missing Dependencies
```bash
sudo pip3 install firebase-admin opencv-python tflite-runtime sqlalchemy psutil
```

#### 4.3 Test Configuration
```bash
# Test config loading
sudo python3 /opt/camera-agent/camera_agent.py /opt/camera-agent/config/config.json
# Should show: "Camera agent initialized: CAM_XXX"
# Press Ctrl+C to stop
```

#### 4.4 Start Camera Agent Service
```bash
# Enable service
sudo systemctl enable camera-agent

# Start service
sudo systemctl start camera-agent

# Check status
sudo systemctl status camera-agent

# View logs
sudo journalctl -u camera-agent -f
```

---

### Step 5: Verify Integration

#### 5.1 Check Firestore Console
1. Go to Firebase Console: https://console.firebase.google.com/project/aiodcouter04/firestore
2. Navigate to: `cameras/{cameraId}`
3. Verify document exists with correct fields
4. Check `status` field (should be "online" after agent starts)

#### 5.2 Check Counts Subcollection
1. In Firestore console, navigate to: `cameras/{cameraId}/counts`
2. Wait 5 minutes (counts are aggregated every 300 seconds by default)
3. Verify count documents appear

#### 5.3 Check Dashboard
1. Login to: `https://aiodcounter04-superadmin.web.app`
2. Go to **Live Counts** tab
3. Select your camera from dropdown
4. Verify:
   - Camera status shows "online" (green indicator)
   - Latest counts appear
   - Historical chart shows data
   - System health metrics display (if enabled)

---

## 🔧 Troubleshooting

### Camera Not Appearing in Dashboard

**Problem:** Camera doesn't show in dashboard after starting agent

**Solutions:**
1. Verify camera document exists in Firestore:
   ```bash
   # Check logs for errors
   sudo journalctl -u camera-agent -n 100
   ```
2. Verify service account permissions:
   - Service account must have Firestore write permissions
   - Check Firebase Console → IAM & Admin → Service Accounts
3. Verify camera ID matches:
   - Dashboard: Check camera ID in Cameras tab
   - RPi: Check `config.json` cameraId matches exactly

### No Counts Appearing

**Problem:** Camera shows online but no count data

**Solutions:**
1. Check aggregation interval:
   - Default: 300 seconds (5 minutes)
   - Adjust in `config.json` → `transmissionConfig.aggregationInterval`
2. Verify object detection working:
   ```bash
   # Check detector logs
   sudo journalctl -u camera-agent | grep -i "detection\|count"
   ```
3. Verify detection zones configured:
   - If no zones, counts may be zero
   - Add detection zones in config (future feature)

### Service Account Errors

**Problem:** "Permission denied" or "Invalid credentials"

**Solutions:**
1. Verify service account file exists:
   ```bash
   ls -la /opt/camera-agent/config/service-account.json
   ```
2. Verify file permissions:
   ```bash
   sudo chmod 600 /opt/camera-agent/config/service-account.json
   ```
3. Verify JSON is valid:
   ```bash
   python3 -m json.tool /opt/camera-agent/config/service-account.json
   ```

### Firebase Connection Errors

**Problem:** "Failed to connect to Firebase"

**Solutions:**
1. Check internet connection:
   ```bash
   ping 8.8.8.8
   ```
2. Verify Firestore API enabled:
   - Firebase Console → Project Settings → APIs
   - Ensure "Cloud Firestore API" is enabled
3. Check firewall:
   ```bash
   # Allow outbound HTTPS
   sudo ufw allow out 443/tcp
   ```

---

## 📊 Monitoring

### View Real-Time Logs
```bash
sudo journalctl -u camera-agent -f
```

### Check System Status
```bash
# Service status
sudo systemctl status camera-agent

# Resource usage
top -p $(pgrep -f camera_agent.py)

# Disk usage
df -h /var/lib/camera_agent
```

### Monitor Firestore Writes
1. Firebase Console → Firestore → Usage tab
2. Monitor write operations
3. Check for errors in Firestore console

---

## 🔄 Update Camera Configuration

To update camera settings:

1. Edit config file:
   ```bash
   sudo nano /opt/camera-agent/config/config.json
   ```

2. Restart service:
   ```bash
   sudo systemctl restart camera-agent
   ```

3. Verify in dashboard (changes should reflect within 60 seconds)

---

## 📝 Next Steps

After successful integration:

1. **Configure Detection Zones** (future enhancement)
   - Define areas for counting
   - Set direction (in/out/bidirectional)

2. **Set Up Alerts** (future enhancement)
   - Configure notifications for offline cameras
   - Set thresholds for count anomalies

3. **Performance Tuning**
   - Adjust `aggregationInterval` based on needs
   - Tune `confidenceThreshold` for accuracy
   - Optimize frame rate for hardware

---

## 📞 Support

For issues:
1. Check logs: `sudo journalctl -u camera-agent -n 200`
2. Check Firestore console for data flow
3. Verify all steps in this guide were followed

---

## ✅ Integration Checklist

- [ ] Camera registered in dashboard
- [ ] Service account JSON copied to RPi
- [ ] Configuration file created with correct cameraId and siteId
- [ ] Camera agent service running
- [ ] Camera shows "online" in dashboard
- [ ] Count data appears in Firestore
- [ ] Live counts display in dashboard
- [ ] System health metrics showing (optional)

---

**Last Updated:** December 27, 2024
**Project:** aiodcounter04
**Firebase Project:** aiodcouter04


