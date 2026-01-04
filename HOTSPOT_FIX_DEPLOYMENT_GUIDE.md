# Hotspot Fix Deployment Guide

## Problem: RPi Not Reachable via SSH

If you're getting "Operation timed out" when trying to deploy the hotspot fix, the RPi is likely:
- In hotspot mode (192.168.4.1) and not connected to your WiFi
- Not powered on
- On a different network
- SSH service not running

## Solution Options

### Option 1: Deploy via Hotspot Connection (Recommended)

If the RPi is in hotspot mode:

1. **Connect your Mac to the RPi hotspot:**
   - WiFi SSID: `AIOD-Camera-XXXXX` (check your phone/device for exact name)
   - Password: `aiod2024`

2. **Run the hotspot deployment script:**
   ```bash
   ./deploy-hotspot-fix-via-hotspot.sh
   ```

   This script will:
   - Detect if RPi is reachable via hotspot (192.168.4.1)
   - Copy the fix script
   - Run it remotely

### Option 2: Manual Deployment via USB

If SSH is not available at all:

1. **Copy script to USB drive:**
   ```bash
   cp camera-system/fix-hotspot.sh /Volumes/USB_DRIVE/
   ```

2. **Insert USB into RPi**

3. **On RPi (via serial console or direct access):**
   ```bash
   sudo bash /media/usb/fix-hotspot.sh
   ```

### Option 3: Manual Script Copy

1. **Generate script content:**
   ```bash
   ./deploy-hotspot-fix-manual.sh > fix-script.txt
   ```

2. **Copy script content to RPi:**
   - Via serial console
   - Via USB
   - Via any available method

3. **On RPi:**
   ```bash
   sudo nano /tmp/fix-hotspot.sh
   # Paste content, save (Ctrl+X, Y, Enter)
   sudo bash /tmp/fix-hotspot.sh
   ```

### Option 4: Direct SSH (If RPi is on WiFi)

If the RPi is connected to your WiFi network:

1. **Find RPi IP:**
   ```bash
   # Check your router's connected devices
   # Or scan network:
   nmap -sn 192.168.0.0/24 | grep -i raspberry
   ```

2. **SSH directly:**
   ```bash
   ssh digioptics_od@<RPI_IP>
   ```

3. **Copy script manually:**
   ```bash
   # On Mac, create a simple copy command:
   cat camera-system/fix-hotspot.sh | ssh digioptics_od@<RPI_IP> "cat > /tmp/fix-hotspot.sh"
   
   # Then on RPi:
   sudo bash /tmp/fix-hotspot.sh
   ```

## Quick Fix Commands (If You Can Access RPi)

If you can get any kind of access to the RPi (SSH, serial, direct), run these commands:

```bash
# 1. Ensure NetworkManager is running
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager

# 2. Clean up old hotspot
sudo nmcli con down "Hotspot" 2>/dev/null || true
sudo nmcli con delete "Hotspot" 2>/dev/null || true

# 3. Create hotspot
HOSTNAME_SHORT=$(hostname | cut -c1-15)
sudo nmcli device wifi hotspot ssid "AIOD-Camera-${HOSTNAME_SHORT}" password aiod2024 ifname wlan0 con-name Hotspot

# 4. Configure for shared mode
sudo nmcli connection modify Hotspot ipv4.method shared ipv4.addresses 192.168.4.1/24

# 5. Activate hotspot
sudo nmcli connection up Hotspot
sleep 3

# 6. Force IP address
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.4.1/24 dev wlan0

# 7. Restart portal
sudo fuser -k 80/tcp 2>/dev/null || true
sudo systemctl restart provisioning-portal
```

## Verification

After running the fix, verify:

```bash
# Check IP address
ip addr show wlan0 | grep "192.168.4.1"

# Check hotspot is active
nmcli connection show --active | grep Hotspot

# Check portal is running
sudo systemctl status provisioning-portal

# Test portal
curl http://localhost
```

## Troubleshooting

### Still Can't Reach RPi?

1. **Check if RPi is powered on:**
   - Check power LED
   - Check if it's responding to ping (if you know the IP)

2. **Try serial console:**
   - Connect via USB-to-serial adapter
   - Use screen/minicom to access console

3. **Check network:**
   - Ensure your Mac and RPi are on the same network
   - Try connecting Mac to RPi hotspot manually

4. **Physical access:**
   - Connect monitor and keyboard directly to RPi
   - Run fix script locally

### Hotspot Still Not Working After Fix?

1. **Check logs:**
   ```bash
   sudo journalctl -u provisioning-portal -n 50
   ```

2. **Check NetworkManager:**
   ```bash
   sudo systemctl status NetworkManager
   ```

3. **Manual hotspot creation:**
   ```bash
   sudo nmcli device wifi hotspot ssid "AIOD-Camera-Test" password aiod2024 ifname wlan0
   sudo ip addr add 192.168.4.1/24 dev wlan0
   ```

## Files Available

- `deploy-hotspot-fix.sh` - Standard deployment (requires WiFi connection)
- `deploy-hotspot-fix-via-hotspot.sh` - Deployment via hotspot connection
- `deploy-hotspot-fix-manual.sh` - Manual deployment instructions
- `camera-system/fix-hotspot.sh` - The actual fix script

