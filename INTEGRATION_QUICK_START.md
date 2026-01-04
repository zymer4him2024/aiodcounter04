# Quick Start: RPi to Firebase Integration

## 🎯 Goal
Connect your deployed Raspberry Pi camera to `aiodcounter04-superadmin.web.app` and `aiodcouter04.web.app`.

---

## ⚡ Quick Setup (5 Steps)

### Step 1: Register Camera in Dashboard
1. Login: https://aiodcounter04-superadmin.web.app
2. Go to **Cameras** tab
3. Approve pending camera OR create new camera
4. **Note the Camera ID** (e.g., `CAM_ABC1234`)

### Step 2: Copy Service Account to RPi
From your Mac:
```bash
scp aiodcouter04-firebase-adminsdk-fbsvc-2b39b335bc.json \
    digioptics_od@CameraUnit.local:/opt/camera-agent/config/service-account.json
```

### Step 3: Generate Configuration
On RPi, run the setup script:
```bash
cd /opt/camera-agent
sudo bash setup_rpi_integration.sh
```

Or manually create `/opt/camera-agent/config/config.json`:
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

### Step 4: Install Dependencies
```bash
sudo pip3 install firebase-admin opencv-python-headless tflite-runtime sqlalchemy psutil
```

### Step 5: Start Camera Agent
```bash
sudo systemctl start camera-agent
sudo systemctl status camera-agent
sudo journalctl -u camera-agent -f
```

---

## ✅ Verify Integration

1. **Check Firestore Console:**
   - https://console.firebase.google.com/project/aiodcouter04/firestore
   - Navigate to: `cameras/{cameraId}`
   - Verify `status: "online"` and `lastSeen` updating

2. **Check Dashboard:**
   - https://aiodcounter04-superadmin.web.app
   - Go to **Live Counts** tab
   - Select your camera
   - Verify status shows "online" (green)

3. **Wait for Counts:**
   - Counts aggregate every 5 minutes (300 seconds)
   - Check `cameras/{cameraId}/counts` in Firestore
   - Verify count documents appear

---

## 🔧 Files Created/Updated

### Integration Files:
- ✅ `RPI_FIREBASE_INTEGRATION_GUIDE.md` - Complete integration guide
- ✅ `camera-system/camera_agent.py` - Updated to write to correct Firestore path
- ✅ `camera-system/generate_config.py` - Config generator script
- ✅ `camera-system/update_camera_status.py` - Status update utility
- ✅ `camera-system/setup_rpi_integration.sh` - Automated setup script

### Key Changes:
- **Firestore Path:** Updated from `/organizations/{orgId}/sites/{siteId}/cameras/{cameraId}/counts` 
  to `/cameras/{cameraId}/counts` to match web dashboard
- **Status Updates:** Added heartbeat thread to update camera status every 60 seconds
- **FPS Tracking:** Added frame count and FPS calculation

---

## 📚 Full Documentation

See `RPI_FIREBASE_INTEGRATION_GUIDE.md` for:
- Detailed step-by-step instructions
- Troubleshooting guide
- Architecture overview
- Monitoring and maintenance

---

## 🆘 Quick Troubleshooting

**Camera not appearing in dashboard?**
```bash
# Check logs
sudo journalctl -u camera-agent -n 50

# Verify config
cat /opt/camera-agent/config/config.json

# Test Firebase connection
python3 -c "import firebase_admin; from firebase_admin import credentials; print('OK')"
```

**No counts appearing?**
- Wait 5 minutes (aggregation interval)
- Check detection model exists: `ls -la /opt/camera-agent/models/`
- Verify camera is detecting objects in logs

**Service account errors?**
- Verify file exists: `ls -la /opt/camera-agent/config/service-account.json`
- Check permissions: `sudo chmod 600 /opt/camera-agent/config/service-account.json`

---

**Ready to integrate? Start with Step 1 above!** 🚀




