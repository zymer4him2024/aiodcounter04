#!/bin/bash
# Camera System Test Script
# Tests camera agent installation, configuration, and runtime status

echo "=========================================="
echo "  CAMERA SYSTEM TEST"
echo "=========================================="
echo ""

APP_DIR="/opt/camera-agent"
CONFIG_FILE="$APP_DIR/config/config.json"
SERVICE_NAME="camera-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Service Status
echo "1. Service Status:"
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "   ${GREEN}✓${NC} Service is running"
    systemctl status $SERVICE_NAME --no-pager -l | head -n 3 | tail -n 1
else
    echo -e "   ${RED}✗${NC} Service is not running"
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        echo "   Service is enabled but not active"
    else
        echo "   Service is not enabled"
    fi
fi
echo ""

# Test 2: Configuration File
echo "2. Configuration File:"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "   ${GREEN}✓${NC} Config file exists: $CONFIG_FILE"
    
    # Validate JSON
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
            echo -e "   ${GREEN}✓${NC} Config file is valid JSON"
            
            # Extract key values
            if command -v jq &> /dev/null; then
                echo "   Camera ID: $(jq -r '.cameraId // "N/A"' "$CONFIG_FILE")"
                echo "   Site ID: $(jq -r '.siteId // "N/A"' "$CONFIG_FILE")"
            else
                echo "   (Install 'jq' for detailed config parsing)"
            fi
        else
            echo -e "   ${RED}✗${NC} Config file is invalid JSON"
        fi
    fi
else
    echo -e "   ${RED}✗${NC} Config file not found: $CONFIG_FILE"
    echo "   Run provisioning to create configuration"
fi
echo ""

# Test 3: File Permissions
echo "3. File Permissions:"
if [ -f "$APP_DIR/camera_agent.py" ]; then
    if [ -x "$APP_DIR/camera_agent.py" ]; then
        echo -e "   ${GREEN}✓${NC} camera_agent.py is executable"
    else
        echo -e "   ${YELLOW}⚠${NC} camera_agent.py is not executable"
    fi
else
    echo -e "   ${RED}✗${NC} camera_agent.py not found"
fi

if [ -d "$APP_DIR/plugins" ]; then
    PLUGIN_COUNT=$(find "$APP_DIR/plugins" -name "*.py" | wc -l)
    echo "   Plugins found: $PLUGIN_COUNT"
else
    echo -e "   ${RED}✗${NC} Plugins directory not found"
fi
echo ""

# Test 4: Python Environment
echo "4. Python Environment:"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "   ${GREEN}✓${NC} Python: $PYTHON_VERSION"
    
    # Check required modules
    REQUIRED_MODULES=("firebase_admin" "cv2" "numpy")
    for module in "${REQUIRED_MODULES[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            echo -e "   ${GREEN}✓${NC} Module '$module' available"
        else
            echo -e "   ${RED}✗${NC} Module '$module' not found"
        fi
    done
else
    echo -e "   ${RED}✗${NC} Python3 not found"
fi
echo ""

# Test 5: Network Connectivity
echo "5. Network Connectivity:"
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓${NC} Internet connectivity: OK"
else
    echo -e "   ${RED}✗${NC} Internet connectivity: FAILED"
fi

# Check Firebase endpoint
FIREBASE_URL="https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera"
if curl -s --max-time 5 "$FIREBASE_URL" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓${NC} Firebase endpoint reachable"
else
    echo -e "   ${YELLOW}⚠${NC} Firebase endpoint check failed (may be normal)"
fi
echo ""

# Test 6: Recent Logs
echo "6. Recent Logs (last 10 lines):"
if systemctl is-active --quiet $SERVICE_NAME; then
    journalctl -u $SERVICE_NAME -n 10 --no-pager | sed 's/^/   /'
else
    echo "   Service not running - no recent logs"
    echo "   Last logs before stop:"
    journalctl -u $SERVICE_NAME -n 5 --no-pager | sed 's/^/   /' || echo "   No logs found"
fi
echo ""

# Test 7: System Resources
echo "7. System Resources:"
echo "   CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "   Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "   Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo ""

# Summary
echo "=========================================="
echo "  TEST SUMMARY"
echo "=========================================="

ISSUES=0

if ! systemctl is-active --quiet $SERVICE_NAME; then
    ISSUES=$((ISSUES + 1))
fi

if [ ! -f "$CONFIG_FILE" ]; then
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed${NC}"
    echo ""
    echo "Useful commands:"
    echo "  View logs:        sudo journalctl -u $SERVICE_NAME -f"
    echo "  Restart service:  sudo systemctl restart $SERVICE_NAME"
    echo "  Check status:     sudo systemctl status $SERVICE_NAME"
else
    echo -e "${YELLOW}⚠ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Troubleshooting:"
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        echo "  - Start service: sudo systemctl start $SERVICE_NAME"
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "  - Configure camera using provisioning portal"
    fi
fi

echo "=========================================="





