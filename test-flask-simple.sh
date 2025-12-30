#!/bin/bash
# Simple Flask Test - Run this ON the Raspberry Pi

echo "=========================================="
echo "FLASK PORTAL DIAGNOSTIC"
echo "=========================================="
echo ""

# Check Flask
echo "1. Checking Flask..."
if python3 -c "import flask" 2>/dev/null; then
    echo "   ✅ Flask installed"
else
    echo "   ❌ Flask NOT installed"
    echo "   Installing Flask..."
    sudo pip3 install flask flask-cors requests --break-system-packages
fi

echo ""
echo "2. Checking portal file..."
if [ -f /opt/camera-agent/provisioning_portal.py ]; then
    echo "   ✅ Portal file exists"
else
    echo "   ❌ Portal file missing"
    exit 1
fi

echo ""
echo "3. Checking config..."
if [ -f /opt/camera-agent/config.json ]; then
    echo "   ⚠️  Config exists - portal will exit immediately"
    echo "   (This is normal if camera is already configured)"
else
    echo "   ✅ No config - portal can run"
fi

echo ""
echo "4. Testing simple Flask server..."
echo "   Starting test server on port 5000..."
echo "   Access from phone: http://192.168.4.1:5000"
echo "   Press Ctrl+C to stop"
echo ""

# Simple test server
sudo python3 << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def test():
    return '''
    <html>
    <head><title>Test</title></head>
    <body style="font-family: sans-serif; padding: 40px; text-align: center;">
        <h1 style="color: green;">✅ Flask Works!</h1>
        <p>If you see this, Flask is running correctly.</p>
        <p>Now test the provisioning portal.</p>
    </body>
    </html>
    '''

if __name__ == '__main__':
    print("=" * 60)
    print("TEST SERVER RUNNING")
    print("=" * 60)
    print("Access at: http://192.168.4.1:5000")
    print("Press Ctrl+C to stop")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF



