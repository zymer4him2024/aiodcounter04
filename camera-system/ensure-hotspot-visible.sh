#!/bin/bash
# Ensure RPi Hotspot is Visible and Working
# Run this ON the Raspberry Pi to fix hotspot visibility issues

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Ensuring RPi Hotspot is Visible                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check wlan0 interface
echo "[1/7] Checking wlan0 interface..."
if ip link show wlan0 > /dev/null 2>&1; then
    echo "   ✅ wlan0 interface exists"
    WLAN0_STATUS=$(ip link show wlan0 | grep -o "state [A-Z]*" | awk '{print $2}')
    echo "   Status: $WLAN0_STATUS"
    
    if [ "$WLAN0_STATUS" != "UP" ]; then
        echo "   ⚠️  wlan0 is not UP, bringing it up..."
        sudo ip link set wlan0 up
        sleep 2
    fi
else
    echo "   ❌ wlan0 interface not found!"
    echo "   Check if WiFi adapter is connected"
    exit 1
fi

# Step 2: Check NetworkManager
echo ""
echo "[2/7] Checking NetworkManager..."
if systemctl is-active --quiet NetworkManager; then
    echo "   ✅ NetworkManager is running"
else
    echo "   ⚠️  NetworkManager not running, starting..."
    sudo systemctl start NetworkManager
    sudo systemctl enable NetworkManager
    sleep 3
fi

# Ensure wlan0 is managed by NetworkManager
echo "   Ensuring wlan0 is managed..."
sudo nmcli dev set wlan0 managed yes
sleep 1

# Step 3: Check for existing hotspot
echo ""
echo "[3/7] Checking for existing hotspot..."
HOTSPOT_EXISTS=false
if nmcli connection show Hotspot > /dev/null 2>&1; then
    HOTSPOT_EXISTS=true
    echo "   ✅ Hotspot connection exists"
    
    # Get current SSID
    CURRENT_SSID=$(nmcli connection show Hotspot | grep "802-11-wireless.ssid" | awk '{print $2}' || echo "")
    echo "   Current SSID: $CURRENT_SSID"
    
    # Check if it's active
    if nmcli connection show --active | grep -q Hotspot; then
        echo "   ✅ Hotspot is active"
    else
        echo "   ⚠️  Hotspot exists but not active"
    fi
else
    echo "   ⚠️  No hotspot connection found"
fi

# Step 4: Get hostname for SSID
echo ""
echo "[4/7] Getting device hostname..."
HOSTNAME_FULL=$(hostname)
HOSTNAME_SHORT=$(echo "$HOSTNAME_FULL" | cut -c1-15)
HOTSPOT_SSID="AIOD-Camera-${HOSTNAME_SHORT}"
echo "   Full hostname: $HOSTNAME_FULL"
echo "   Hotspot SSID: $HOTSPOT_SSID"

# Step 5: Clean up and recreate if needed
echo ""
echo "[5/7] Setting up hotspot..."

if [ "$HOTSPOT_EXISTS" = true ]; then
    # Check if SSID matches
    if [ "$CURRENT_SSID" != "$HOTSPOT_SSID" ]; then
        echo "   ⚠️  SSID mismatch, recreating hotspot..."
        sudo nmcli con down Hotspot 2>/dev/null || true
        sudo nmcli con delete Hotspot 2>/dev/null || true
        sleep 2
        HOTSPOT_EXISTS=false
    else
        echo "   ✅ SSID matches, reusing existing hotspot"
    fi
fi

if [ "$HOTSPOT_EXISTS" = false ]; then
    echo "   Creating new hotspot..."
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
    
    # Configure for shared mode
    echo "   Configuring for shared mode..."
    sudo nmcli connection modify Hotspot \
        ipv4.method shared \
        ipv4.addresses 192.168.4.1/24 \
        connection.autoconnect yes
fi

# Step 6: Activate hotspot
echo ""
echo "[6/7] Activating hotspot..."
sudo nmcli con down Hotspot 2>/dev/null || true
sleep 2

# Ensure wlan0 is up
sudo ip link set wlan0 up
sleep 1

# Activate hotspot
sudo nmcli con up Hotspot
sleep 5

# Verify it's active
if nmcli connection show --active | grep -q Hotspot; then
    echo "   ✅ Hotspot is active"
else
    echo "   ⚠️  Hotspot activation may have failed, trying again..."
    sudo nmcli con up Hotspot
    sleep 5
fi

# Step 7: Force IP and verify
echo ""
echo "[7/7] Setting IP address and verifying..."
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || \
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up

sleep 2

# Verify IP
CURRENT_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ "$CURRENT_IP" = "192.168.4.1" ]; then
    echo "   ✅ IP address is correct: $CURRENT_IP"
else
    echo "   ⚠️  IP is $CURRENT_IP, forcing to 192.168.4.1..."
    sudo ifconfig wlan0 192.168.4.1 netmask 255.255.255.0 up
    sleep 2
fi

# Final verification
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Verification                                                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "--- Hotspot Status ---"
if nmcli connection show --active | grep -q Hotspot; then
    echo "✅ Hotspot is ACTIVE"
    ACTIVE_SSID=$(nmcli connection show Hotspot | grep "802-11-wireless.ssid" | awk '{print $2}')
    echo "   SSID: $ACTIVE_SSID"
    echo "   Password: aiod2024"
else
    echo "❌ Hotspot is NOT active"
fi

echo ""
echo "--- WiFi Interface (wlan0) ---"
iwconfig wlan0 2>/dev/null | grep -E "Mode|ESSID|Frequency" || echo "   Cannot read wlan0 info"

echo ""
echo "--- IP Address ---"
ip addr show wlan0 | grep "inet " || echo "   No IP address on wlan0"

echo ""
echo "--- NetworkManager Status ---"
nmcli device status | grep wlan0 || echo "   wlan0 not in NetworkManager"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Next Steps                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "1. On your phone, go to WiFi settings"
echo "2. Look for: $HOTSPOT_SSID"
echo "3. Connect with password: aiod2024"
echo "4. Open browser: http://192.168.4.1"
echo ""
echo "If hotspot still not visible:"
echo "  - Wait 30 seconds and refresh WiFi list"
echo "  - Move phone closer to RPi"
echo "  - Check if other devices can see it"
echo "  - Run: sudo iwconfig wlan0 (to check WiFi mode)"
echo ""

