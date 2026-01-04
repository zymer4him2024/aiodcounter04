# WiFi Connection Fix After Camera Activation

## Problem
After camera activation, the RPi stays in hotspot mode and doesn't reconnect to normal WiFi, preventing it from reaching Firebase.

## Solution
Updated `provisioning_portal.py` to:
1. **After activation**: Automatically disable hotspot
2. **Reconnect to WiFi**: Try to reconnect to any previously saved WiFi connections
3. **Logging**: Added detailed logging to track the WiFi switching process

## Changes Made

### 1. Automatic WiFi Reconnection After Activation
- Disables hotspot connection after successful activation
- Scans for saved WiFi connections (excluding hotspot)
- Automatically reconnects to the first available saved WiFi network
- Logs warnings if no WiFi networks are found

### 2. Enhanced Logging
- Added file logging to `/var/log/camera-agent/provisioning.log`
- Logs all activation steps for troubleshooting
- Logs WiFi switching attempts and results

## Deployment

### Deploy Updated Portal
```bash
# From your Mac
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04
./deploy-to-rpi.sh
```

### Or Manual Update
```bash
# SSH to RPi
ssh digioptics_od@ShawnRaspberryPi.local

# Backup current portal
sudo cp /opt/camera-agent/provisioning_portal.py /opt/camera-agent/provisioning_portal.py.backup

# Copy new portal (from Mac, run this command)
# scp camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/
# Then on RPi:
# sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py

# Restart portal
sudo systemctl restart provisioning-portal
```

## Important: Configure WiFi Before Activation

**For the automatic reconnection to work, you must configure WiFi on the RPi BEFORE activation:**

### Option 1: Configure WiFi via SSH (Recommended)
```bash
# SSH to RPi (use Ethernet or serial if needed)
ssh digioptics_od@ShawnRaspberryPi.local

# List available WiFi networks
nmcli device wifi list

# Connect to a WiFi network
sudo nmcli device wifi connect "YOUR_WIFI_SSID" password "YOUR_WIFI_PASSWORD"

# Verify connection
nmcli connection show --active
```

### Option 2: Configure WiFi via Raspberry Pi Imager (Before First Boot)
- Use Raspberry Pi Imager's advanced options
- Set WiFi credentials before writing the image

### Option 3: Use raspi-config (On RPi)
```bash
sudo raspi-config
# Navigate to: System Options > Wireless LAN
# Enter SSID and password
```

## Verification After Activation

### 1. Check WiFi Connection
```bash
# SSH to RPi
ssh digioptics_od@ShawnRaspberryPi.local

# Check active connections
nmcli connection show --active

# Check if connected to WiFi (should NOT show Hotspot)
nmcli device status
```

### 2. Check Logs
```bash
# View provisioning portal logs
sudo journalctl -u provisioning-portal -n 50

# View detailed provisioning log
sudo tail -f /var/log/camera-agent/provisioning.log
```

### 3. Test Internet Connectivity
```bash
# Test if RPi can reach internet
ping -c 3 8.8.8.8

# Test if RPi can reach Firebase
curl -I https://us-central1-aiodcouter04.cloudfunctions.net
```

### 4. Check Camera Agent Status
```bash
# Check if camera agent is running
sudo systemctl status camera-agent

# View camera agent logs
sudo journalctl -u camera-agent -f
```

## Expected Behavior

### During Activation:
1. ✅ Portal accessible at `http://192.168.4.1` (hotspot mode)
2. ✅ User enters provisioning token
3. ✅ Token validated and config saved
4. ✅ Camera agent service starts

### After Activation:
1. ✅ Hotspot disabled
2. ✅ RPi reconnects to saved WiFi network
3. ✅ Portal service stops
4. ✅ Camera agent can reach Firebase
5. ✅ Counting data uploaded successfully

## Troubleshooting

### Issue: RPi Doesn't Reconnect to WiFi After Activation

**Check:**
```bash
# 1. Are there any saved WiFi connections?
nmcli connection show

# 2. Check provisioning logs
sudo tail -50 /var/log/camera-agent/provisioning.log

# 3. Manually reconnect WiFi
sudo nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
```

### Issue: No Saved WiFi Connections

**Solution:** Configure WiFi BEFORE activation using one of the methods above.

### Issue: RPi Stays in Hotspot Mode

**Manual Fix:**
```bash
# Disable hotspot
sudo nmcli con down Hotspot

# Connect to WiFi manually
sudo nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"

# Verify connection
nmcli connection show --active
```

### Issue: Camera Agent Can't Reach Firebase

**Check:**
```bash
# 1. Verify internet connectivity
ping -c 3 8.8.8.8

# 2. Check camera agent logs
sudo journalctl -u camera-agent -n 50 | grep -i firebase

# 3. Test Firebase connection
curl -I https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera
```

## Next Steps

1. **Configure WiFi** on RPi before first activation
2. **Deploy updated portal** using `deploy-to-rpi.sh`
3. **Test activation** - WiFi should reconnect automatically
4. **Verify** camera agent can upload data to Firebase

## Notes

- The portal will attempt to reconnect to **any** saved WiFi connection (first one found)
- If no WiFi is configured, the RPi will remain offline and camera agent won't be able to upload data
- WiFi configuration can be done anytime via `nmcli` or `raspi-config`
- After activation, you can SSH to the RPi using its WiFi IP address instead of hotspot


