# Setup Provisioning Portal on Raspberry Pi

## ⚠️ Important: Run these commands from your Mac, NOT on the RPi

Since you're currently SSH'd into the RPi, you have two options:

---

## Option 1: Exit RPi and Run from Mac (Recommended)

1. **Exit the RPi:**
   ```bash
   exit
   ```

2. **From your Mac, run the update script:**
   ```bash
   cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04
   ./update-flask-portal.sh
   ```

---

## Option 2: Copy File Directly on RPi

If you want to stay on the RPi, create the file directly:

```bash
# On RPi, create the file
sudo nano /opt/camera-agent/provisioning_portal.py

# Copy and paste the entire contents from:
# camera-system/provisioning_portal.py
# Then save (Ctrl+X, Y, Enter)

sudo chmod +x /opt/camera-agent/provisioning_portal.py
```

---

## Option 3: Manual Copy from Mac

**Exit the RPi first:**
```bash
exit
```

**Then from your Mac terminal:**
```bash
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04

# Copy file to RPi
scp camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/

# SSH into RPi and move it
ssh digioptics_od@ShawnRaspberryPi.local
sudo mv /tmp/provisioning_portal.py /opt/camera-agent/
sudo chmod +x /opt/camera-agent/provisioning_portal.py
```

---

## After Copying: Setup Service on RPi

Once the file is copied, on the RPi:

```bash
# 1. Install Flask dependencies
sudo pip3 install flask flask-cors requests --break-system-packages

# 2. Create service file
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

# 3. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable provisioning-portal
sudo systemctl start provisioning-portal

# 4. Check status
sudo systemctl status provisioning-portal

# 5. View logs
sudo journalctl -u provisioning-portal -f
```

---

## Verify It's Working

```bash
# Check service is running
sudo systemctl status provisioning-portal

# Check port 80 is listening
sudo netstat -tlnp | grep :80

# Test from phone (connected to camera WiFi):
# Open browser: http://192.168.4.1
# Should see provisioning portal
```

---

**Note:** The correct hostname is `ShawnRaspberryPi.local` (not `CameraUnit.local`)



