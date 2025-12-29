#!/bin/bash
set -euo pipefail

# Camera System Installation Script for Raspberry Pi
# Installs camera agent and plugins to /opt/camera-agent/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/camera-agent"
SERVICE_USER="${SERVICE_USER:-pi}"

echo "=========================================="
echo "Camera System Installation"
echo "=========================================="
echo "Source directory: $SCRIPT_DIR"
echo "Install directory: $APP_DIR"
echo "Service user: $SERVICE_USER"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Create app directory structure
echo "Creating directory structure..."
mkdir -p "$APP_DIR/plugins"
mkdir -p "$APP_DIR/config"
mkdir -p "/var/log/camera-agent"
mkdir -p "/var/lib/camera-agent"

# Set ownership
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "/var/log/camera-agent"
chown -R "$SERVICE_USER:$SERVICE_USER" "/var/lib/camera-agent"

# Copy camera agent
echo "Copying camera agent..."
if [[ -f "$SCRIPT_DIR/camera_agent.py" ]]; then
    cp "$SCRIPT_DIR/camera_agent.py" "$APP_DIR/"
    chmod +x "$APP_DIR/camera_agent.py"
    chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/camera_agent.py"
    echo "✓ camera_agent.py copied"
else
    echo "⚠ Warning: camera_agent.py not found in $SCRIPT_DIR"
fi

# Copy base detector plugin
echo "Copying base detector plugin..."
if [[ -f "$SCRIPT_DIR/plugins/base_detector.py" ]]; then
    cp "$SCRIPT_DIR/plugins/base_detector.py" "$APP_DIR/plugins/"
    chmod +x "$APP_DIR/plugins/base_detector.py"
    chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/plugins/base_detector.py"
    echo "✓ base_detector.py copied"
else
    echo "⚠ Warning: plugins/base_detector.py not found"
fi

# Copy traffic monitor plugin
echo "Copying traffic monitor plugin..."
if [[ -d "$SCRIPT_DIR/plugins/traffic_monitor" ]]; then
    cp -r "$SCRIPT_DIR/plugins/traffic_monitor" "$APP_DIR/plugins/"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/plugins/traffic_monitor"
    find "$APP_DIR/plugins/traffic_monitor" -type f -name "*.py" -exec chmod +x {} \;
    echo "✓ traffic_monitor plugin copied"
else
    echo "⚠ Warning: plugins/traffic_monitor not found"
fi

# Install Python dependencies (if requirements.txt exists)
if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
    echo "Installing Python dependencies..."
    if command -v pip3 &> /dev/null; then
        pip3 install -r "$SCRIPT_DIR/requirements.txt" || echo "⚠ Warning: Some dependencies may have failed to install"
    else
        echo "⚠ Warning: pip3 not found, skipping dependency installation"
    fi
fi

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/camera-agent.service << EOF
[Unit]
Description=Camera Agent Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment="PYTHONPATH=$APP_DIR"
ExecStart=/usr/bin/python3 $APP_DIR/camera_agent.py $APP_DIR/config/config.json
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Copy helper scripts
echo "Copying helper scripts..."
if [[ -f "$SCRIPT_DIR/test-camera.sh" ]]; then
    cp "$SCRIPT_DIR/test-camera.sh" "$APP_DIR/"
    chmod +x "$APP_DIR/test-camera.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/test-camera.sh"
    echo "✓ test-camera.sh copied"
else
    echo "⚠ Warning: test-camera.sh not found in $SCRIPT_DIR"
fi

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service (but don't start yet - needs configuration)
echo "Enabling camera-agent service..."
systemctl enable camera-agent.service

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Files installed:"
echo "  - $APP_DIR/camera_agent.py"
echo "  - $APP_DIR/plugins/base_detector.py"
echo "  - $APP_DIR/plugins/traffic_monitor/"
echo "  - $APP_DIR/test-camera.sh"
echo ""
echo "Next steps:"
echo "  1. Create configuration file: $APP_DIR/config/config.json"
echo "  2. Install Python dependencies (if not already installed):"
echo "     pip3 install opencv-python numpy firebase-admin sqlalchemy tflite-runtime"
echo "  3. Start the service:"
echo "     sudo systemctl start camera-agent"
echo ""
echo "Useful commands:"
echo "  Test system:        sudo $APP_DIR/test-camera.sh"
echo "  Check service:      sudo systemctl status camera-agent"
echo "  View logs:          sudo journalctl -u camera-agent -f"
echo ""


