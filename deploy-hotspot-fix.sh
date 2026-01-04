#!/bin/bash
# Deploy Hotspot Fix to Raspberry Pi via SSH
# Run this from your Mac

set -e

# Allow manual IP override via environment variable
RPI_IP="${RPI_IP:-192.168.0.214}"
RPI_WIFI="digioptics_od@${RPI_IP}"
RPI_HOTSPOT="digioptics_od@192.168.4.1"
SCRIPT_PATH="camera-system/fix-hotspot.sh"
RPI_TMP="/tmp/fix-hotspot.sh"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Deploying Hotspot Fix to Raspberry Pi                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script not found: $SCRIPT_PATH"
    exit 1
fi

# Try to detect which IP is reachable
RPI_HOST=""
echo "Checking RPi connectivity..."
echo "   (RPi has both WiFi and Ethernet connections)"

# Check WiFi IP first (most common)
if ping -c 1 -W 2 192.168.0.214 > /dev/null 2>&1; then
    echo "✅ RPi WiFi/Ethernet is reachable (192.168.0.214)"
    RPI_HOST="$RPI_WIFI"
# Check hotspot IP
elif ping -c 1 -W 2 192.168.4.1 > /dev/null 2>&1; then
    echo "✅ RPi hotspot is reachable (192.168.4.1)"
    echo "⚠️  Note: You may need to connect to the hotspot WiFi first"
    RPI_HOST="$RPI_HOTSPOT"
# Try to find RPi via ARP table (Ethernet might be on different IP)
else
    echo "⚠️  Standard IPs not reachable, checking ARP table..."
    
    # Check ARP table for known RPi MAC addresses or hostname
    ARP_ENTRIES=$(arp -a | grep -E "192\.168\.0\." | head -10)
    
    if [ -n "$ARP_ENTRIES" ]; then
        echo "   Found devices on network:"
        # Use process substitution to avoid subshell issue
        while IFS= read -r line; do
            IP=$(echo "$line" | grep -oE "192\.168\.0\.[0-9]+" | head -1)
            if [ -n "$IP" ] && [ "$IP" != "192.168.0.1" ]; then
                echo "   Trying $IP..."
                if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
                    # Try SSH to see if it's the RPi
                    if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" > /dev/null 2>&1; then
                        HOSTNAME=$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "digioptics_od@$IP" "hostname" 2>/dev/null)
                        echo "✅ Found RPi at $IP (hostname: $HOSTNAME)"
                        RPI_HOST="digioptics_od@$IP"
                        break
                    fi
                fi
            fi
        done <<< "$ARP_ENTRIES"
    fi
    
    # If still not found, provide options
    if [ -z "$RPI_HOST" ]; then
        echo "❌ Cannot reach RPi automatically"
        echo ""
        echo "Since RPi has both WiFi and Ethernet, try:"
        echo ""
        echo "Option 1: Specify RPi IP manually:"
        echo "  RPI_IP=<IP_ADDRESS> ./deploy-hotspot-fix.sh"
        echo ""
        echo "Option 2: Connect to RPi hotspot and use hotspot deployment:"
        echo "  1. Connect your Mac to WiFi: AIOD-Camera-XXXXX (password: aiod2024)"
        echo "  2. Run: ./deploy-hotspot-fix-via-hotspot.sh"
        echo ""
        echo "Option 3: Use manual deployment:"
        echo "  Run: ./deploy-hotspot-fix-manual.sh"
        echo ""
        echo "Option 4: Direct SSH (if you know the IP):"
        echo "  ssh digioptics_od@<RPI_IP>"
        echo "  Then copy and run the fix script manually"
        
        # Allow manual IP override
        if [ -n "$RPI_IP" ]; then
            echo ""
            echo "Using provided IP: $RPI_IP"
            RPI_HOST="digioptics_od@$RPI_IP"
        else
            exit 1
        fi
    fi
fi

echo ""
echo "[1/3] Copying fix script to Raspberry Pi..."
echo "   Target: $RPI_HOST"

scp -o ConnectTimeout=10 "$SCRIPT_PATH" "${RPI_HOST}:${RPI_TMP}"

if [ $? -eq 0 ]; then
    echo "   ✅ Script copied successfully"
else
    echo "   ✗ Failed to copy script"
    exit 1
fi
echo ""

echo "[2/3] Making script executable on RPi..."
ssh "${RPI_HOST}" "chmod +x ${RPI_TMP} && echo '✓ Script is now executable'"

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to make script executable"
    exit 1
fi
echo ""

echo "[3/3] Running hotspot fix on RPi..."
echo "   (This may take a minute...)"
echo ""
ssh -t "${RPI_HOST}" "sudo ${RPI_TMP}"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Deployment Complete!                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Connect your phone to the hotspot WiFi"
echo "  2. Open browser: http://192.168.4.1"
echo ""

