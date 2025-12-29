#!/usr/bin/env python3
import os, sys, json, time, subprocess, requests
from pathlib import Path
from flask import Flask, request, jsonify, render_template_string

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

# --- Apple-Style Portal with Token Details ---
PORTAL_HTML = """<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Camera Activation</title><style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#F5F5F7;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}
.card{background:white;padding:40px;border-radius:24px;box-shadow:0 10px 40px rgba(0,0,0,0.05);width:100%;max-width:440px;text-align:center}
h1{font-size:24px;font-weight:600;margin-bottom:8px;color:#1D1D1F}p{color:#86868B;margin-bottom:32px;font-size:15px}
.token-details{background:#E8F2FF;padding:16px;border-radius:14px;margin-bottom:24px;text-align:left;font-size:14px;display:none;border:1px solid #0071E3}
.token-details h3{font-size:14px;color:#0071E3;margin-bottom:8px}
.token-row{display:flex;justify-content:space-between;margin-bottom:4px}
.token-label{color:#86868B}.token-value{font-weight:600;color:#1D1D1F}
.info{background:#FBFBFD;padding:16px;border-radius:14px;margin-bottom:32px;text-align:left;font-size:13px;color:#424245}
input{width:100%;padding:16px;background:#F5F5F7;border:none;border-radius:12px;font-size:17px;margin-bottom:20px;text-align:center;font-family:monospace}
.btn{width:100%;padding:16px;background:#0071E3;color:white;border:none;border-radius:12px;font-size:17px;font-weight:600;cursor:pointer;transition:all 0.2s}
.btn:disabled{background:#E1E1E6;color:#86868B}
</style></head><body><div class="card"><h1>Activate Camera</h1><p>Connect this unit to your dashboard</p>
<div class="token-details" id="details">
    <h3>Token Information</h3>
    <div class="token-row"><span class="token-label">Name:</span><span class="token-value" id="det-name">-</span></div>
    <div class="token-row"><span class="token-label">Site:</span><span class="token-value" id="det-site">-</span></div>
</div>
<div class="info">Device: {{ hostname }}<br>Serial: {{ serial }}</div>
<form id="actForm"><input type="text" id="token" placeholder="PT_XXXXXXXX" value="{{ token }}" required>
<button type="submit" class="btn" id="btn">Activate Camera</button></form>
<div id="msg" style="margin-top:20px;font-size:14px"></div></div>
<script>
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
            msg.style.color = 'green'; msg.innerText = '✅ Activated! Camera ID: ' + data.cameraId;
            setTimeout(() => { window.location.reload(); }, 5000);
        } else {
            msg.style.color = 'red'; msg.innerText = '❌ ' + (data.message || 'Failed');
            btn.disabled = false; btn.innerText = 'Try Again';
        }
    } catch (err) { msg.innerText = 'Network error'; btn.disabled = false; }
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

@app.route('/activate', methods=['POST'])
def activate():
    try:
        data = request.get_json()
        payload = {"provisioningToken": data.get('token'), "deviceInfo": {"macAddress": sys_info['mac'], "serialNumber": sys_info['serial'], "hostname": sys_info['hostname']}}
        r = requests.post(PROVISION_SERVER, json=payload, timeout=20)
        if r.status_code == 200:
            res = r.json()
            with open(CONFIG_PATH, 'w') as f: json.dump(res['config'], f, indent=2)
            return jsonify({"status": "success", "cameraId": res['cameraId']})
        return jsonify({"status": "error", "message": r.text}), 400
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500

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
