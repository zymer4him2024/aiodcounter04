#!/bin/bash
# Complete Hotspot Fix - Addresses Password and DHCP Issues
# Run this ON the Raspberry Pi

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Complete Hotspot Fix (Password + DHCP)                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

HOSTNAME_SHORT=$(hostname | cut -c1-15)
HOTSPOT_SSID="AIOD-Camera-${HOSTNAME_SHORT}"
PASSWORD="aiod2024"

echo "Hotspot SSID: $HOTSPOT_SSID"
echo "Password: $PASSWORD"
echo ""

# Step 1: Fix dnsmasq permissions
echo "[1/6] Fixing dnsmasq permissions..."
sudo mkdir -p /run/dnsmasq
sudo chown dnsmasq:nogroup /run/dnsmasq 2>/dev/null || true
sudo chmod 755 /run/dnsmasq
sudo touch /run/nm-dnsmasq-wlan0.pid
sudo chown root:root /run/nm-dnsmasq-wlan0.pid
sudo chmod 644 /run/nm-dnsmasq-wlan0.pid

# Step 2: Stop conflicting services
echo "[2/6] Stopping conflicting services..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true
sudo killall dnsmasq 2>/dev/null || true
sleep 2

# Step 3: Clean up existing hotspot
echo "[3/6] Cleaning up existing hotspot..."
sudo nmcli con down Hotspot 2>/dev/null || true
sudo nmcli con delete Hotspot 2>/dev/null || true
sleep 2

# Ensure wlan0 is managed and up
sudo nmcli dev set wlan0 managed yes
sudo ip link set wlan0 up
sleep 1

# Step 4: Create hotspot with password
echo "[4/6] Creating hotspot with password..."
sudo nmcli device wifi hotspot \
    ssid "${HOTSPOT_SSID}" \
    password "${PASSWORD}" \
    ifname wlan0 \
    con-name Hotspot

if [ $? -ne 0 ]; then
    echo "   ❌ Failed to create hotspot"
    exit 1
fi

# Step 5: Configure hotspot settings
echo "[5/6] Configuring hotspot settings..."
sudo nmcli connection modify Hotspot \
    ipv4.method shared \
    ipv4.addresses 192.168.4.1/24 \
    connection.autoconnect yes \
    802-11-wireless.band bg \
    802-11-wireless.channel 6 \
    802-11-wireless-security.key-mgmt wpa-psk \
    802-11-wireless-security.proto rsn \
    802-11-wireless-security.pairwise ccmp \
    802-11-wireless-security.group ccmp \
    802-11-wireless-security.psk "${PASSWORD}" \
    802-11-wireless-security.wps-method 0

# Step 6: Activate hotspot
echo "[6/6] Activating hotspot..."
sudo nmcli connection up Hotspot
sleep 5

# Force IP address
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || \
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up

# Wait for dnsmasq to start
sleep 3

# Verification
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Verification                                                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "--- Hotspot Password ---"
sudo nmcli dev wifi show-password

echo ""
echo "--- Hotspot Status ---"
if nmcli connection show --active | grep -q Hotspot; then
    echo "✅ Hotspot is ACTIVE"
else
    echo "❌ Hotspot is NOT active"
fi

echo ""
echo "--- IP Address ---"
ip addr show wlan0 | grep "inet " || echo "No IP address"

echo ""
echo "--- DHCP Server (dnsmasq) ---"
if pgrep -f "nm-dnsmasq.*wlan0" > /dev/null; then
    echo "✅ DHCP server is running"
    ps aux | grep -E "nm-dnsmasq.*wlan0" | grep -v grep | head -1
else
    echo "⚠️  DHCP server may not be running"
fi

echo ""
echo "--- WiFi Interface Mode ---"
sudo wpa_cli -i wlan0 status 2>/dev/null | grep -E "mode|ssid|wpa_state" || echo "Cannot check WiFi status"

echo ""
echo "--- Connection Details ---"
nmcli connection show Hotspot | grep -E '802-11-wireless.ssid|802-11-wireless-security.proto|802-11-wireless-security.key-mgmt|ipv4.method'

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Connection Instructions                                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "1. On your phone, go to WiFi settings"
echo "2. FORGET the network if it's already saved"
echo "3. Look for: $HOTSPOT_SSID"
echo "4. Connect with password: $PASSWORD"
echo "5. If it says 'Saved' but not connected:"
echo "   - Turn WiFi off and on"
echo "   - Forget and reconnect"
echo "6. Once connected, open: http://192.168.4.1"
echo ""
echo "If still not connecting, try:"
echo "  - Password: aiod2024 (all lowercase)"
echo "  - Check phone WiFi settings for 'WPA2' compatibility"
echo "  - Move closer to RPi (within 10 feet)"
echo ""

