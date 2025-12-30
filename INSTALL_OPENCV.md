# Install OpenCV on Raspberry Pi

OpenCV (cv2) is required for the camera agent to capture video from USB cameras.

## Quick Install

**Option 1: Run the automated install script** (recommended)

From your Mac, copy and run:
```bash
# Copy install script to RPi
scp camera-system/install-opencv-rpi.sh digioptics_od@ShawnRaspberryPi.local:/tmp/

# SSH into RPi and run it
ssh digioptics_od@ShawnRaspberryPi.local
chmod +x /tmp/install-opencv-rpi.sh
sudo /tmp/install-opencv-rpi.sh
```

**Option 2: Manual installation**

SSH into your RPi and run:
```bash
# Update package list
sudo apt-get update

# Install OpenCV (system package - faster on RPi)
sudo apt-get install -y python3-opencv

# Or install via pip (if system package doesn't work)
sudo pip3 install --break-system-packages opencv-python-headless

# Verify installation
python3 -c "import cv2; print('OpenCV version:', cv2.__version__)"
```

## Verify Camera Works

After installing OpenCV, test the camera:
```bash
python3 -c "import cv2; cap = cv2.VideoCapture(0); print('Camera opened:', cap.isOpened()); ret, frame = cap.read(); print('Frame captured:', ret); print('Resolution:', frame.shape if ret else 'N/A'); cap.release()"
```

## Then Start Object Detection

Once OpenCV is installed, run the startup script again:
```bash
sudo /tmp/start-od-with-usb-camera.sh
```

