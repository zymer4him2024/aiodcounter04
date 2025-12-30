#!/bin/bash
# Copy Provisioning Portal to RPi
# Run this from your Mac terminal

RPI_HOST="digioptics_od@ShawnRaspberryPi.local"
FILE="camera-system/provisioning_portal.py"

echo "Copying provisioning_portal.py to RPi..."
echo "You will be prompted for SSH password"
echo ""

scp "$FILE" "$RPI_HOST:/tmp/provisioning_portal.py" && \
echo "" && \
echo "✓ File copied! Now run these commands on RPi:" && \
echo "  sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py" && \
echo "  sudo chmod +x /opt/camera-agent/provisioning_portal.py" && \
echo "  sudo systemctl daemon-reload" && \
echo "  sudo systemctl restart provisioning-portal"
