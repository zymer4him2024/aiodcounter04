#!/bin/bash
# RPI_HOTSPOT_FINAL_FIX.sh
# Run this ON the Raspberry Pi to fix the hotspot and provisioning portal.

echo "=========================================="
echo "🚀 FIXING RPI HOTSPOT & PORTAL"
echo "=========================================="

# 1. Ensure NetworkManager is healthy
echo "[1/6] Checking NetworkManager..."
# Disable dnsmasq if it's running separately, as NetworkManager handles its own DHCP for hotspots
sudo systemctl stop dnsmasq 2>/dev/null
sudo systemctl disable dnsmasq 2>/dev/null

sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
if systemctl is-active --quiet NetworkManager; then
    echo "✅ NetworkManager is running"
else
    echo "❌ NetworkManager failed to start. Trying to restart..."
    sudo systemctl restart NetworkManager
    sleep 2
fi

# 2. Clean up previous hotspot attempts
echo "[2/6] Cleaning up old connections..."
sudo nmcli con down "Hotspot" 2>/dev/null
sudo nmcli con delete "Hotspot" 2>/dev/null
sudo nmcli dev set wlan0 managed yes
echo "✅ Cleanup complete"

# 3. Create the hotspot using the "Safe" nmcli method
echo "[3/6] Creating Hotspot: AIOD-Camera-ShawnRas"
sudo nmcli device wifi hotspot ssid AIOD-Camera-ShawnRas password aiod2024 ifname wlan0
if [ $? -eq 0 ]; then
    echo "✅ Hotspot created successfully"
else
    echo "❌ Failed to create hotspot via nmcli. Trying manual fallback..."
fi

# 4. FORCE the IP address to 192.168.4.1
# This is the most common reason the portal isn't reachable
echo "[4/6] Forcing IP 192.168.4.1 on wlan0..."
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0
echo "✅ IP address set to 192.168.4.1"

# 5. Restart the Provisioning Portal Service
echo "[5/6] Restarting Provisioning Portal..."
# First, ensure no other process is using port 80
sudo fuser -k 80/tcp 2>/dev/null
sudo systemctl restart provisioning-portal
sleep 3
echo "✅ Service restarted"

# 6. Final Verification
echo "[6/6] Final Check..."
echo "--- IP Addresses ---"
ip addr show wlan0 | grep inet
echo "--- Portal Service ---"
sudo systemctl status provisioning-portal --no-pager -l | grep Active
echo "--- Listening Ports ---"
sudo netstat -tlnp | grep :80 || echo "Nothing listening on port 80!"

echo ""
echo "=========================================="
echo "🎉 FIX COMPLETE!"
echo "=========================================="
echo "Try connecting your phone to:"
echo "WiFi: AIOD-Camera-ShawnRas"
echo "Password: aiod2024"
echo "URL: http://192.168.4.1/?token=TEST123"
echo ""
echo "If hotspot still fails, try this URL on your home WiFi:"
MY_IP=$(hostname -I | awk '{print $1}')
echo "URL: http://$MY_IP/?token=TEST123"
echo "=========================================="

