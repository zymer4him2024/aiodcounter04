#!/bin/bash
# Run this ON the Raspberry Pi to diagnose the provisioning portal issue

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Provisioning Portal Diagnostics                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "[1/8] Checking if config.json exists (this prevents portal from running)..."
if [ -f "/opt/camera-agent/config.json" ]; then
    echo "⚠️  WARNING: config.json exists - portal will NOT start!"
    echo "   Portal only runs when camera is NOT configured yet."
    echo "   File: /opt/camera-agent/config.json"
    echo ""
    echo "   Options:"
    echo "   A) Remove config.json temporarily to test portal:"
    echo "      sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup"
    echo "   B) Or skip this check (modify provisioning_portal.py)"
    echo ""
else
    echo "✅ No config.json - portal can run"
fi
echo ""

echo "[2/8] Checking provisioning portal file..."
if [ -f "/opt/camera-agent/provisioning_portal.py" ]; then
    echo "✅ File exists"
    ls -lh /opt/camera-agent/provisioning_portal.py
else
    echo "❌ File NOT found: /opt/camera-agent/provisioning_portal.py"
fi
echo ""

echo "[3/8] Checking Flask installation..."
if python3 -c "import flask" 2>/dev/null; then
    echo "✅ Flask installed"
    python3 -c "import flask; print(f'   Version: {flask.__version__}')"
else
    echo "❌ Flask NOT installed"
    echo "   Install: sudo pip3 install flask flask-cors requests --break-system-packages"
fi
echo ""

echo "[4/8] Checking provisioning portal service..."
if systemctl list-unit-files | grep -q provisioning-portal; then
    echo "✅ Service exists"
    sudo systemctl status provisioning-portal --no-pager -l | head -15
else
    echo "❌ Service NOT found: provisioning-portal"
    echo "   Need to create service file"
fi
echo ""

echo "[5/8] Checking if port 80 is in use..."
if sudo netstat -tlnp 2>/dev/null | grep :80 || sudo ss -tlnp 2>/dev/null | grep :80; then
    echo "✅ Port 80 is listening"
    sudo netstat -tlnp 2>/dev/null | grep :80 || sudo ss -tlnp 2>/dev/null | grep :80
else
    echo "❌ Port 80 NOT listening - Flask is not running"
fi
echo ""

echo "[6/8] Checking WiFi hotspot..."
if iwconfig wlan0 2>/dev/null | grep -q "Mode:Master"; then
    echo "✅ WiFi hotspot is active"
    iwconfig wlan0 2>/dev/null | grep -E "Mode|ESSID"
else
    echo "❌ WiFi hotspot NOT active"
    echo "   Check: sudo iwconfig wlan0"
fi
echo ""

echo "[7/8] Checking NetworkManager..."
if systemctl is-active NetworkManager >/dev/null 2>&1; then
    echo "✅ NetworkManager is running"
else
    echo "⚠️  NetworkManager not active"
fi
echo ""

echo "[8/8] Recent portal logs (if service exists)..."
if systemctl list-unit-files | grep -q provisioning-portal; then
    sudo journalctl -u provisioning-portal -n 20 --no-pager 2>/dev/null || echo "No logs available"
else
    echo "Service not found, checking for log file..."
    if [ -f "/var/log/camera-agent/provisioning.log" ]; then
        tail -20 /var/log/camera-agent/provisioning.log 2>/dev/null || echo "Cannot read log"
    fi
fi
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Summary                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Quick fixes to try:"
echo ""
echo "1. If config.json exists (camera already configured):"
echo "   sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup"
echo ""
echo "2. Install Flask:"
echo "   sudo pip3 install flask flask-cors requests --break-system-packages"
echo ""
echo "3. Test portal manually:"
echo "   sudo python3 /opt/camera-agent/provisioning_portal.py"
echo ""
echo "4. Check if portal is running on different port:"
echo "   sudo netstat -tlnp | grep python"
echo "   sudo ss -tlnp | grep python"
echo ""



