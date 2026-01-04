#!/bin/bash
# Find Raspberry Pi IP address on the network
# Useful when RPi has both WiFi and Ethernet connections

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Finding Raspberry Pi IP Address                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Known RPi IPs to check
KNOWN_IPS=(
    "192.168.0.214"  # WiFi IP
    "192.168.4.1"    # Hotspot IP
)

echo "Checking known IPs..."
for IP in "${KNOWN_IPS[@]}"; do
    if ping -c 1 -W 2 "$IP" > /dev/null 2>&1; then
        echo "✅ $IP is reachable"
        # Try SSH to verify it's the RPi
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" > /dev/null 2>&1; then
            HOSTNAME=$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" 2>/dev/null)
            echo "   ✅ Confirmed: RPi at $IP (hostname: $HOSTNAME)"
            echo ""
            echo "Use this IP: $IP"
            exit 0
        fi
    else
        echo "❌ $IP is not reachable"
    fi
done

echo ""
echo "Scanning network for RPi..."
echo ""

# Get local network range
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ifconfig en0 | grep "inet " | awk '{print $2}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
fi

if [ -n "$LOCAL_IP" ]; then
    NETWORK=$(echo "$LOCAL_IP" | cut -d. -f1-3)
    echo "Scanning network: ${NETWORK}.0/24"
    echo "(This may take a minute...)"
    echo ""
    
    # Scan common IP range
    for i in {1..254}; do
        IP="${NETWORK}.${i}"
        # Skip router and self
        if [ "$IP" = "${NETWORK}.1" ] || [ "$IP" = "$LOCAL_IP" ]; then
            continue
        fi
        
        # Quick ping check
        if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
            # Try SSH to see if it's the RPi
            if ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" > /dev/null 2>&1; then
                HOSTNAME=$(ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" 2>/dev/null)
                echo "✅ Found RPi: $IP (hostname: $HOSTNAME)"
                echo ""
                echo "Use this IP: $IP"
                echo ""
                echo "To deploy fix:"
                echo "  RPI_IP=$IP ./deploy-hotspot-fix.sh"
                exit 0
            fi
        fi
    done
fi

echo ""
echo "❌ Could not find RPi automatically"
echo ""
echo "Manual options:"
echo "  1. Check your router's connected devices list"
echo "  2. Connect to RPi hotspot and check: http://192.168.4.1"
echo "  3. Use serial console to check: hostname -I"
echo "  4. Specify IP manually: RPI_IP=<IP> ./deploy-hotspot-fix.sh"
echo ""

