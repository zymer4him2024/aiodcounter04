# Start Object Detection with USB Camera on Raspberry Pi

## Quick Start

SSH into your Raspberry Pi and run these commands:

### Option 1: Run Commands Directly

```bash
# 1. SSH into RPi
ssh digioptics_od@ShawnRaspberryPi.local

# 2. Check USB camera is detected
ls -la /dev/video*

# 3. Test camera with OpenCV
python3 -c "import cv2; cap = cv2.VideoCapture(0); print('Camera opened:', cap.isOpened()); ret, frame = cap.read(); print('Frame captured:', ret, 'Size:', frame.shape if ret else 'N/A'); cap.release()"

# 4. Check configuration exists
ls -la /opt/camera-agent/config.json

# 5. Start the camera-agent service
sudo systemctl start camera-agent
sudo systemctl enable camera-agent

# 6. Check service status
sudo systemctl status camera-agent

# 7. Monitor logs in real-time
sudo journalctl -u camera-agent -f
```

### Option 2: Use the Automated Script

1. **Copy the script to RPi** (from your Mac):
```bash
scp camera-system/start-od-with-usb-camera.sh digioptics_od@ShawnRaspberryPi.local:/tmp/
```

2. **On the RPi, run the script**:
```bash
chmod +x /tmp/start-od-with-usb-camera.sh
sudo /tmp/start-od-with-usb-camera.sh
```

## What to Expect

When the service starts successfully, you should see in the logs:

```
Video capture started
Detection thread started
Counting thread started
Upload thread started
Status update thread started
Camera agent started successfully
```

## Troubleshooting

### Camera not detected
- Check USB connection: `lsusb`
- Verify camera appears: `ls -la /dev/video*`
- Try different USB port

### Service fails to start
- Check logs: `sudo journalctl -u camera-agent -n 50`
- Verify config exists: `sudo cat /opt/camera-agent/config.json`
- Check Python dependencies: `python3 -c "import cv2, tflite_runtime"`

### No detections
- Verify model file exists: `ls -la /opt/camera-agent/models/*.tflite`
- Check camera is capturing: Look for "Video capture started" in logs
- Verify object classes in config match model

### Service keeps restarting
- Check detailed error: `sudo journalctl -u camera-agent -n 100 --no-pager`
- Verify Firebase credentials: `ls -la /opt/camera-agent/*.json`
- Check disk space: `df -h`

## Verify Object Detection is Working

1. **Check logs for detection messages**:
```bash
sudo journalctl -u camera-agent | grep -i "detection\|count\|aggregated"
```

2. **Check Firebase dashboard**:
   - Go to https://aiodcounter04-superadmin.web.app
   - Navigate to the camera
   - Check if counts are appearing

3. **Monitor FPS and frame count**:
```bash
sudo journalctl -u camera-agent -f | grep -E "fps|frame|FPS"
```

## Stop the Service

```bash
sudo systemctl stop camera-agent
```

## Restart the Service

```bash
sudo systemctl restart camera-agent
```


