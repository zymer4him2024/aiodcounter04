# New Activation Flow - WiFi First, Then Activation

## Overview

The provisioning portal now has a **two-step process**:
1. **Step 1**: Configure site WiFi connection (so RPi has internet)
2. **Step 2**: Activate camera with provisioning token

## New Flow

### 1. Installer connects to RPi hotspot
- WiFi: `AIOD-Camera-{hostname}`
- Password: `aiod2024`
- Portal accessible at: `http://192.168.4.1`

### 2. Installer enters site WiFi credentials
- Portal shows WiFi configuration form
- Installer enters:
  - Site WiFi SSID
  - Site WiFi Password
- Clicks "Connect to WiFi"

### 3. Portal connects RPi to site WiFi
- RPi disables hotspot
- RPi connects to site WiFi (gets internet access)
- Portal continues running on new WiFi IP

### 4. Portal shows new IP address
- Displays new IP (e.g., `192.168.1.100`)
- Shows instructions:
  - Disconnect from camera hotspot
  - Connect phone to site WiFi
  - Open browser to new IP address

### 5. Installer reconnects phone to site WiFi
- Phone disconnects from camera hotspot
- Phone connects to site WiFi (has internet)

### 6. Installer accesses portal on site WiFi
- Opens browser to new IP (e.g., `http://192.168.1.100`)
- Portal shows activation form
- Or scans QR code (which will work if RPi is on site WiFi)

### 7. Installer activates camera
- Enters provisioning token (or scans QR code)
- Clicks "Activate Camera"
- RPi calls Firebase (has internet now!)
- Camera is activated and starts counting

## Technical Details

### Portal Endpoints

- `GET /` - Main portal page (shows WiFi config or activation based on WiFi status)
- `GET /wifi-status` - Check if RPi is connected to WiFi (not hotspot)
- `POST /configure-wifi` - Connect RPi to site WiFi
- `GET /token-info?token=PT_XXX` - Get token information from Firebase
- `POST /activate` - Activate camera with token

### WiFi Connection Process

1. Portal receives WiFi credentials
2. Disables hotspot connection
3. Creates/updates WiFi connection profile
4. Connects to site WiFi
5. Portal continues running (binds to all interfaces, so accessible on new IP)
6. Returns new IP address to installer

### Portal Lifecycle

- **Starts**: When `config.json` doesn't exist (camera not activated)
- **Stops**: After successful activation (when `config.json` is created)
- **Runs during**: Hotspot mode → WiFi mode transition (remains accessible)

## Deployment

### Update Portal on RPi

```bash
# From Mac terminal
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04
./deploy-to-rpi.sh
```

This will deploy:
- Updated `provisioning_portal.py` with WiFi-first flow
- Updated `camera_agent.py` with counting fixes
- Other necessary files

### After Deployment

```bash
# On RPi, restart portal
sudo systemctl restart provisioning-portal

# Check status
sudo systemctl status provisioning-portal
```

## Testing the New Flow

1. **Start with no config** (portal should start):
   ```bash
   # Backup config if exists
   sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup
   sudo systemctl start provisioning-portal
   ```

2. **Connect phone to hotspot**: `AIOD-Camera-XXXX`

3. **Access portal**: `http://192.168.4.1`

4. **Configure WiFi**:
   - Enter site WiFi SSID and password
   - Click "Connect to WiFi"
   - Note the new IP address shown

5. **Reconnect phone**:
   - Disconnect from camera hotspot
   - Connect to site WiFi
   - Open browser to new IP

6. **Activate camera**:
   - Enter token or scan QR code
   - Click "Activate Camera"
   - Camera should activate successfully

## Benefits

✅ **RPi has internet** during activation (can reach Firebase)  
✅ **No more network errors** during activation  
✅ **Works in WiFi-only sites** (no Ethernet needed)  
✅ **Clear step-by-step** instructions for installer  
✅ **Portal remains accessible** during WiFi transition  

## Troubleshooting

### WiFi connection fails
- Check SSID and password are correct
- Check site WiFi is in range
- Check RPi WiFi adapter is working: `iwconfig wlan0`

### Portal not accessible after WiFi connection
- Note the IP address shown before reconnecting
- Try accessing portal at that IP
- Check if portal is still running: `sudo systemctl status provisioning-portal`

### Activation fails after WiFi connection
- Check RPi has internet: `ping -c 3 8.8.8.8`
- Check Firebase is reachable: `curl -I https://us-central1-aiodcouter04.cloudfunctions.net`
- Check portal logs: `sudo journalctl -u provisioning-portal -f`

