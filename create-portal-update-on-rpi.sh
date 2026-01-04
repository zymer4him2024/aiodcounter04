#!/bin/bash
################################################################################
# Create Portal Update Script for RPi
# This generates a script you can copy and paste into RPi terminal
################################################################################

cat << 'RPI_UPDATE_EOF'
#!/bin/bash
# Run this script ON the Raspberry Pi
# It will backup the current portal and show instructions

echo "Updating provisioning portal..."

# Backup current portal
sudo cp /opt/camera-agent/provisioning_portal.py /opt/camera-agent/provisioning_portal.py.backup
echo "✓ Backed up current portal"

echo ""
echo "Next steps:"
echo "1. From your Mac terminal, run:"
echo "   scp /Users/shawnshlee/1_CursorAI/1_aiodcounter04/camera-system/provisioning_portal.py digioptics_od@ShawnRaspberryPi.local:/tmp/"
echo ""
echo "2. Then on RPi, run:"
echo "   sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py"
echo "   sudo chmod +x /opt/camera-agent/provisioning_portal.py"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl restart provisioning-portal"
RPI_UPDATE_EOF

echo "Script created. Copy the content above and paste it into your RPi terminal."


