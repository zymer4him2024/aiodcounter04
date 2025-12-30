#!/bin/bash
################################################################################
# Install REST API Dependencies for Camera Agent
################################################################################

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Installing REST API Dependencies                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "[1/3] Installing Flask and dependencies..."
sudo pip3 install --break-system-packages Flask flask-cors requests 2>&1 | tail -10

if python3 -c "import flask, flask_cors, requests" 2>/dev/null; then
    echo "   ✓ Flask dependencies installed"
else
    echo "   ✗ Installation failed"
    exit 1
fi
echo ""

echo "[2/3] Verifying installation..."
python3 << 'PYTHON_EOF'
import sys
errors = []

try:
    import flask
    print(f"✓ Flask {flask.__version__}")
except ImportError as e:
    print(f"✗ Flask: {e}")
    errors.append("Flask")

try:
    import flask_cors
    print("✓ flask-cors")
except ImportError as e:
    print(f"✗ flask-cors: {e}")
    errors.append("flask-cors")

try:
    import requests
    print(f"✓ requests {requests.__version__}")
except ImportError as e:
    print(f"✗ requests: {e}")
    errors.append("requests")

if errors:
    print(f"\n❌ Missing: {', '.join(errors)}")
    sys.exit(1)
else:
    print("\n✅ All dependencies installed!")
    sys.exit(0)
PYTHON_EOF

INSTALL_RESULT=$?

echo ""
if [ $INSTALL_RESULT -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ Installation Complete!                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "REST API server will start automatically with camera agent."
    echo ""
    echo "API endpoints will be available at:"
    echo "  - http://<RPI_IP>:5000/api/detection/start"
    echo "  - http://<RPI_IP>:5000/api/detection/stop"
    echo "  - http://<RPI_IP>:5000/api/detection/status"
    echo ""
else
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ❌ Installation Failed                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

