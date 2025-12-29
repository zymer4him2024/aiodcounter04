# Quick Test: Why Portal Can't Be Reached

## 🔍 Step-by-Step Diagnosis

**Run these commands ON the Raspberry Pi:**

### Step 1: Check if Flask is installed
```bash
python3 -c "import flask; print('✅ Flask installed')" || echo "❌ Install: sudo pip3 install flask flask-cors requests --break-system-packages"
```

### Step 2: Check if portal file exists
```bash
ls -la /opt/camera-agent/provisioning_portal.py
```

### Step 3: Check if config.json exists (this prevents portal from running)
```bash
if [ -f /opt/camera-agent/config.json ]; then
    echo "⚠️  Config exists - portal won't run!"
    echo "   This is normal if camera is already configured"
else
    echo "✅ No config - portal should run"
fi
```

### Step 4: Check if anything is listening on port 80
```bash
sudo netstat -tlnp 2>/dev/null | grep :80 || echo "❌ Nothing on port 80"
```

### Step 5: Test portal manually (this will show errors)
```bash
cd /opt/camera-agent
sudo python3 provisioning_portal.py
```

**What do you see?** 
- Does it exit immediately?
- Does it show an error?
- Does it start and show "PORTAL READY"?

---

## 🚀 Quick Fix: Test Portal on Port 5000

If port 80 doesn't work, test on port 5000 (doesn't require root):

**On RPi, run:**
```bash
# Copy test version
sudo cp /opt/camera-agent/provisioning_portal.py /opt/camera-agent/provisioning_portal_test.py

# Edit to use port 5000
sudo sed -i 's/port=80/port=5000/g' /opt/camera-agent/provisioning_portal_test.py

# Run test version
sudo python3 /opt/camera-agent/provisioning_portal_test.py
```

**Then test from phone:**
- URL: `http://192.168.4.1:5000/?token=PT_TEST123`

---

## 💡 Most Common Issues

1. **"This site can't be reached"** = Flask server not running
   - Solution: Start Flask manually or via service

2. **Portal exits immediately** = config.json exists
   - Solution: Remove config temporarily or use test version

3. **Connection refused** = Wrong IP or not on camera WiFi
   - Solution: Connect to AIOD-Camera-XXXX WiFi first

4. **Port 80 permission denied** = Need root or use port 5000
   - Solution: Run with sudo or use port 5000

---

## ✅ Simple Test Command

**Run this ON the RPi to test everything:**

```bash
# Install Flask if needed
sudo pip3 install flask flask-cors requests --break-system-packages

# Create simple test server
sudo python3 -c "
from flask import Flask
app = Flask(__name__)
@app.route('/')
def test():
    return '<h1>Portal Works!</h1><p>Flask is running</p>'
print('Starting test server on port 5000...')
app.run(host='0.0.0.0', port=5000)
"
```

**Then from phone (on camera WiFi):**
- Go to: `http://192.168.4.1:5000`
- Should see "Portal Works!"

If this works, Flask is fine - the issue is with the provisioning portal script.

---

**Share the output of Step 5 above so we can see exactly what's happening!**


