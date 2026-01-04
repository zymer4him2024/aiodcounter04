#!/bin/bash
# Comprehensive RPi Hotspot Fix
# Run this ON the Raspberry Pi

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Comprehensive RPi Hotspot Fix                                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Note: This script configures WiFi hotspot (wlan0) only."
echo "Ethernet (eth0) connection will remain active for internet access."
echo ""

# Check current network status
echo "[0/8] Checking network interfaces..."
echo "--- Ethernet (eth0) ---"
ip addr show eth0 2>/dev/null | grep "inet " || echo "   No Ethernet connection"
echo "--- WiFi (wlan0) ---"
ip addr show wlan0 2>/dev/null | grep "inet " || echo "   No WiFi connection"
echo ""

# Step 1: Ensure NetworkManager is running
echo "[1/8] Checking NetworkManager..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
sleep 2

if systemctl is-active --quiet NetworkManager; then
    echo "   ✅ NetworkManager is running"
else
    echo "   ❌ NetworkManager failed to start"
    exit 1
fi

# Step 2: Clean up existing hotspot connections
echo ""
echo "[2/8] Cleaning up old hotspot connections..."
# Only affect wlan0, keep eth0 connections intact
sudo nmcli con down "Hotspot" 2>/dev/null || true
sudo nmcli con delete "Hotspot" 2>/dev/null || true
sudo nmcli con delete "AIOD-Camera-ShawnRas" 2>/dev/null || true
# Ensure wlan0 is managed by NetworkManager (for hotspot)
sudo nmcli dev set wlan0 managed yes
# Ensure eth0 remains managed (for internet)
sudo nmcli dev set eth0 managed yes 2>/dev/null || true
sleep 1
echo "   ✅ Cleanup complete (Ethernet connections preserved)"

# Step 3: Get hostname for SSID
echo ""
echo "[3/8] Getting device hostname..."
HOSTNAME_SHORT=$(hostname | cut -c1-15)
HOTSPOT_SSID="AIOD-Camera-${HOSTNAME_SHORT}"
echo "   Hotspot SSID: ${HOTSPOT_SSID}"

# Step 4: Create hotspot with proper configuration
echo ""
echo "[4/8] Creating hotspot..."
sudo nmcli device wifi hotspot \
    ssid "${HOTSPOT_SSID}" \
    password aiod2024 \
    ifname wlan0 \
    con-name Hotspot

if [ $? -eq 0 ]; then
    echo "   ✅ Hotspot created"
else
    echo "   ❌ Failed to create hotspot"
    exit 1
fi

# Step 5: Configure hotspot for shared mode (DHCP)
echo ""
echo "[5/8] Configuring hotspot for shared mode..."
sudo nmcli connection modify Hotspot \
    ipv4.method shared \
    ipv4.addresses 192.168.4.1/24 \
    connection.autoconnect yes

echo "   ✅ Hotspot configured"

# Step 6: Activate hotspot
echo ""
echo "[6/8] Activating hotspot..."
sudo nmcli connection down Hotspot 2>/dev/null || true
sleep 2
sudo nmcli connection up Hotspot
sleep 3
echo "   ✅ Hotspot activated"

# Step 7: Force IP address (critical step)
echo ""
echo "[7/8] Forcing IP address to 192.168.4.1..."
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || \
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up

# Verify IP
CURRENT_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ "$CURRENT_IP" == "192.168.4.1" ]; then
    echo "   ✅ IP address is correct: $CURRENT_IP"
else
    echo "   ⚠️  IP is $CURRENT_IP, trying again..."
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up
    sleep 2
    CURRENT_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [ "$CURRENT_IP" == "192.168.4.1" ]; then
        echo "   ✅ IP address fixed: $CURRENT_IP"
    else
        echo "   ❌ Failed to set IP address"
    fi
fi

# Step 8: Restart provisioning portal
echo ""
echo "[8/8] Restarting provisioning portal..."
# Kill any process on port 80
sudo fuser -k 80/tcp 2>/dev/null || true
sleep 1

# Restart service
sudo systemctl daemon-reload
sudo systemctl restart provisioning-portal
sleep 3

# Check service status
if systemctl is-active --quiet provisioning-portal; then
    echo "   ✅ Portal service is running"
else
    echo "   ⚠️  Portal service may not be running"
    echo "   Checking logs..."
    sudo journalctl -u provisioning-portal -n 20 --no-pager
fi

# Final verification
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Verification                                                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "--- Ethernet (eth0) Status ---"
ETH_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' || echo "Not connected")
if [ "$ETH_IP" != "Not connected" ]; then
    echo "   ✅ Ethernet connected: $ETH_IP (Internet access available)"
else
    echo "   ⚠️  Ethernet not connected"
fi

echo ""
echo "--- WiFi Hotspot (wlan0) Status ---"
WLAN_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "Not configured")
if [ "$WLAN_IP" = "192.168.4.1" ]; then
    echo "   ✅ Hotspot active: $WLAN_IP"
else
    echo "   ⚠️  Hotspot IP: $WLAN_IP (expected: 192.168.4.1)"
fi

echo ""
echo "--- Active Connections ---"
nmcli connection show --active | grep -E "Hotspot|eth0|wlan0" || echo "No active connections"

echo ""
echo "--- Portal Service ---"
sudo systemctl status provisioning-portal --no-pager -l | head -5

echo ""
echo "--- Listening Ports ---"
sudo netstat -tlnp 2>/dev/null | grep :80 || sudo ss -tlnp | grep :80 || echo "Nothing listening on port 80"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Fix Complete!                                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Connect your phone to:"
echo "  WiFi SSID: ${HOTSPOT_SSID}"
echo "  Password: aiod2024"
echo "  URL: http://192.168.4.1"
echo ""

