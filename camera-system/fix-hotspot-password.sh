#!/bin/bash
# Fix Hotspot Password Connection Issue
# Run this ON the Raspberry Pi

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Fixing Hotspot Password Connection                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

HOSTNAME_SHORT=$(hostname | cut -c1-15)
HOTSPOT_SSID="AIOD-Camera-${HOSTNAME_SHORT}"
PASSWORD="aiod2024"

echo "Hotspot SSID: $HOTSPOT_SSID"
echo "Password: $PASSWORD"
echo ""

# Step 1: Clean up
echo "[1/4] Cleaning up existing hotspot..."
sudo nmcli con down Hotspot 2>/dev/null || true
sudo nmcli con delete Hotspot 2>/dev/null || true
sleep 2

# Step 2: Create hotspot with explicit password
echo "[2/4] Creating hotspot with explicit password..."
sudo nmcli device wifi hotspot \
    ssid "${HOTSPOT_SSID}" \
    password "${PASSWORD}" \
    ifname wlan0 \
    con-name Hotspot

# Step 3: Configure security settings explicitly
echo "[3/4] Configuring security settings..."
sudo nmcli connection modify Hotspot \
    ipv4.method shared \
    ipv4.addresses 192.168.4.1/24 \
    802-11-wireless.band bg \
    802-11-wireless.channel 6 \
    802-11-wireless-security.key-mgmt wpa-psk \
    802-11-wireless-security.proto rsn \
    802-11-wireless-security.pairwise ccmp \
    802-11-wireless-security.group ccmp \
    802-11-wireless-security.psk "${PASSWORD}"

# Step 4: Activate
echo "[4/4] Activating hotspot..."
sudo nmcli connection up Hotspot
sleep 5

# Force IP
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip addr add 192.168.4.1/24 dev wlan0

# Verify
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Verification                                                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

sudo nmcli dev wifi show-password

echo ""
echo "Hotspot Details:"
nmcli connection show Hotspot | grep -E '802-11-wireless.ssid|802-11-wireless-security.proto|802-11-wireless-security.key-mgmt'

echo ""
echo "✅ Hotspot configured with password: $PASSWORD"
echo ""
echo "On your phone:"
echo "1. Forget the network if it's saved"
echo "2. Connect to: $HOTSPOT_SSID"
echo "3. Enter password exactly: $PASSWORD"
echo "4. Make sure caps lock is OFF"
echo ""

