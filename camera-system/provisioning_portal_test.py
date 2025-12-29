#!/usr/bin/env python3
"""
Test Version of Provisioning Portal - Always Runs
Use this for testing even if camera is already configured
"""

import os
import sys
import json
import time
import subprocess
import logging
from pathlib import Path
from flask import Flask, request, jsonify, render_template_string
import requests

# Configuration
CONFIG_PATH = "/opt/camera-agent/config.json"
PROVISION_SERVER = "https://us-central1-aiodcouter04.cloudfunctions.net/provisionCamera"
HOTSPOT_SSID_PREFIX = "AIOD-Camera"
HOTSPOT_PASSWORD = "aiod2024"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

PORTAL_HTML = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Camera Activation</title><style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.container{background:white;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,0.3);max-width:500px;width:100%;padding:40px}
.logo{text-align:center;margin-bottom:30px}.logo h1{color:#667eea;font-size:28px;margin-bottom:10px}.logo p{color:#666;font-size:14px}
.device-info{background:#f8f9fa;border-radius:10px;padding:20px;margin-bottom:30px}.device-info h3{color:#333;font-size:16px;margin-bottom:15px}
.info-row{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid #e0e0e0}.info-row:last-child{border-bottom:none}
.info-label{color:#666;font-size:14px}.info-value{color:#333;font-weight:600;font-size:14px;font-family:monospace}
.form-group{margin-bottom:25px}label{display:block;color:#333;font-weight:600;margin-bottom:10px;font-size:14px}
input[type="text"]{width:100%;padding:15px;border:2px solid #e0e0e0;border-radius:10px;font-size:16px;font-family:monospace;transition:all 0.3s}
input[type="text"]:focus{outline:none;border-color:#667eea;box-shadow:0 0 0 3px rgba(102,126,234,0.1)}
.btn{width:100%;padding:15px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer;transition:transform 0.2s}
.btn:hover{transform:translateY(-2px)}.btn:disabled{background:#ccc;cursor:not-allowed}
.status{margin-top:20px;padding:15px;border-radius:10px;display:none}
.status.success{background:#d4edda;border:2px solid #28a745;color:#155724}
.status.error{background:#f8d7da;border:2px solid #dc3545;color:#721c24}
.status.loading{background:#d1ecf1;border:2px solid #17a2b8;color:#0c5460}
.spinner{border:3px solid #f3f3f3;border-top:3px solid #667eea;border-radius:50%;width:20px;height:20px;animation:spin 1s linear infinite;display:inline-block;margin-right:10px}
@keyframes spin{100%{transform:rotate(360deg)}}.help-text{color:#666;font-size:13px;margin-top:8px}.footer{margin-top:30px;text-align:center;color:#999;font-size:12px}
</style></head><body><div class="container"><div class="logo"><h1>📹 Camera Activation</h1><p>Multi-Tier Object Detection System</p></div>
<div class="device-info"><h3>Device Information</h3>
<div class="info-row"><span class="info-label">Hostname:</span><span class="info-value">{{ hostname }}</span></div>
<div class="info-row"><span class="info-label">MAC:</span><span class="info-value">{{ mac_address }}</span></div>
<div class="info-row"><span class="info-label">Serial:</span><span class="info-value">{{ serial_number }}</span></div>
<div class="info-row"><span class="info-label">Status:</span><span class="info-value" id="status-text">Waiting</span></div></div>
<form id="activation-form"><div class="form-group"><label for="token">Provisioning Token</label>
<input type="text" id="token" name="token" placeholder="PT_XXXXXXXXXX" value="{{ token }}" required>
<p class="help-text">Enter token from QR code sticker</p></div>
<button type="submit" class="btn" id="activate-btn">🚀 Activate Camera</button></form>
<div id="status" class="status"></div><div class="footer"><p>WiFi: {{ ssid }}</p><p>Portal closes after activation</p></div></div>
<script>
// Auto-fill token from URL if present
(function() {
    const urlParams = new URLSearchParams(window.location.search);
    const tokenParam = urlParams.get('token');
    if (tokenParam) {
        document.getElementById('token').value = tokenParam;
    }
})();

function showStatus(msg,type){const s=document.getElementById('status');s.className='status '+type;s.style.display='block';
if(type==='loading'){s.innerHTML='<div class="spinner"></div>'+msg}else{s.innerHTML=(type==='success'?'✓ ':'✗ ')+msg}}
document.getElementById('activation-form').addEventListener('submit',async(e)=>{e.preventDefault();const token=document.getElementById('token').value.trim();
const btn=document.getElementById('activate-btn');if(!token){showStatus('Please enter token','error');return}
btn.disabled=true;btn.textContent='⏳ Activating...';showStatus('Activating camera...','loading');document.getElementById('status-text').textContent='Activating...';
try{const res=await fetch('/activate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token})});
const result=await res.json();if(res.ok&&result.status==='success'){showStatus('Camera activated! ID: '+result.cameraId,'success');
document.getElementById('status-text').textContent='Online ✓';btn.textContent='✓ Activated';
setTimeout(()=>{window.location.href='/complete'},5000)}else{showStatus(result.message||'Activation failed','error');btn.disabled=false;btn.textContent='🚀 Activate Camera'}}
catch(error){showStatus('Network error: '+error.message,'error');btn.disabled=false;btn.textContent='🚀 Activate Camera'}});
document.getElementById('token').focus();
</script></body></html>"""

COMPLETE_HTML = """<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Complete</title><style>
body{font-family:sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.container{background:white;border-radius:20px;padding:60px 40px;text-align:center;max-width:500px}
.checkmark{width:80px;height:80px;border-radius:50%;background:#28a745;margin:0 auto 30px;display:flex;align-items:center;justify-content:center;font-size:50px;color:white}
h1{color:#333;margin-bottom:20px}p{color:#666;line-height:1.6}</style></head><body><div class="container">
<div class="checkmark">✓</div><h1>Camera Activated!</h1><p><strong>Camera ID:</strong> {{ camera_id }}</p>
<p>WiFi hotspot will close shortly.</p><p>You can close this window.</p></div></body></html>"""


def get_device_info():
    try:
        mac = subprocess.check_output("cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/wlan0/address", shell=True).decode().strip().upper()
        serial = subprocess.check_output("cat /proc/cpuinfo | grep Serial | awk '{print $3}'", shell=True).decode().strip()
        hostname = subprocess.check_output("hostname", shell=True).decode().strip()
        return {
            "macAddress": mac, 
            "serialNumber": serial, 
            "hostname": hostname, 
            "hostname_short": hostname.split('.')[0][:8]
        }
    except Exception as e:
        logger.error(f"Error getting device info: {e}")
        return {
            "macAddress": "UNKNOWN", 
            "serialNumber": "UNKNOWN", 
            "hostname": "camera", 
            "hostname_short": "camera"
        }

device_info = get_device_info()
hotspot_ssid = f"{HOTSPOT_SSID_PREFIX}-{device_info['hostname_short']}"

@app.route('/')
def index():
    token = request.args.get('token', '')
    return render_template_string(
        PORTAL_HTML, 
        hostname=device_info['hostname'], 
        mac_address=device_info['macAddress'], 
        serial_number=device_info['serialNumber'], 
        ssid=hotspot_ssid,
        token=token
    )

@app.route('/activate', methods=['POST'])
def activate():
    data = request.get_json()
    token = data.get('token', '').strip()
    if not token:
        return jsonify({"status": "error", "message": "Token required"}), 400
    
    # Call Firebase function
    try:
        response = requests.post(
            PROVISION_SERVER, 
            json={
                "provisioningToken": token, 
                "deviceInfo": device_info
            }, 
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            config = result.get('config')
            camera_id = result.get('cameraId')
            
            if config:
                Path(CONFIG_PATH).parent.mkdir(parents=True, exist_ok=True)
                with open(CONFIG_PATH, 'w') as f:
                    json.dump(config, f, indent=2)
                os.chmod(CONFIG_PATH, 0o600)
                logger.info(f"✓ Config saved: {camera_id}")
                return jsonify({
                    "status": "success", 
                    "cameraId": camera_id, 
                    "message": "Camera activated"
                })
        return jsonify({"status": "error", "message": f"Error: {response.text}"}), 400
    except Exception as e:
        logger.error(f"Activation error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 400

@app.route('/complete')
def complete():
    camera_id = "Unknown"
    try:
        if Path(CONFIG_PATH).exists():
            with open(CONFIG_PATH) as f:
                camera_id = json.load(f).get('cameraId', 'Unknown')
    except:
        pass
    return render_template_string(COMPLETE_HTML, camera_id=camera_id)

if __name__ == "__main__":
    print("=" * 60)
    print("TEST PROVISIONING PORTAL")
    print("=" * 60)
    print(f"Hostname: {device_info['hostname']}")
    print(f"MAC: {device_info['macAddress']}")
    print(f"Hotspot: {hotspot_ssid}")
    print("")
    print("Starting Flask on port 5000...")
    print("Access at: http://192.168.4.1:5000")
    print("Or: http://localhost:5000")
    print("=" * 60)
    print("")
    
    # Run on port 5000 (doesn't require root)
    app.run(host='0.0.0.0', port=5000, debug=True)


