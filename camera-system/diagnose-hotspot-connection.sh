#!/bin/bash
# Diagnose Hotspot Connection Issues
# Run this ON the Raspberry Pi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Hotspot Connection Diagnostic                                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "=== Hotspot Configuration ==="
SSID=$(nmcli connection show Hotspot | grep "802-11-wireless.ssid" | awk '{print $2}')
PASSWORD=$(sudo nmcli dev wifi show-password 2>/dev/null | grep "Password:" | awk '{print $2}' || echo "aiod2024")
echo "SSID: $SSID"
echo "Password: $PASSWORD"
echo ""

echo "=== Hotspot Status ==="
if nmcli connection show --active | grep -q Hotspot; then
    echo "✅ Hotspot is ACTIVE"
else
    echo "❌ Hotspot is NOT active"
fi
echo ""

echo "=== WiFi Interface (wlan0) ==="
ip link show wlan0 | grep -E "state|UP|DOWN"
WLAN_MODE=$(sudo wpa_cli -i wlan0 status 2>/dev/null | grep "mode=" | cut -d= -f2 || echo "unknown")
echo "Mode: $WLAN_MODE (should be AP)"
echo ""

echo "=== IP Address ==="
ip addr show wlan0 | grep "inet " || echo "No IP address"
echo ""

echo "=== NetworkManager Status ==="
nmcli device status | grep wlan0
echo ""

echo "=== WiFi Adapter Info ==="
if command -v iw > /dev/null 2>&1; then
    sudo iw dev wlan0 info 2>/dev/null || echo "iw command not available"
elif command -v iwconfig > /dev/null 2>&1; then
    sudo iwconfig wlan0 2>/dev/null | grep -E "Mode|ESSID|Frequency" || echo "iwconfig not available"
else
    echo "WiFi tools not available"
fi
echo ""

echo "=== Recent NetworkManager Errors ==="
sudo journalctl -u NetworkManager -n 20 --no-pager | grep -i -E "error|fail|wlan0|hotspot" | tail -5 || echo "No recent errors"
echo ""

echo "=== Troubleshooting Tips ==="
echo "1. Ensure phone is within 10-20 feet of RPi"
echo "2. Try forgetting the network on phone and reconnecting"
echo "3. Check if other devices can see the hotspot"
echo "4. Verify password is exactly: aiod2024"
echo "5. Try restarting phone WiFi"
echo "6. Check if RPi WiFi adapter supports AP mode:"
echo "   sudo iw list | grep -A 5 'Supported interface modes'"
echo ""

