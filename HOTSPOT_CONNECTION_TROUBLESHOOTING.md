# Hotspot Connection Troubleshooting Guide

## Current Status

✅ **Hotspot is ACTIVE**
- SSID: `AIOD-Camera-ShawnRaspberryP`
- Password: `aiod2024`
- IP: `192.168.4.1`
- Mode: AP (Access Point)

## If Phone Can't Connect

### Step 1: Verify Phone Can See the Hotspot

1. **On your phone:**
   - Go to WiFi settings
   - Refresh the WiFi list
   - Look for: `AIOD-Camera-ShawnRaspberryP`
   - If you don't see it, try:
     - Move closer to the RPi (within 10-20 feet)
     - Wait 30 seconds and refresh again
     - Turn phone WiFi off and on
     - Restart phone WiFi

### Step 2: Connection Issues

If you can see the hotspot but can't connect:

1. **Forget and reconnect:**
   - On phone: Settings → WiFi
   - Long-press on `AIOD-Camera-ShawnRaspberryP`
   - Select "Forget" or "Remove"
   - Try connecting again

2. **Check password:**
   - Password is exactly: `aiod2024` (lowercase, no spaces)
   - Make sure caps lock is off

3. **Try manual connection:**
   - Select the network
   - Enter password: `aiod2024`
   - If it says "Saved" but not connected, try:
     - Turn WiFi off and on
     - Forget and reconnect

### Step 3: RPi Side Checks

Run these commands on RPi to verify:

```bash
# Check hotspot is active
nmcli connection show --active | grep Hotspot

# Check password
sudo nmcli dev wifi show-password

# Check IP address
ip addr show wlan0 | grep "192.168.4.1"

# Restart hotspot
sudo nmcli connection down Hotspot
sudo nmcli connection up Hotspot
```

### Step 4: Alternative Connection Methods

If WiFi hotspot still doesn't work:

1. **Use Ethernet + WiFi:**
   - RPi is connected via Ethernet (192.168.0.213)
   - You can access portal via Ethernet IP if on same network
   - Or use USB tethering from phone

2. **Direct IP access:**
   - If phone and RPi are on same WiFi network
   - Access portal at: `http://192.168.0.213`

3. **USB connection:**
   - Connect phone via USB
   - Enable USB tethering
   - Access RPi via USB network

## Common Issues

### Issue: Hotspot Not Visible

**Causes:**
- WiFi adapter doesn't support AP mode
- NetworkManager configuration issue
- WiFi adapter disabled or not working

**Fix:**
```bash
# Check WiFi adapter
lsusb | grep -i wifi
ip link show wlan0

# Restart NetworkManager
sudo systemctl restart NetworkManager
sudo nmcli connection up Hotspot
```

### Issue: Can See But Can't Connect

**Causes:**
- Wrong password
- Phone compatibility issue
- NetworkManager DHCP issue

**Fix:**
```bash
# Verify password
sudo nmcli dev wifi show-password

# Recreate hotspot with explicit settings
sudo nmcli con delete Hotspot
sudo nmcli device wifi hotspot ssid "AIOD-Camera-$(hostname | cut -c1-15)" password aiod2024 ifname wlan0
sudo nmcli connection modify Hotspot 802-11-wireless.band bg 802-11-wireless.channel 6
sudo nmcli connection up Hotspot
```

### Issue: Connects But No Internet/Portal

**Causes:**
- Portal not running
- IP address wrong
- Firewall blocking

**Fix:**
```bash
# Check portal
sudo systemctl status provisioning-portal
curl http://192.168.4.1

# Restart portal
sudo systemctl restart provisioning-portal
```

## Quick Fix Script

Run this on RPi to fix common issues:

```bash
#!/bin/bash
# Quick hotspot fix
sudo systemctl restart NetworkManager
sleep 3
sudo nmcli con down Hotspot 2>/dev/null
sudo nmcli con delete Hotspot 2>/dev/null
HOSTNAME_SHORT=$(hostname | cut -c1-15)
sudo nmcli device wifi hotspot ssid "AIOD-Camera-${HOSTNAME_SHORT}" password aiod2024 ifname wlan0 con-name Hotspot
sudo nmcli connection modify Hotspot 802-11-wireless.band bg ipv4.method shared ipv4.addresses 192.168.4.1/24
sudo nmcli connection up Hotspot
sleep 5
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.4.1/24 dev wlan0
echo "Hotspot: AIOD-Camera-${HOSTNAME_SHORT}"
echo "Password: aiod2024"
echo "IP: 192.168.4.1"
```

## Verification

After fixes, verify:

1. **Hotspot visible on phone** ✅
2. **Can connect with password** ✅
3. **Can access http://192.168.4.1** ✅
4. **Portal loads correctly** ✅

## Still Not Working?

If hotspot still doesn't work after all fixes:

1. **Check WiFi adapter model:**
   ```bash
   lsusb
   dmesg | grep -i wifi
   ```

2. **Try different WiFi adapter** (if USB WiFi dongle)

3. **Use Ethernet connection** instead:
   - Connect phone to same network as RPi
   - Access portal at RPi's Ethernet IP

4. **Check RPi logs:**
   ```bash
   sudo journalctl -u NetworkManager -n 50
   sudo dmesg | tail -50
   ```

