#!/bin/bash
# Comprehensive Diagnostic and Fix Script for Provisioning Portal
# Run this ON the Raspberry Pi

echo "=========================================="
echo "PROVISIONING PORTAL DIAGNOSTIC & FIX"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check Flask installation
echo "[1/8] Checking Flask..."
if python3 -c "import flask" 2>/dev/null; then
    echo -e "${GREEN}✓ Flask installed${NC}"
else
    echo -e "${RED}✗ Flask NOT installed${NC}"
    echo "Installing Flask..."
    sudo pip3 install flask flask-cors requests --break-system-packages
    if python3 -c "import flask" 2>/dev/null; then
        echo -e "${GREEN}✓ Flask installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install Flask${NC}"
        exit 1
    fi
fi

# Step 2: Check portal file
echo ""
echo "[2/8] Checking portal file..."
if [ -f /opt/camera-agent/provisioning_portal.py ]; then
    echo -e "${GREEN}✓ Portal file exists${NC}"
else
    echo -e "${RED}✗ Portal file missing${NC}"
    echo "Creating directory..."
    sudo mkdir -p /opt/camera-agent
    echo -e "${YELLOW}⚠ You need to copy provisioning_portal.py to /opt/camera-agent/${NC}"
    exit 1
fi

# Step 3: Check permissions
echo ""
echo "[3/8] Checking file permissions..."
sudo chmod +x /opt/camera-agent/provisioning_portal.py
echo -e "${GREEN}✓ Permissions set${NC}"

# Step 4: Check config.json (prevents portal from running)
echo ""
echo "[4/8] Checking config.json..."
if [ -f /opt/camera-agent/config.json ]; then
    echo -e "${YELLOW}⚠ Config exists - portal won't run automatically${NC}"
    echo "This is normal if camera is already configured."
    echo "Options:"
    echo "  1. Backup config: sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup"
    echo "  2. Run portal manually for testing: sudo python3 /opt/camera-agent/provisioning_portal.py"
else
    echo -e "${GREEN}✓ No config - portal can run${NC}"
fi

# Step 5: Check log directory
echo ""
echo "[5/8] Checking log directory..."
if [ -d /var/log/camera-agent ]; then
    echo -e "${GREEN}✓ Log directory exists${NC}"
else
    echo "Creating log directory..."
    sudo mkdir -p /var/log/camera-agent
    sudo chmod 755 /var/log/camera-agent
    echo -e "${GREEN}✓ Log directory created${NC}"
fi

# Step 6: Check if service exists
echo ""
echo "[6/8] Checking provisioning portal service..."
if [ -f /etc/systemd/system/provisioning-portal.service ]; then
    echo -e "${GREEN}✓ Service file exists${NC}"
    echo "Service status:"
    sudo systemctl status provisioning-portal --no-pager -l || echo "Service not running"
else
    echo -e "${YELLOW}⚠ Service file missing - creating...${NC}"
    sudo tee /etc/systemd/system/provisioning-portal.service > /dev/null << 'EOF'
[Unit]
Description=Camera Provisioning Portal
After=network-online.target hostapd.service
Wants=network-online.target
ConditionPathExists=!/opt/camera-agent/config.json

[Service]
Type=simple
User=root
WorkingDirectory=/opt/camera-agent
ExecStart=/usr/bin/python3 /opt/camera-agent/provisioning_portal.py
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    echo -e "${GREEN}✓ Service created${NC}"
fi

# Step 7: Check port 80
echo ""
echo "[7/8] Checking port 80..."
PORT_80=$(sudo netstat -tlnp 2>/dev/null | grep :80 || sudo ss -tlnp 2>/dev/null | grep :80 || echo "")
if [ -z "$PORT_80" ]; then
    echo -e "${RED}✗ Nothing listening on port 80${NC}"
else
    echo -e "${GREEN}✓ Port 80 is in use:${NC}"
    echo "$PORT_80"
fi

# Step 8: Test portal manually
echo ""
echo "[8/8] Testing portal..."
echo -e "${YELLOW}Testing if portal can start...${NC}"
echo ""

# Create a test version that doesn't exit if config exists
sudo python3 << 'TEST_EOF'
import sys
sys.path.insert(0, '/opt/camera-agent')

try:
    # Try to import the portal
    import provisioning_portal
    
    # Check if it has the Flask app
    if hasattr(provisioning_portal, 'app'):
        print("✓ Portal module loads successfully")
        print("✓ Flask app found")
    else:
        print("✗ Flask app not found in portal module")
        sys.exit(1)
        
except ImportError as e:
    print(f"✗ Failed to import portal: {e}")
    sys.exit(1)
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)

TEST_EOF

TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Portal module is valid${NC}"
else
    echo -e "${RED}✗ Portal module has issues${NC}"
fi

echo ""
echo "=========================================="
echo "DIAGNOSTIC COMPLETE"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. If config.json exists and you want to test:"
echo "   sudo mv /opt/camera-agent/config.json /opt/camera-agent/config.json.backup"
echo ""
echo "2. Start the portal service:"
echo "   sudo systemctl start provisioning-portal"
echo ""
echo "3. Enable auto-start on boot:"
echo "   sudo systemctl enable provisioning-portal"
echo ""
echo "4. Check service status:"
echo "   sudo systemctl status provisioning-portal"
echo ""
echo "5. View logs:"
echo "   sudo journalctl -u provisioning-portal -f"
echo ""
echo "6. Test manually (if service fails):"
echo "   sudo python3 /opt/camera-agent/provisioning_portal.py"
echo ""
echo "7. From phone (connected to camera WiFi):"
echo "   http://192.168.4.1/?token=PT_TEST123"
echo ""
echo "=========================================="




