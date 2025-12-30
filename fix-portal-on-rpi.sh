#!/bin/bash
################################################################################
# Fix Provisioning Portal on Raspberry Pi
# Run this script ON the RPi to diagnose and fix portal issues
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Fixing Provisioning Portal on Raspberry Pi                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check if config.json exists (prevents portal from running)
echo "[1/7] Checking config.json..."
if [ -f /opt/camera-agent/config.json ]; then
    echo -e "${YELLOW}⚠ Config file exists - portal won't start${NC}"
    echo "   Portal only runs when camera is not configured."
    read -p "   Backup and remove config to test portal? (y/N): " REMOVE_CONFIG
    if [[ $REMOVE_CONFIG == "y" || $REMOVE_CONFIG == "Y" ]]; then
        sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup
        echo -e "${GREEN}✓ Config backed up${NC}"
    fi
else
    echo -e "${GREEN}✓ No config file - portal can run${NC}"
fi

# Step 2: Ensure log directory exists
echo ""
echo "[2/7] Checking log directory..."
if [ ! -d /var/log/camera-agent ]; then
    sudo mkdir -p /var/log/camera-agent
    sudo chmod 755 /var/log/camera-agent
    echo -e "${GREEN}✓ Log directory created${NC}"
else
    echo -e "${GREEN}✓ Log directory exists${NC}"
fi

# Step 3: Check Flask installation
echo ""
echo "[3/7] Checking Flask installation..."
if python3 -c "import flask" 2>/dev/null; then
    echo -e "${GREEN}✓ Flask is installed${NC}"
else
    echo -e "${YELLOW}⚠ Flask not installed - installing...${NC}"
    sudo pip3 install flask flask-cors requests --break-system-packages
    echo -e "${GREEN}✓ Flask installed${NC}"
fi

# Step 4: Configure hotspot with shared IP mode (DHCP)
echo ""
echo "[4/7] Configuring hotspot for DHCP..."
# Check if Hotspot connection exists
if nmcli connection show Hotspot &>/dev/null; then
    # Set to shared mode (enables DHCP)
    sudo nmcli connection modify Hotspot ipv4.method shared
    echo -e "${GREEN}✓ Hotspot configured for shared mode (DHCP enabled)${NC}"
else
    echo -e "${YELLOW}⚠ Hotspot connection doesn't exist - creating...${NC}"
    HOSTNAME_SHORT=$(hostname | cut -c1-15)
    sudo nmcli device wifi hotspot ssid "AIOD-Camera-${HOSTNAME_SHORT}" password aiod2024 ifname wlan0 con-name Hotspot
    sudo nmcli connection modify Hotspot ipv4.method shared ipv4.addresses 192.168.4.1/24
    echo -e "${GREEN}✓ Hotspot created${NC}"
fi

# Step 5: Activate hotspot
echo ""
echo "[5/7] Activating hotspot..."
sudo nmcli connection down Hotspot 2>/dev/null || true
sleep 1
sudo nmcli connection up Hotspot
sleep 2

# Force IP address
sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up 2>/dev/null || true

# Verify hotspot is active
if nmcli connection show --active | grep -q Hotspot; then
    echo -e "${GREEN}✓ Hotspot is active${NC}"
    IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo "   IP Address: $IP"
    if [ "$IP" == "192.168.4.1" ]; then
        echo -e "${GREEN}✓ IP address is correct${NC}"
    else
        echo -e "${YELLOW}⚠ IP is $IP, forcing to 192.168.4.1...${NC}"
        sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up
    fi
else
    echo -e "${RED}✗ Hotspot failed to activate${NC}"
    exit 1
fi

# Step 6: Start portal service
echo ""
echo "[6/7] Starting provisioning portal..."
sudo systemctl daemon-reload
sudo systemctl start provisioning-portal
sleep 2

if sudo systemctl is-active --quiet provisioning-portal; then
    echo -e "${GREEN}✓ Portal service is running${NC}"
else
    echo -e "${RED}✗ Portal service failed to start${NC}"
    echo "Checking logs..."
    sudo journalctl -u provisioning-portal -n 20 --no-pager
    exit 1
fi

# Step 7: Verify portal is accessible
echo ""
echo "[7/7] Verifying portal is accessible..."
sleep 1

# Check if Flask is listening on port 80
if sudo netstat -tlnp 2>/dev/null | grep -q ":80.*python3" || sudo ss -tlnp 2>/dev/null | grep -q ":80.*python3"; then
    echo -e "${GREEN}✓ Flask is listening on port 80${NC}"
else
    echo -e "${YELLOW}⚠ Flask not detected on port 80${NC}"
fi

# Test local connectivity
if curl -s http://localhost >/dev/null 2>&1 || curl -s http://192.168.4.1 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Portal responds locally${NC}"
else
    echo -e "${YELLOW}⚠ Portal not responding locally${NC}"
fi

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Portal Fix Complete!                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Portal Status:"
sudo systemctl status provisioning-portal --no-pager -l | head -10
echo ""
echo "Hotspot Information:"
echo "  SSID: $(nmcli connection show Hotspot | grep '802-11-wireless.ssid' | awk '{print $2}')"
echo "  IP: $(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
echo ""
echo "Access the portal:"
echo "  1. Connect phone to WiFi: $(nmcli connection show Hotspot | grep '802-11-wireless.ssid' | awk '{print $2}')"
echo "  2. Password: aiod2024"
echo "  3. Open browser: http://192.168.4.1"
echo ""
echo "View logs: sudo journalctl -u provisioning-portal -f"
echo ""

