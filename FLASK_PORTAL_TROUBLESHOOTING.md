# Flask Provisioning Portal Not Loading - Troubleshooting

## 🔍 Issue
The Flask provisioning portal at `http://192.168.4.1/?token=PT_XXXXX` is not loading.

## ✅ Solution Steps

### Step 1: Verify Flask Portal is Installed on RPi

SSH into your Raspberry Pi and check:

```bash
# Check if provisioning portal file exists
ls -la /opt/camera-agent/provisioning_portal.py

# Check if Flask is installed
pip3 list | grep -i flask
```

### Step 2: Install/Update Flask Portal

If missing or needs update, copy the updated `provisioning_portal.py`:

```bash
# On your Mac, copy to RPi
scp camera-system/provisioning_portal.py digioptics_od@CameraUnit.local:/tmp/

# On RPi
sudo mv /tmp/provisioning_portal.py /opt/camera-agent/
sudo chmod +x /opt/camera-agent/provisioning_portal.py
```

### Step 3: Install Flask Dependencies

```bash
sudo pip3 install flask flask-cors requests
```

### Step 4: Check Provisioning Portal Service

```bash
# Check if service exists
sudo systemctl status provisioning-portal

# If not running, start it
sudo systemctl start provisioning-portal
sudo systemctl enable provisioning-portal

# View logs
sudo journalctl -u provisioning-portal -f
```

### Step 5: Create Service File (if missing)

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

### Step 6: Verify Hotspot is Running

```bash
# Check WiFi hotspot status
iwconfig wlan0

# Should show: Mode:Master and SSID: AIOD-Camera-XXXX

# Check hotspot connection
nmcli connection show Hotspot
```

### Step 7: Test Portal Access

**On your phone (connected to camera WiFi):**

1. Open browser
2. Go to: `http://192.168.4.1`
3. Should see provisioning portal

**Test with token:**
1. Go to: `http://192.168.4.1/?token=PT_TEST123`
2. Token field should be pre-filled

### Step 8: Check Firewall/Port

```bash
# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Or
sudo ss -tlnp | grep :80

# Should show Python/Flask listening on 0.0.0.0:80
```

### Step 9: Manual Test (Run Flask Directly)

If service isn't working, test manually:

```bash
# Stop service
sudo systemctl stop provisioning-portal

# Run manually (requires root for port 80)
sudo python3 /opt/camera-agent/provisioning_portal.py

# Should see:
# PORTAL READY
# WiFi: AIOD-Camera-XXXX
# Password: aiod2024
# URL: http://192.168.4.1
```

## 🔧 Common Issues

### Issue: "Connection refused" or "Cannot reach page"

**Causes:**
- Flask server not running
- Wrong IP address
- Firewall blocking port 80
- Not connected to camera WiFi

**Fix:**
```bash
# Verify you're connected to camera WiFi
# SSID should be: AIOD-Camera-XXXX

# Check Flask is running
sudo systemctl status provisioning-portal

# Restart service
sudo systemctl restart provisioning-portal
```

### Issue: "Permission denied" on port 80

**Fix:**
```bash
# Run Flask on port 5000 instead (or use port forwarding)
# Edit provisioning_portal.py:
# Change: app.run(host='0.0.0.0', port=80, debug=False)
# To: app.run(host='0.0.0.0', port=5000, debug=False)

# Update QR code URL to: http://192.168.4.1:5000/?token=TOKEN
```

### Issue: Hotspot not created

**Fix:**
```bash
# Check NetworkManager
sudo systemctl status NetworkManager

# Manually create hotspot
sudo nmcli device wifi hotspot ssid AIOD-Camera-TEST password aiod2024
```

### Issue: Token not pre-filled in form

**Fix:**
- Updated `provisioning_portal.py` now handles token parameter
- JavaScript auto-fills token from URL
- Verify you're using the updated script

## 📝 Verification Checklist

- [ ] Flask installed: `pip3 list | grep flask`
- [ ] Portal file exists: `/opt/camera-agent/provisioning_portal.py`
- [ ] Service running: `sudo systemctl status provisioning-portal`
- [ ] Hotspot active: `iwconfig wlan0` shows Mode:Master
- [ ] Port 80 listening: `sudo netstat -tlnp | grep :80`
- [ ] Connected to camera WiFi on phone
- [ ] Can access: `http://192.168.4.1`
- [ ] Token pre-fills: `http://192.168.4.1/?token=TEST`

## 🚀 Quick Fix Script

Run on RPi:

```bash
#!/bin/bash
# Quick fix provisioning portal

echo "Installing Flask..."
sudo pip3 install flask flask-cors requests

echo "Starting provisioning portal service..."
sudo systemctl enable provisioning-portal
sudo systemctl start provisioning-portal

echo "Checking status..."
sudo systemctl status provisioning-portal --no-pager

echo "View logs:"
echo "sudo journalctl -u provisioning-portal -f"
```

---

**Last Updated:** December 28, 2024




