# Install TensorFlow Lite Runtime on Raspberry Pi

The camera agent requires `tflite_runtime` to run object detection models.

## Quick Install

**From your Mac, copy and run:**

```bash
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04

# Copy install script to RPi
scp camera-system/install-tflite-rpi.sh digioptics_od@ShawnRaspberryPi.local:/tmp/

# SSH into RPi and run it
ssh digioptics_od@ShawnRaspberryPi.local "chmod +x /tmp/install-tflite-rpi.sh && sudo /tmp/install-tflite-rpi.sh"
```

## Manual Installation

**On your RPi, run:**

```bash
# Install TensorFlow Lite Runtime via pip
sudo pip3 install --break-system-packages tflite-runtime

# Verify installation
python3 -c "import tflite_runtime.interpreter as tflite; print('✓ tflite_runtime installed')"
```

## Verify Installation

After installing, test the import:
```bash
python3 -c "import tflite_runtime.interpreter as tflite; print('Success!')"
```

## Then Start Camera Agent

Once tflite_runtime is installed:
```bash
sudo systemctl start camera-agent
sudo systemctl status camera-agent
```

## Troubleshooting

If pip install fails, try:
```bash
# For Python 3.9 on ARMv7
sudo pip3 install --break-system-packages https://github.com/google-coral/pycoral/releases/download/v2.0.0/tflite_runtime-2.14.0-cp39-cp39-linux_armv7l.whl

# Or check your Python version first
python3 --version
python3 -c "import sys; print(f'Python {sys.version_info.major}.{sys.version_info.minor}')"
```

