#!/usr/bin/env python3
import os, sys, json, time, subprocess, requests, logging
from pathlib import Path
from flask import Flask, request, jsonify, render_template_string

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/camera-agent/provisioning.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
CONFIG_PATH = "/opt/camera-agent/config.json"
PROVISION_SERVER = "https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera"
TOKEN_INFO_SERVER = "https://us-central1-aiodcouter04.cloudfunctions.net/getProvisioningTokenInfo"
HOTSPOT_SSID_PREFIX = "AIOD-Camera"
HOTSPOT_PASSWORD = "aiod2024"

app = Flask(__name__)

# System Info
def get_sys_info():
    info = {"hostname": "camera", "serial": "unknown", "mac": "unknown"}
    try:
        info["hostname"] = subprocess.check_output("hostname", shell=True).decode().strip()
        info["serial"] = subprocess.check_output("grep Serial /proc/cpuinfo | awk '{print $3}'", shell=True).decode().strip() or "unknown"
        info["mac"] = subprocess.check_output("cat /sys/class/net/wlan0/address", shell=True).decode().strip().upper()
    except: pass
    return info

sys_info = get_sys_info()

# --- Multi-Step Portal: WiFi Config First, Then Activation ---
PORTAL_HTML = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Camera Setup</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#F5F5F7;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}
.card{background:white;padding:40px;border-radius:24px;box-shadow:0 10px 40px rgba(0,0,0,0.05);width:100%;max-width:440px;text-align:center}
h1{font-size:24px;font-weight:600;margin-bottom:8px;color:#1D1D1F}
p{color:#86868B;margin-bottom:32px;font-size:15px}
.info{background:#FBFBFD;padding:16px;border-radius:14px;margin-bottom:24px;text-align:left;font-size:13px;color:#424245}
.token-details{background:#E8F2FF;padding:16px;border-radius:14px;margin-bottom:24px;text-align:left;font-size:14px;display:none;border:1px solid #0071E3}
.token-details h3{font-size:14px;color:#0071E3;margin-bottom:8px}
.token-row{display:flex;justify-content:space-between;margin-bottom:4px}
.token-label{color:#86868B}.token-value{font-weight:600;color:#1D1D1F}
input{width:100%;padding:16px;background:#F5F5F7;border:none;border-radius:12px;font-size:17px;margin-bottom:20px}
.btn{width:100%;padding:16px;background:#0071E3;color:white;border:none;border-radius:12px;font-size:17px;font-weight:600;cursor:pointer;transition:all 0.2s}
.btn:disabled{background:#E1E1E6;color:#86868B}
.step{display:none}
.step.active{display:block}
.status-box{margin-top:16px;padding:16px;border-radius:12px;font-size:14px;text-align:left}
.status-box.success{background:#d4edda;color:#155724;border:1px solid #c3e6cb}
.status-box.info{background:#d1ecf1;color:#0c5460;border:1px solid #bee5eb}
.status-box.error{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}
.status-box strong{display:block;margin-bottom:8px}
.ip-address{font-size:24px;color:#0071E3;font-weight:600;font-family:monospace;padding:12px;background:#F5F5F7;border-radius:8px;margin:12px 0}
</style>
</head>
<body>
<div class="card">
  <!-- Step 1: WiFi Configuration -->
  <div class="step active" id="step1">
    <h1>Step 1: Connect to Site WiFi</h1>
    <p>Enter your site WiFi network credentials</p>
    <div class="info">Device: {{ hostname }}<br>Serial: {{ serial }}</div>
    <form id="wifiForm">
      <input type="text" id="wifiSSID" placeholder="WiFi Network Name (SSID)" required autocomplete="off">
      <input type="password" id="wifiPassword" placeholder="WiFi Password" autocomplete="off">
      <button type="submit" class="btn" id="wifiBtn">Connect to WiFi</button>
    </form>
    <div id="wifiMsg" style="display:none"></div>
  </div>

  <!-- Step 2: WiFi Connected - Show new IP and instructions -->
  <div class="step" id="step2">
    <h1>✓ WiFi Connected!</h1>
    <p>Please reconnect your phone to the site WiFi</p>
    <div class="info">
      <strong>Connected to:</strong><br>
      <span id="connectedSSID" style="font-weight:600">-</span><br><br>
      <strong>Portal Access:</strong><br>
      <div class="ip-address" id="portalIP">Loading...</div>
    </div>
    <div class="status-box info">
      <strong>Next Steps:</strong>
      <ol style="margin:8px 0 0 20px;padding:0">
        <li>Disconnect from camera hotspot</li>
        <li>Connect your phone to site WiFi: <span id="ssidDisplay">-</span></li>
        <li>Open browser to the IP address above</li>
        <li>Continue with activation</li>
      </ol>
    </div>
    <button class="btn" onclick="checkWiFiStatus()" style="margin-top:20px">Continue to Activation</button>
  </div>

  <!-- Step 3: Activation -->
  <div class="step" id="step3">
    <h1>Step 2: Activate Camera</h1>
    <p>Enter provisioning token from QR code</p>
    <div class="token-details" id="details">
      <h3>Token Information</h3>
      <div class="token-row"><span class="token-label">Name:</span><span class="token-value" id="det-name">-</span></div>
      <div class="token-row"><span class="token-label">Site:</span><span class="token-value" id="det-site">-</span></div>
    </div>
    <div class="info">Device: {{ hostname }}<br>Serial: {{ serial }}</div>
    <form id="actForm">
      <input type="text" id="token" placeholder="PT_XXXXXXXX" value="{{ token }}" required>
      <button type="submit" class="btn" id="btn">Activate Camera</button>
    </form>
    <div id="msg" style="margin-top:20px;font-size:14px"></div>
  </div>
</div>

<script>
const step1 = document.getElementById('step1');
const step2 = document.getElementById('step2');
const step3 = document.getElementById('step3');
const wifiForm = document.getElementById('wifiForm');
const wifiMsg = document.getElementById('wifiMsg');

// Check WiFi status on page load
fetch('/wifi-status').then(r => r.json()).then(data => {
  if (data.connected) {
    // WiFi already connected, skip to activation
    step1.classList.remove('active');
    step3.classList.add('active');
    document.getElementById('portalIP').textContent = data.ip || window.location.hostname;
  } else {
    // Show WiFi config
    step1.classList.add('active');
  }
}).catch(() => {
  // If check fails, show WiFi config
  step1.classList.add('active');
});

// WiFi configuration
wifiForm.onsubmit = async (e) => {
  e.preventDefault();
  const btn = document.getElementById('wifiBtn');
  const ssid = document.getElementById('wifiSSID').value.trim();
  const password = document.getElementById('wifiPassword').value;
  
  btn.disabled = true;
  btn.innerText = 'Connecting...';
  wifiMsg.style.display = 'block';
  wifiMsg.className = 'status-box info';
  wifiMsg.innerHTML = 'Connecting to WiFi...';
  
  try {
    const res = await fetch('/configure-wifi', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ssid: ssid, password: password})
    });
    const data = await res.json();
    if (data.status === 'success') {
      wifiMsg.className = 'status-box success';
      wifiMsg.innerHTML = '✓ WiFi connected successfully!';
      step1.classList.remove('active');
      step2.classList.add('active');
      document.getElementById('connectedSSID').textContent = ssid;
      document.getElementById('ssidDisplay').textContent = ssid;
      document.getElementById('portalIP').textContent = data.ip || 'Loading...';
    } else {
      wifiMsg.className = 'status-box error';
      wifiMsg.innerHTML = '✗ ' + (data.message || 'Connection failed');
      btn.disabled = false;
      btn.innerText = 'Try Again';
    }
  } catch (err) {
    wifiMsg.className = 'status-box error';
    wifiMsg.innerHTML = 'Network error: ' + err.message;
    btn.disabled = false;
    btn.innerText = 'Try Again';
  }
};

function checkWiFiStatus() {
  fetch('/wifi-status').then(r => r.json()).then(data => {
    if (data.connected) {
      step2.classList.remove('active');
      step3.classList.add('active');
      document.getElementById('portalIP').textContent = data.ip || window.location.hostname;
    } else {
      alert('WiFi not connected. Please configure WiFi first.');
    }
  });
}

// Step 3: Activation (existing activation logic)
const tInput = document.getElementById('token');
const details = document.getElementById('details');
const dName = document.getElementById('det-name');
const dSite = document.getElementById('det-site');

async function checkToken(val) {
  if (val.length < 8) { details.style.display = 'none'; return; }
  try {
    const r = await fetch('/token-info?token=' + val);
    const j = await r.json();
    if (j.success) {
      dName.innerText = j.cameraName;
      dSite.innerText = j.siteName;
      details.style.display = 'block';
    } else { details.style.display = 'none'; }
  } catch(e) {}
}
tInput.oninput = (e) => checkToken(e.target.value.trim());
if (tInput.value) checkToken(tInput.value.trim());

document.getElementById('actForm').onsubmit = async (e) => {
  e.preventDefault();
  const btn = document.getElementById('btn');
  const msg = document.getElementById('msg');
  btn.disabled = true; btn.innerText = 'Activating...';
  try {
    const res = await fetch('/activate', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({token: tInput.value})
    });
    const data = await res.json();
    if (data.status === 'success') {
      msg.style.color = 'green'; msg.innerHTML = '✅ Activated! Camera ID: ' + data.cameraId + '<br>Portal will close in 5 seconds...';
      setTimeout(() => { window.location.reload(); }, 5000);
    } else {
      msg.style.color = 'red'; msg.innerText = '❌ ' + (data.message || 'Failed');
      btn.disabled = false; btn.innerText = 'Try Again';
    }
  } catch (err) { 
    msg.style.color = 'red';
    msg.innerText = 'Network error: ' + err.message; 
    btn.disabled = false; 
    btn.innerText = 'Try Again';
  }
};
</script></body></html>"""

@app.route('/')
def index():
    return render_template_string(PORTAL_HTML, hostname=sys_info['hostname'], serial=sys_info['serial'], token=request.args.get('token', ''))

@app.route('/token-info')
def token_info():
    try:
        r = requests.get(f"{TOKEN_INFO_SERVER}?token={request.args.get('token')}", timeout=5)
        return jsonify(r.json())
    except: return jsonify({"success": False})

@app.route('/wifi-status')
def wifi_status():
    """Check if RPi is connected to WiFi (not hotspot)"""
    try:
        # Get active WiFi connection (not hotspot)
        result = subprocess.run(
            ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "con", "show", "--active"],
            capture_output=True, text=True, timeout=5
        )
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines:
                parts = line.split(':')
                if len(parts) >= 3 and '802-11-wireless' in parts[1] and 'wlan0' in parts[2] and 'Hotspot' not in parts[0]:
                    # Connected to WiFi (not hotspot)
                    # Get IP address
                    ip_result = subprocess.run(
                        ["hostname", "-I"],
                        capture_output=True, text=True, timeout=5
                    )
                    ip = None
                    if ip_result.returncode == 0:
                        # Filter to get wlan0 IP (usually first non-127.x.x.x IP)
                        ips = ip_result.stdout.strip().split()
                        for ip_addr in ips:
                            if not ip_addr.startswith('127.') and not ip_addr.startswith('192.168.4.'):
                                ip = ip_addr
                                break
                        if not ip and ips:
                            ip = ips[0]  # Fallback to first IP
                    
                    return jsonify({
                        "connected": True,
                        "ssid": parts[0],
                        "ip": ip or "Unknown"
                    })
        
        return jsonify({"connected": False})
    except Exception as e:
        logger.error(f"Error checking WiFi status: {e}")
        return jsonify({"connected": False})

@app.route('/configure-wifi', methods=['POST'])
def configure_wifi():
    """Connect RPi to site WiFi"""
    try:
        data = request.get_json()
        ssid = data.get('ssid', '').strip()
        password = data.get('password', '').strip()
        
        if not ssid:
            return jsonify({"status": "error", "message": "WiFi SSID is required"}), 400
        
        logger.info(f"Configuring WiFi: SSID={ssid}")
        
        # Disable hotspot first (but keep portal running)
        subprocess.run(["sudo", "nmcli", "con", "down", "Hotspot"], check=False, timeout=5)
        time.sleep(1)
        
        # Create or connect to WiFi
        # Check if connection already exists
        check_result = subprocess.run(
            ["nmcli", "-t", "-f", "NAME", "con", "show", ssid],
            capture_output=True, text=True, timeout=5
        )
        
        if check_result.returncode == 0 and check_result.stdout.strip():
            # Connection exists, activate it (possibly with new password)
            logger.info(f"WiFi connection '{ssid}' exists, updating password if needed...")
            if password:
                subprocess.run(
                    ["sudo", "nmcli", "con", "modify", ssid, "wifi-sec.psk", password],
                    check=False, timeout=5
                )
            result = subprocess.run(
                ["sudo", "nmcli", "con", "up", ssid],
                capture_output=True, text=True, timeout=30
            )
        else:
            # Create new connection
            logger.info(f"Creating new WiFi connection: {ssid}")
            if password:
                result = subprocess.run(
                    ["sudo", "nmcli", "device", "wifi", "connect", ssid, "password", password],
                    capture_output=True, text=True, timeout=30
                )
            else:
                result = subprocess.run(
                    ["sudo", "nmcli", "device", "wifi", "connect", ssid],
                    capture_output=True, text=True, timeout=30
                )
        
        if result.returncode == 0:
            # Wait for connection to establish and get IP
            time.sleep(5)
            
            # Get new IP address
            ip_result = subprocess.run(
                ["hostname", "-I"],
                capture_output=True, text=True, timeout=5
            )
            new_ip = None
            if ip_result.returncode == 0:
                # Filter to get wlan0 IP (not hotspot IP 192.168.4.1)
                ips = ip_result.stdout.strip().split()
                for ip_addr in ips:
                    if not ip_addr.startswith('127.') and not ip_addr.startswith('192.168.4.'):
                        new_ip = ip_addr
                        break
                if not new_ip and ips:
                    new_ip = ips[0]  # Fallback to first IP
            
            logger.info(f"WiFi connected! IP: {new_ip}")
            logger.info("Portal continues running - accessible at new IP")
            
            # Portal continues running, accessible at new IP
            return jsonify({
                "status": "success",
                "message": "WiFi connected successfully",
                "ip": new_ip or "Unknown",
                "ssid": ssid
            })
        else:
            error_msg = result.stderr or result.stdout or "Connection failed"
            logger.error(f"WiFi connection failed: {error_msg}")
            # Re-enable hotspot if WiFi connection failed
            subprocess.run(["sudo", "nmcli", "con", "up", "Hotspot"], check=False, timeout=5)
            return jsonify({"status": "error", "message": f"Failed to connect: {error_msg}"}), 400
            
    except Exception as e:
        logger.error(f"Error configuring WiFi: {e}")
        # Re-enable hotspot on error
        subprocess.run(["sudo", "nmcli", "con", "up", "Hotspot"], check=False, timeout=5)
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/activate', methods=['POST'])
def activate():
    try:
        data = request.get_json()
        token = data.get('token', '').strip()
        logger.info(f"Activation request received for token: {token[:10]}...")
        
        payload = {"provisioningToken": token, "deviceInfo": {"macAddress": sys_info['mac'], "serialNumber": sys_info['serial'], "hostname": sys_info['hostname']}}
        logger.info(f"Calling provision server: {PROVISION_SERVER}")
        r = requests.post(PROVISION_SERVER, json=payload, timeout=20)
        if r.status_code == 200:
            res = r.json()
            config = res['config']
            camera_id = res.get('cameraId')
            logger.info(f"Provisioning successful! Camera ID: {camera_id}")
            
            # Transform config to match camera_agent.py expectations
            # Fix transmissionConfig: interval -> aggregationInterval
            if 'transmissionConfig' in config and 'interval' in config['transmissionConfig']:
                config['transmissionConfig']['aggregationInterval'] = config['transmissionConfig'].pop('interval')
            
            # Fix detectionConfig: zones -> detectionZones
            if 'detectionConfig' in config and 'zones' in config['detectionConfig']:
                config['detectionConfig']['detectionZones'] = config['detectionConfig'].pop('zones')
            elif 'detectionConfig' not in config or 'detectionZones' not in config.get('detectionConfig', {}):
                # Ensure detectionZones exists (default empty list)
                if 'detectionConfig' not in config:
                    config['detectionConfig'] = {}
                config['detectionConfig']['detectionZones'] = []
            
            # Add missing orgId (derive from siteId or subadminId)
            if 'orgId' not in config:
                # Use siteId as orgId for now (can be refined later)
                config['orgId'] = config.get('siteId', 'default')
            
            # Add serviceAccountPath (expected to be pre-installed on RPi)
            if 'serviceAccountPath' not in config:
                config['serviceAccountPath'] = '/opt/camera-agent/service-account.json'
            
            # Add modelPath if not present (default location)
            if 'detectionConfig' in config and 'modelPath' not in config['detectionConfig']:
                config['detectionConfig']['modelPath'] = '/opt/camera-agent/model.tflite'
            
            # Ensure detectionConfig has required fields
            if 'detectionConfig' not in config:
                config['detectionConfig'] = {}
            if 'objectClasses' not in config['detectionConfig']:
                config['detectionConfig']['objectClasses'] = ["person", "vehicle", "forklift"]
            if 'confidenceThreshold' not in config['detectionConfig']:
                config['detectionConfig']['confidenceThreshold'] = 0.8
            
            # Save transformed config
            Path(CONFIG_PATH).parent.mkdir(parents=True, exist_ok=True)
            with open(CONFIG_PATH, 'w') as f: 
                json.dump(config, f, indent=2)
            logger.info(f"Config saved to {CONFIG_PATH}")
            
            # Enable and start camera-agent service
            logger.info("Starting camera-agent service...")
            subprocess.run(["sudo", "systemctl", "enable", "camera-agent"], check=False)
            result = subprocess.run(["sudo", "systemctl", "start", "camera-agent"], check=False, capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Camera-agent service started successfully")
            else:
                logger.warning(f"Camera-agent service start may have issues: {result.stderr}")
            
            # Give service a moment to start
            time.sleep(2)
            
            # WiFi should already be connected (from Step 1), so no need to switch
            # Just verify WiFi is still connected
            try:
                result = subprocess.run(
                    ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    wifi_connected = any(
                        '802-11-wireless' in line and 'Hotspot' not in line 
                        for line in lines
                    )
                    if wifi_connected:
                        logger.info("WiFi connection verified - camera has internet access")
                    else:
                        logger.warning("No WiFi connection found - camera may not have internet")
            except Exception as e:
                logger.warning(f"Could not verify WiFi status: {e}")
            
            # Stop provisioning portal (no longer needed)
            # Delay to allow portal response to be sent first
            time.sleep(1)
            subprocess.run(["sudo", "systemctl", "stop", "provisioning-portal"], check=False)
            
            return jsonify({"status": "success", "cameraId": res['cameraId']})
        return jsonify({"status": "error", "message": r.text}), 400
    except Exception as e: 
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    if Path(CONFIG_PATH).exists(): sys.exit(0)
    # 1. Start Hotspot
    subprocess.run(["nmcli", "con", "up", "Hotspot"], check=False)
    # 2. WAIT for NetworkManager to settle
    time.sleep(3)
    # 3. Force IP
    subprocess.run(["sudo", "ifconfig", "wlan0", "192.168.4.1", "netmask", "255.255.255.0", "up"], check=False)
    # 4. Start Server
    app.run(host='0.0.0.0', port=80)
