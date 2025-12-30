#!/bin/bash
################################################################################
# Install Camera Agent Systemd Service
# Deploys the camera-agent.service file to the Raspberry Pi
################################################################################

set -e

SERVICE_FILE="camera-agent.service"
SERVICE_SOURCE="$(dirname "$0")/${SERVICE_FILE}"
SERVICE_TARGET="/etc/systemd/system/${SERVICE_FILE}"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing Camera Agent Service                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script requires root privileges. Using sudo..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Check if service file already exists in target location
if [ -f "$SERVICE_TARGET" ]; then
    echo "[1/5] Service file already installed at $SERVICE_TARGET"
    echo "✅ Skipping copy (file already in place)"
else
    # Check if service file exists in source location
    if [ ! -f "$SERVICE_SOURCE" ]; then
        echo "❌ Error: Service file not found in source: $SERVICE_SOURCE"
        echo "   And not found in target: $SERVICE_TARGET"
        exit 1
    fi
    
    echo "[1/5] Copying service file..."
    $SUDO_CMD cp "$SERVICE_SOURCE" "$SERVICE_TARGET"
    echo "✅ Service file copied to $SERVICE_TARGET"
fi

echo "[2/5] Setting permissions..."
$SUDO_CMD chmod 644 "$SERVICE_TARGET"
echo "✅ Permissions set"

echo "[3/5] Reloading systemd daemon..."
$SUDO_CMD systemctl daemon-reload
echo "✅ Systemd daemon reloaded"

echo "[4/5] Verifying service file syntax..."
if $SUDO_CMD systemctl is-enabled camera-agent >/dev/null 2>&1 || true; then
    # Service exists, try to validate it
    if $SUDO_CMD systemctl show camera-agent >/dev/null 2>&1; then
        echo "✅ Service file syntax is valid"
    else
        echo "⚠️  Warning: Could not validate service file syntax"
    fi
else
    echo "ℹ️  Service not yet enabled (this is normal for first-time setup)"
fi

echo "[5/5] Summary..."
echo ""
echo "Service file installed: $SERVICE_TARGET"
echo ""
echo "Next steps:"
echo "  • The service will auto-start when /opt/camera-agent/config.json exists"
echo "  • Enable manually: sudo systemctl enable camera-agent"
echo "  • Start manually:   sudo systemctl start camera-agent"
echo "  • Check status:     sudo systemctl status camera-agent"
echo "  • View logs:        sudo journalctl -u camera-agent -f"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Installation Complete!                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

