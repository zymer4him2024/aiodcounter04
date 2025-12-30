#!/bin/bash
################################################################################
# Update Provisioning Portal on RPi
# Run this script ON the Raspberry Pi to update the portal file
################################################################################

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Updating Provisioning Portal on RPi                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will update the portal from your Mac."
echo "Make sure your Mac is on the same network as the RPi."
echo ""
read -p "Enter your Mac's IP address (or press Enter to skip and update manually): " MAC_IP

if [ -z "$MAC_IP" ]; then
    echo ""
    echo "Manual update instructions:"
    echo "  1. From your Mac terminal, run:"
    echo "     scp /Users/shawnshlee/1_CursorAI/1_aiodcounter04/camera-system/provisioning_portal.py digioptics_od@$(hostname -I | awk '{print $1}').local:/tmp/"
    echo ""
    echo "  2. Then on RPi, run:"
    echo "     sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py"
    echo "     sudo chmod +x /opt/camera-agent/provisioning_portal.py"
    echo "     sudo systemctl daemon-reload"
    echo "     sudo systemctl restart provisioning-portal"
    exit 0
fi

# Try to copy from Mac
echo ""
echo "Attempting to copy from Mac at $MAC_IP..."
MAC_USER=$(whoami)
RPI_IP=$(hostname -I | awk '{print $1}')

# Try scp from Mac
echo "From your Mac, run this command:"
echo "scp /Users/shawnshlee/1_CursorAI/1_aiodcounter04/camera-system/provisioning_portal.py $USER@$RPI_IP:/tmp/"
echo ""
echo "Then run on RPi:"
echo "sudo mv /tmp/provisioning_portal.py /opt/camera-agent/provisioning_portal.py"
echo "sudo chmod +x /opt/camera-agent/provisioning_portal.py"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl restart provisioning-portal"

