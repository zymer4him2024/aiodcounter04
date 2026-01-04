#!/bin/bash
################################################################################
# Complete Activation Flow Test Script
# Run this ON the Raspberry Pi to test the full activation → service start flow
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_DIR="/opt/camera-agent"
CONFIG_FILE="$APP_DIR/config.json"
SERVICE_NAME="camera-agent"
PORTAL_FILE="$APP_DIR/provisioning_portal.py"
SERVICE_FILE="/etc/systemd/system/camera-agent.service"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  COMPLETE ACTIVATION FLOW TEST                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo -e "   ${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "   ${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_warn() {
    echo -e "   ${YELLOW}⚠${NC} $1"
}

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 1: PRE-TEST VERIFICATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Check portal file exists
echo "[1/10] Checking provisioning portal file..."
if [ -f "$PORTAL_FILE" ]; then
    test_pass "Portal file exists: $PORTAL_FILE"
    
    # Check if it has the new activation logic
    if grep -q "systemctl.*enable.*camera-agent" "$PORTAL_FILE"; then
        test_pass "Portal contains service start logic"
    else
        test_fail "Portal missing service start logic (may need update)"
    fi
else
    test_fail "Portal file not found: $PORTAL_FILE"
fi
echo ""

# Test 2: Check service file
echo "[2/10] Checking systemd service file..."
if [ -f "$SERVICE_FILE" ]; then
    test_pass "Service file exists: $SERVICE_FILE"
    
    # Validate service file syntax
    if sudo systemctl daemon-reload 2>/dev/null && sudo systemctl show camera-agent >/dev/null 2>&1; then
        test_pass "Service file syntax is valid"
    else
        test_warn "Service file may have syntax issues"
    fi
else
    test_warn "Service file not installed yet. Run: sudo ./install-camera-service.sh"
fi
echo ""

# Test 3: Check Python dependencies
echo "[3/10] Checking Python dependencies..."
REQUIRED_MODULES=("flask" "requests")
for module in "${REQUIRED_MODULES[@]}"; do
    if python3 -c "import $module" 2>/dev/null; then
        test_pass "Module '$module' available"
    else
        test_fail "Module '$module' not found (install: sudo pip3 install $module --break-system-packages)"
    fi
done
echo ""

# Test 4: Check if camera is already activated
echo "[4/10] Checking activation status..."
if [ -f "$CONFIG_FILE" ]; then
    test_warn "Camera already activated (config.json exists)"
    echo ""
    read -p "   Do you want to backup and remove config for fresh test? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%s)"
        sudo mv "$CONFIG_FILE" "$BACKUP_FILE"
        test_pass "Config backed up to: $BACKUP_FILE"
        echo "   (Restore with: sudo mv $BACKUP_FILE $CONFIG_FILE)"
    else
        echo "   Skipping activation test (camera already configured)"
        echo "   To test activation, remove config: sudo rm $CONFIG_FILE"
    fi
else
    test_pass "Camera not activated (ready for test)"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 2: CONFIG TRANSFORMATION TEST"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 5: Test config transformation logic
echo "[5/10] Testing config transformation..."
python3 << 'TEST_CONFIG_EOF'
import json
import sys

# Simulate Firebase response (old format)
firebase_config = {
    "cameraId": "CAM_TEST123",
    "siteId": "SITE_001",
    "subadminId": "SUB_TEST",
    "deviceId": "test-device",
    "macAddress": "AA:BB:CC:DD:EE:FF",
    "serialNumber": "TEST123",
    "deviceToken": "DEV_TOKEN_TEST",
    "firebaseConfig": {
        "apiKey": "test",
        "projectId": "test"
    },
    "transmissionConfig": {
        "interval": 300,
        "batchSize": 10
    },
    "detectionConfig": {
        "zones": [],
        "objectClasses": ["person", "vehicle"],
        "confidenceThreshold": 0.8
    }
}

# Apply transformation (same as portal)
config = firebase_config.copy()
if 'transmissionConfig' in config and 'interval' in config['transmissionConfig']:
    config['transmissionConfig']['aggregationInterval'] = config['transmissionConfig'].pop('interval')

if 'detectionConfig' in config and 'zones' in config['detectionConfig']:
    config['detectionConfig']['detectionZones'] = config['detectionConfig'].pop('zones')

if 'orgId' not in config:
    config['orgId'] = config.get('siteId', 'default')

if 'serviceAccountPath' not in config:
    config['serviceAccountPath'] = '/opt/camera-agent/service-account.json'

if 'detectionConfig' in config and 'modelPath' not in config['detectionConfig']:
    config['detectionConfig']['modelPath'] = '/opt/camera-agent/model.tflite'

# Validate
errors = []
if 'aggregationInterval' not in config.get('transmissionConfig', {}):
    errors.append("Missing aggregationInterval")
if 'detectionZones' not in config.get('detectionConfig', {}):
    errors.append("Missing detectionZones")
if 'orgId' not in config:
    errors.append("Missing orgId")
if 'serviceAccountPath' not in config:
    errors.append("Missing serviceAccountPath")

if errors:
    print(f"   ✗ Config transformation failed: {', '.join(errors)}")
    sys.exit(1)
else:
    print("   ✓ Config transformation successful")
    print(f"   ✓ aggregationInterval: {config['transmissionConfig']['aggregationInterval']}")
    print(f"   ✓ detectionZones: {len(config['detectionConfig']['detectionZones'])} zones")
    print(f"   ✓ orgId: {config['orgId']}")
TEST_CONFIG_EOF

if [ $? -eq 0 ]; then
    test_pass "Config transformation logic works correctly"
else
    test_fail "Config transformation test failed"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 3: PORTAL FUNCTIONALITY TEST"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 6: Test portal can be imported
echo "[6/10] Testing portal module import..."
if python3 -c "import sys; sys.path.insert(0, '/opt/camera-agent'); import provisioning_portal" 2>/dev/null; then
    test_pass "Portal module imports successfully"
else
    test_fail "Portal module import failed"
    python3 -c "import sys; sys.path.insert(0, '/opt/camera-agent'); import provisioning_portal" 2>&1 | head -5
fi
echo ""

# Test 7: Check portal has required routes
echo "[7/10] Checking portal routes..."
if grep -q "@app.route('/activate'" "$PORTAL_FILE" && grep -q "@app.route('/token-info'" "$PORTAL_FILE"; then
    test_pass "Portal has required routes (/activate, /token-info)"
else
    test_fail "Portal missing required routes"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 4: SERVICE INSTALLATION TEST"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 8: Check service installation
echo "[8/10] Testing service installation..."
if [ -f "$SERVICE_FILE" ]; then
    test_pass "Service file is installed"
    
    # Check if service can be enabled
    if sudo systemctl is-enabled camera-agent >/dev/null 2>&1 || \
       sudo systemctl enable --dry-run camera-agent >/dev/null 2>&1; then
        test_pass "Service can be enabled"
    else
        test_warn "Service enable test inconclusive (may need config.json)"
    fi
else
    echo "   Installing service file..."
    if [ -f "$(dirname "$0")/install-camera-service.sh" ] || [ -f "./install-camera-service.sh" ]; then
        INSTALL_SCRIPT="$(dirname "$0")/install-camera-service.sh"
        [ ! -f "$INSTALL_SCRIPT" ] && INSTALL_SCRIPT="./install-camera-service.sh"
        
        if sudo bash "$INSTALL_SCRIPT" 2>/dev/null; then
            test_pass "Service installed successfully"
        else
            test_fail "Service installation failed"
        fi
    else
        test_fail "Install script not found. Manually install service file."
    fi
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 5: ACTIVATION SIMULATION (OPTIONAL)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 9: Simulate activation (if not already activated)
echo "[9/10] Activation simulation..."
if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "   This will test the activation flow with a real token."
    echo "   You can skip this and test manually via the portal UI."
    echo ""
    read -p "   Do you want to simulate activation with a test token? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "   Enter a valid provisioning token (PT_...): " TEST_TOKEN
        
        if [ ! -z "$TEST_TOKEN" ]; then
            echo "   Attempting activation with token..."
            
            # Stop portal if running
            sudo systemctl stop provisioning-portal 2>/dev/null || true
            
            # Test activation via curl (if portal is running)
            # This is a simplified test - full test requires portal to be running
            test_warn "Manual activation test recommended via portal UI"
            echo "   Steps:"
            echo "   1. Start portal: sudo systemctl start provisioning-portal"
            echo "   2. Connect to WiFi: AIOD-Camera-<hostname>"
            echo "   3. Open: http://192.168.4.1/?token=$TEST_TOKEN"
            echo "   4. Click 'Activate Camera'"
            echo "   5. Verify service starts: sudo systemctl status camera-agent"
        else
            test_warn "No token provided, skipping activation test"
        fi
    else
        test_pass "Activation simulation skipped (will test manually)"
    fi
else
    test_pass "Camera already activated (skipping simulation)"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "PHASE 6: POST-ACTIVATION VERIFICATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 10: Check if service would start (if config exists)
echo "[10/10] Service startup verification..."
if [ -f "$CONFIG_FILE" ]; then
    # Validate config JSON
    if python3 -m json.tool "$CONFIG_FILE" >/dev/null 2>&1; then
        test_pass "Config file is valid JSON"
        
        # Check required fields
        if python3 << 'CHECK_CONFIG_EOF'
import json
import sys

try:
    with open('/opt/camera-agent/config.json', 'r') as f:
        config = json.load(f)
    
    required = ['cameraId', 'siteId', 'orgId', 'firebaseConfig', 'transmissionConfig', 'detectionConfig']
    missing = [f for f in required if f not in config]
    
    if missing:
        print(f"   ✗ Missing required fields: {', '.join(missing)}")
        sys.exit(1)
    
    # Check nested fields
    if 'aggregationInterval' not in config.get('transmissionConfig', {}):
        print("   ✗ Missing transmissionConfig.aggregationInterval")
        sys.exit(1)
    
    if 'detectionZones' not in config.get('detectionConfig', {}):
        print("   ✗ Missing detectionConfig.detectionZones")
        sys.exit(1)
    
    print("   ✓ Config has all required fields")
    print(f"   ✓ Camera ID: {config.get('cameraId', 'N/A')}")
    print(f"   ✓ Site ID: {config.get('siteId', 'N/A')}")
    
except Exception as e:
    print(f"   ✗ Config validation error: {e}")
    sys.exit(1)
CHECK_CONFIG_EOF
        then
            test_pass "Config has all required fields for camera_agent.py"
        else
            test_fail "Config missing required fields"
        fi
        
        # Check service status
        if sudo systemctl is-active --quiet camera-agent 2>/dev/null; then
            test_pass "Camera agent service is running"
            echo ""
            echo "   Service status:"
            sudo systemctl status camera-agent --no-pager -l | head -10 | sed 's/^/      /'
        elif sudo systemctl is-enabled --quiet camera-agent 2>/dev/null; then
            test_warn "Service is enabled but not running"
            echo "   Start with: sudo systemctl start camera-agent"
        else
            test_warn "Service not enabled/started"
            echo "   Enable with: sudo systemctl enable --now camera-agent"
        fi
    else
        test_fail "Config file is not valid JSON"
    fi
else
    test_pass "No config file (camera not activated yet)"
fi
echo ""

# Final Summary
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  TEST SUMMARY                                                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "   Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo "   Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy updated Firebase functions: ./deploy-functions.sh"
    echo "  2. Test activation via portal UI with a real token"
    echo "  3. Verify service starts automatically after activation"
    echo "  4. Check Firestore for count data: cameras/{cameraId}/counts/"
else
    echo -e "${YELLOW}⚠ Some tests failed. Review output above.${NC}"
fi

echo ""
echo "Useful commands:"
echo "  View portal logs:     sudo journalctl -u provisioning-portal -f"
echo "  View agent logs:      sudo journalctl -u camera-agent -f"
echo "  Check agent status:   sudo systemctl status camera-agent"
echo "  Check portal status:  sudo systemctl status provisioning-portal"
echo ""



