# Raspberry Pi Hotspot Fix

This directory contains scripts to fix common hotspot issues on the Raspberry Pi.

## Quick Fix

### Option 1: Deploy from Mac (Recommended)

From your Mac, run:

```bash
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04
./deploy-hotspot-fix.sh
```

This will:
1. Copy the fix script to the RPi
2. Make it executable
3. Run it with sudo privileges

### Option 2: Manual Fix on RPi

SSH into the RPi and run:

```bash
# Copy script to RPi first (from Mac):
scp camera-system/fix-hotspot.sh digioptics_od@192.168.0.214:/tmp/

# Then on RPi:
ssh digioptics_od@192.168.0.214
sudo bash /tmp/fix-hotspot.sh
```

## What the Fix Does

The `fix-hotspot.sh` script:

1. **Ensures NetworkManager is running** - Required for hotspot management
2. **Cleans up old connections** - Removes conflicting hotspot configurations
3. **Creates new hotspot** - Sets up hotspot with proper SSID (AIOD-Camera-XXXXX)
4. **Configures shared mode** - Enables DHCP for connected devices
5. **Forces IP address** - Sets wlan0 to 192.168.4.1 (critical step)
6. **Restarts portal** - Ensures provisioning portal is running on port 80
7. **Verifies setup** - Checks all components are working

## Common Issues Fixed

### Issue 1: IP Address Not 192.168.4.1
**Symptom:** Portal not accessible at http://192.168.4.1

**Fix:** The script forces the IP address using both `ip` and `ifconfig` commands.

### Issue 2: NetworkManager Conflicts
**Symptom:** Hotspot won't start or keeps disconnecting

**Fix:** Script stops conflicting services (dnsmasq) and ensures NetworkManager is running.

### Issue 3: Portal Not Running
**Symptom:** Can't access portal even when connected to hotspot

**Fix:** Script kills any process on port 80 and restarts the provisioning-portal service.

### Issue 4: Hotspot Not Visible
**Symptom:** Can't see hotspot WiFi network

**Fix:** Script recreates the hotspot with proper configuration.

## Verification

After running the fix, verify:

```bash
# On RPi, check:
ip addr show wlan0 | grep "192.168.4.1"
nmcli connection show --active | grep Hotspot
curl http://localhost
sudo systemctl status provisioning-portal
```

**From your phone:**
1. Connect to WiFi: `AIOD-Camera-XXXXX`
2. Password: `aiod2024`
3. Open browser: `http://192.168.4.1`

## Updated Provisioning Portal

The `provisioning_portal.py` has been updated to:

- Automatically create hotspot if it doesn't exist
- Configure hotspot for shared mode (DHCP)
- Force IP address to 192.168.4.1 on startup
- Better error handling and logging
- Check for port conflicts before starting

## Troubleshooting

### Hotspot Still Not Working

1. **Check NetworkManager:**
   ```bash
   sudo systemctl status NetworkManager
   ```

2. **Check wlan0 interface:**
   ```bash
   ip addr show wlan0
   ```

3. **Check portal logs:**
   ```bash
   sudo journalctl -u provisioning-portal -n 50
   ```

4. **Manual hotspot creation:**
   ```bash
   sudo nmcli device wifi hotspot ssid "AIOD-Camera-Test" password aiod2024 ifname wlan0
   sudo ip addr add 192.168.4.1/24 dev wlan0
   ```

### Portal Not Accessible

1. **Check if portal is running:**
   ```bash
   sudo systemctl status provisioning-portal
   ```

2. **Check port 80:**
   ```bash
   sudo netstat -tlnp | grep :80
   ```

3. **Kill conflicting processes:**
   ```bash
   sudo fuser -k 80/tcp
   sudo systemctl restart provisioning-portal
   ```

### WiFi Conflicts

If the RPi is connected to WiFi, it may conflict with hotspot mode:

```bash
# Disconnect from WiFi
sudo nmcli con down "Your-WiFi-Connection"

# Then activate hotspot
sudo nmcli con up Hotspot
```

## Files

- `fix-hotspot.sh` - Main fix script (run on RPi)
- `deploy-hotspot-fix.sh` - Deployment script (run from Mac)
- `provisioning_portal.py` - Updated portal with better hotspot handling

