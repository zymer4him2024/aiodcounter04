#!/bin/bash
################################################################################
# HAILO CAMERA SYSTEM INSTALLATION
# Installs camera agent with Hailo-accelerated detection
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    Hailo Camera System Installation v1.0                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root${NC}"
  exit 1
fi

STEP=0
TOTAL_STEPS=8

progress() {
  STEP=$((STEP + 1))
  echo ""
  echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] $1${NC}"
}

# Check Hailo
progress "Checking Hailo device..."
if ! hailortcli scan > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Hailo device not detected${NC}"
    echo "Run: hailortcli scan"
    exit 1
fi
echo "✓ Hailo device detected"

# Check models
progress "Checking Hailo models..."
if [ ! -f "/opt/hailo-models/yolov8n.hef" ]; then
    echo -e "${RED}ERROR: YOLOv8 model not found${NC}"
    echo "Expected: /opt/hailo-models/yolov8n.hef"
    exit 1
fi
echo "✓ YOLOv8 model found"

# Update system
progress "Updating system..."
apt update -qq

# Install Python
progress "Installing Python environment..."
apt install -y python3 python3-pip python3-venv > /dev/null 2>&1

# Install system dependencies
progress "Installing dependencies..."
apt install -y \
    python3-opencv \
    v4l-utils \
    > /dev/null 2>&1

# Create directories
progress "Creating directories..."
mkdir -p /opt/camera-agent/plugins/traffic_monitor_hailo
mkdir -p /var/log/camera-agent

# Create virtual environment
progress "Setting up Python environment..."
cd /opt/camera-agent
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install --upgrade pip > /dev/null 2>&1
pip install \
    hailo-platform \
    hailort \
    opencv-python \
    numpy \
    firebase-admin \
    > /dev/null 2>&1

deactivate

# Create systemd service
progress "Creating service..."
cat > /etc/systemd/system/camera-agent.service << 'EOF'
[Unit]
Description=Camera Agent - Hailo-Accelerated Detection
After=network-online.target
Wants=network-online.target
ConditionPathExists=/opt/camera-agent/config.json

[Service]
Type=simple
User=root
WorkingDirectory=/opt/camera-agent
Environment="PATH=/opt/camera-agent/venv/bin"
ExecStart=/opt/camera-agent/venv/bin/python /opt/camera-agent/camera_agent.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable camera-agent

# Create helper scripts
cat > /opt/camera-agent/test-hailo.sh << 'EOF'
#!/bin/bash
echo "=== Hailo System Test ==="
echo ""
echo "1. Hailo Device:"
hailortcli scan
echo ""
echo "2. Hailo Firmware:"
hailortcli fw-control identify
echo ""
echo "3. Models:"
ls -lh /opt/hailo-models/*.hef
echo ""
echo "4. Camera:"
v4l2-ctl --list-devices
EOF
chmod +x /opt/camera-agent/test-hailo.sh

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✓ INSTALLATION COMPLETE!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "System: Hailo-8 Accelerated Traffic Monitoring"
echo "Model: YOLOv8n (Hardware Accelerated)"
echo "Classes: person, car, motorcycle, bus, truck"
echo ""
echo "Next steps:"
echo "  1. Copy camera agent files"
echo "  2. Test system: /opt/camera-agent/test-hailo.sh"
echo "  3. Activate camera via provisioning portal"
echo ""
