# Update Provisioning Portal on RPi - Instructions

## Option 1: From Your Mac Terminal (Recommended)

```bash
# 1. From your Mac terminal
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04

# 2. Copy portal file to RPi
scp camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/

# 3. SSH to RPi and move file
ssh digioptics_od@ShawnRaspberryPi.local
sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py
sudo chmod +x /opt/camera-agent/provisioning_portal.py
sudo systemctl daemon-reload
sudo systemctl restart provisioning-portal
```

## Option 2: Direct Commands on RPi

If you're already on the RPi, run these commands:

```bash
# 1. Backup current portal
sudo cp /opt/camera-agent/provisioning_portal.py /opt/camera-agent/provisioning_portal.py.backup

# 2. The file needs to be copied from Mac first via scp (see Option 1)
# OR create it manually using nano (see Option 3)
```

## Option 3: Copy File Content Directly (If scp doesn't work)

If you can't use scp, you can create the file directly on the RPi by copying the content:

```bash
# On RPi, backup current file
sudo cp /opt/camera-agent/provisioning_portal.py /opt/camera-agent/provisioning_portal.py.backup

# Create new file
sudo nano /opt/camera-agent/provisioning_portal.py

# Then copy the entire content from camera-system/provisioning_portal.py
# Paste it into nano, save (Ctrl+X, Y, Enter)

# Make executable
sudo chmod +x /opt/camera-agent/provisioning_portal.py

# Restart portal
sudo systemctl daemon-reload
sudo systemctl restart provisioning-portal
```

## Verify Update

After updating, check:

```bash
# Check portal is running
sudo systemctl status provisioning-portal

# Check portal logs
sudo journalctl -u provisioning-portal -n 20

# Test portal in browser
# Connect to hotspot and go to http://192.168.4.1
# You should see "Step 1: Connect to Site WiFi"
```


