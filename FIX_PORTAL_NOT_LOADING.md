# Fix: Provisioning Portal Not Loading (http://192.168.4.1)

## 🔍 Problem

The Flask provisioning portal at `http://192.168.4.1/?token=PT_TEST123` is not loading.

## 🎯 Quick Diagnostic (Run on RPi)

**Copy and run this on the Raspberry Pi:**

```bash
# Download diagnostic script
curl -o /tmp/diagnose-portal.sh https://raw.githubusercontent.com/your-repo/diagnose-portal.sh
# OR copy the script manually

# Run diagnostic
chmod +x /tmp/diagnose-portal.sh
sudo /tmp/diagnose-portal.sh
```

## ✅ Step-by-Step Manual Fix

### Step 1: SSH into Raspberry Pi

```bash
ssh digioptics_od@ShawnRaspberryPi.local
# or
ssh pi@ShawnRaspberryPi.local
```

### Step 2: Check Flask Installation

```bash
python3 -c "import flask" && echo "Flask installed" || echo "Flask NOT installed"
```

**If not installed:**
```bash
sudo pip3 install flask flask-cors requests --break-system-packages
```

### Step 3: Check Portal File

```bash
ls -la /opt/camera-agent/provisioning_portal.py
```

**If missing, copy it:**
```bash
# Option A: Copy from Mac (if you can scp)
# From Mac:
scp camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/
# Then on RPi:
sudo mv /tmp/provisioning_portal.py /opt/camera-agent/
sudo chmod +x /opt/camera-agent/provisioning_portal.py
```

### Step 4: Check Config File (IMPORTANT!)

The portal **exits immediately** if config.json exists:

```bash
ls -la /opt/camera-agent/config.json
```

**If it exists and you want to test the portal:**
```bash
# Backup config temporarily
sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup
```

### Step 5: Check Service Status

```bash
sudo systemctl status provisioning-portal
```

**If service doesn't exist, create it:**
```bash
sudo tee /etc/systemd/system/provisioning-portal.service > /dev/null << 'EOF'
[Unit]
Description=Camera Provisioning Portal
After=network-online.target hostapd.service
Wants=network-online.target
ConditionPathExists=!/opt/camera-agent/config.json

[Service]
Type=simple
User=root
WorkingDirectory=/opt/camera-agent
ExecStart=/usr/bin/python3 /opt/camera-agent/provisioning_portal.py
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable provisioning-portal
sudo systemctl start provisioning-portal
```

### Step 6: Check Port 80

```bash
sudo netstat -tlnp | grep :80
# OR
sudo ss -tlnp | grep :80
```

**If nothing is on port 80, the portal isn't running.**

### Step 7: Test Portal Manually

```bash
# Stop service first
sudo systemctl stop provisioning-portal

# Run manually to see errors
sudo python3 /opt/camera-agent/provisioning_portal.py
```

**What you should see:**
```
==========================================
CAMERA PROVISIONING PORTAL
==========================================
Hostname: ShawnRaspberryPi
MAC: B8:27:EB:XX:XX:XX
Hotspot: AIOD-Camera-XXXXX
Password: aiod2024
==========================================
PORTAL READY
Access at: http://192.168.4.1
==========================================
 * Running on http://0.0.0.0:80
```

**If you see errors, they will tell you what's wrong.**

### Step 8: Check WiFi Hotspot

The portal only works when connected to the camera's WiFi:

```bash
# Check if hotspot is active
iwconfig wlan0 | grep Mode
sudo systemctl status hostapd
```

**If hotspot isn't running:**
```bash
sudo systemctl start hostapd
sudo systemctl enable hostapd
```

## 🔧 Common Issues & Solutions

### Issue 1: Portal Exits Immediately

**Cause:** `config.json` exists

**Solution:**
```bash
sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup
sudo systemctl restart provisioning-portal
```

### Issue 2: "This site can't be reached"

**Causes:**
- Flask server not running
- Wrong IP address
- Not connected to camera WiFi

**Solutions:**
1. Check service: `sudo systemctl status provisioning-portal`
2. Check IP: `hostname -I` (should show 192.168.4.1 when hotspot is active)
3. Verify WiFi connection (connect to AIOD-Camera-XXXXX)

### Issue 3: Port 80 Permission Denied

**Cause:** Port 80 requires root privileges

**Solution:** Portal must run as root (via systemd service)

### Issue 4: Flask Not Found

**Cause:** Flask not installed

**Solution:**
```bash
sudo pip3 install flask flask-cors requests --break-system-packages
```

### Issue 5: Portal File Missing

**Cause:** File not copied to RPi

**Solution:**
```bash
# Create file manually or copy from Mac
sudo nano /opt/camera-agent/provisioning_portal.py
# Paste contents from camera-system/provisioning_portal.py
sudo chmod +x /opt/camera-agent/provisioning_portal.py
```

## 🧪 Test from Phone

1. **Connect to camera WiFi:**
   - SSID: `AIOD-Camera-XXXXX` (where XXXXX is last 5 chars of MAC)
   - Password: `aiod2024`

2. **Open browser:**
   - Go to: `http://192.168.4.1/?token=PT_TEST123`
   - Should see provisioning portal page

3. **If still not working:**
   - Check phone is on camera WiFi (not your regular WiFi)
   - Try `http://192.168.4.1` (without token)
   - Check phone can ping: `ping 192.168.4.1` (from terminal app)

## 📋 Complete Diagnostic Command

Run this on the RPi to check everything at once:

```bash
echo "=== CHECK 1: Flask ===" && \
python3 -c "import flask" 2>&1 && echo "✓ Flask OK" || echo "✗ Install: sudo pip3 install flask flask-cors requests --break-system-packages" && \
echo "" && \
echo "=== CHECK 2: Portal File ===" && \
[ -f /opt/camera-agent/provisioning_portal.py ] && echo "✓ File exists" || echo "✗ File missing" && \
echo "" && \
echo "=== CHECK 3: Config ===" && \
[ -f /opt/camera-agent/config.json ] && echo "⚠ Config exists (portal won't run)" || echo "✓ No config (portal can run)" && \
echo "" && \
echo "=== CHECK 4: Port 80 ===" && \
(sudo netstat -tlnp 2>/dev/null | grep :80 || sudo ss -tlnp 2>/dev/null | grep :80 || echo "✗ Nothing on port 80") && \
echo "" && \
echo "=== CHECK 5: Service ===" && \
sudo systemctl status provisioning-portal --no-pager -l 2>&1 | head -10 && \
echo "" && \
echo "=== CHECK 6: WiFi Hotspot ===" && \
iwconfig wlan0 2>/dev/null | grep Mode || echo "✗ No hotspot"
```

## 🚀 Quick Fix Script

If you can't SSH, you can create a fix script directly on the RPi:

```bash
# On RPi, create and run:
cat > /tmp/fix-portal.sh << 'FIX_EOF'
#!/bin/bash
sudo pip3 install flask flask-cors requests --break-system-packages
sudo mkdir -p /opt/camera-agent
sudo mkdir -p /var/log/camera-agent
sudo chmod +x /opt/camera-agent/provisioning_portal.py
sudo systemctl daemon-reload
sudo systemctl restart provisioning-portal
sudo systemctl status provisioning-portal
FIX_EOF

chmod +x /tmp/fix-portal.sh
sudo /tmp/fix-portal.sh
```

## 📞 Still Not Working?

1. **Run manual test:**
   ```bash
   sudo python3 /opt/camera-agent/provisioning_portal.py
   ```
   Share the output/errors you see.

2. **Check logs:**
   ```bash
   sudo journalctl -u provisioning-portal -n 50
   ```

3. **Verify all files:**
   ```bash
   ls -la /opt/camera-agent/
   ```

4. **Test from RPi itself:**
   ```bash
   curl http://localhost
   # Should return HTML
   ```

---

**Remember:** The portal only runs when `config.json` doesn't exist. This is by design - once configured, the portal shouldn't run.


