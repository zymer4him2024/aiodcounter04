#!/bin/bash
set -euo pipefail

# Raspberry Pi Production Installation Script
# Installs Python dependencies, creates systemd services, and enables them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="${APP_DIR:-/opt/aiodcounter03}"
PYTHON_VENV="${APP_DIR}/venv"
SERVICE_USER="${SERVICE_USER:-pi}"

echo "=========================================="
echo "Raspberry Pi Production Installation"
echo "=========================================="
echo "Project root: $PROJECT_ROOT"
echo "App directory: $APP_DIR"
echo "Service user: $SERVICE_USER"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Create app directory
echo "Creating app directory: $APP_DIR"
mkdir -p "$APP_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"

# Install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y python3 python3-venv python3-pip

# Create Python virtual environment
echo "Creating Python virtual environment..."
if [[ -d "$PYTHON_VENV" ]]; then
    echo "Virtual environment already exists, skipping..."
else
    sudo -u "$SERVICE_USER" python3 -m venv "$PYTHON_VENV"
fi

# Install Python dependencies
echo "Installing Python dependencies..."
sudo -u "$SERVICE_USER" "$PYTHON_VENV/bin/pip" install --upgrade pip
sudo -u "$SERVICE_USER" "$PYTHON_VENV/bin/pip" install requests python-dotenv

# Copy RPi scripts to app directory
echo "Copying RPi scripts..."
if [[ -d "$PROJECT_ROOT/rpi" ]]; then
    cp -r "$PROJECT_ROOT/rpi"/* "$APP_DIR/" || true
    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    chmod +x "$APP_DIR/firstboot_register.py" || true
fi

# Create systemd service directory if it doesn't exist
SYSTEMD_DIR="/etc/systemd/system"
mkdir -p "$SYSTEMD_DIR"

# Create firstboot service
echo "Creating firstboot systemd service..."
cat > "$SYSTEMD_DIR/aiodcounter03-firstboot.service" << EOF
[Unit]
Description=AIOD Counter 03 First Boot Registration
After=network-online.target
Wants=network-online.target
Before=aiodcounter03-edge.service

[Service]
Type=oneshot
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=$PYTHON_VENV/bin/python3 $APP_DIR/firstboot_register.py
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create edge service (placeholder - adjust based on your detection_client.py)
echo "Creating edge systemd service..."
cat > "$SYSTEMD_DIR/aiodcounter03-edge.service" << EOF
[Unit]
Description=AIOD Counter 03 Edge Detection Service
After=network-online.target aiodcounter03-firstboot.service
Wants=network-online.target
Requires=aiodcounter03-firstboot.service

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment="APP_DIR=$APP_DIR"
Environment="PATH=$PYTHON_VENV/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$PYTHON_VENV/bin/python3 $APP_DIR/detection_client.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable services
echo "Enabling services..."
systemctl enable aiodcounter03-firstboot.service
systemctl enable aiodcounter03-edge.service

# Start firstboot service if provision file exists
if [[ -f "/boot/provision.json" ]]; then
    echo "Provision file found. Starting firstboot service..."
    systemctl start aiodcounter03-firstboot.service
else
    echo "No provision file found. Firstboot service will run on next boot."
fi

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo "Services installed:"
echo "  - aiodcounter03-firstboot.service (oneshot)"
echo "  - aiodcounter03-edge.service (always running)"
echo ""
echo "To check service status:"
echo "  sudo systemctl status aiodcounter03-firstboot.service"
echo "  sudo systemctl status aiodcounter03-edge.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u aiodcounter03-firstboot.service -f"
echo "  sudo journalctl -u aiodcounter03-edge.service -f"
echo ""







