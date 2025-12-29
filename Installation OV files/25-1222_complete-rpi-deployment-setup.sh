#!/bin/bash
################################################################################
# COMPLETE RPi DEPLOYMENT SETUP
# Run this on fresh Raspberry Pi OS to make it deployment-ready
# 
# This script installs:
# 1. Camera agent software (for object detection)
# 2. Web provisioning portal (for easy activation)
# 3. All dependencies and services
# 
# After running this, RPi is ready to ship to field installation
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║       COMPLETE RPi CAMERA DEPLOYMENT SETUP                     ║${NC}"
echo -e "${CYAN}║       Multi-Tier Object Detection System                       ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}✗ Please run as root: sudo $0${NC}"
  exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$(whoami)}

echo -e "${BLUE}═══ PART 1: SYSTEM SETUP ═══${NC}"
echo ""

echo -e "${YELLOW}[1/12] Updating system packages...${NC}"
apt update && apt upgrade -y
echo -e "${GREEN}✓ System updated${NC}"

echo -e "${YELLOW}[2/12] Installing system dependencies...${NC}"
apt install -y \
  python3 \
  python3-pip \
  python3-venv \
  python3-full \
  python3-opencv \
  git \
  curl \
  wget \
  libatlas-base-dev \
  libhdf5-dev \
  sqlite3 \
  v4l-utils \
  network-manager \
  dnsmasq \
  hostapd
echo -e "${GREEN}✓ System dependencies installed${NC}"

echo ""
echo -e "${BLUE}═══ PART 2: CAMERA AGENT SETUP ═══${NC}"
echo ""

echo -e "${YELLOW}[3/12] Creating application directories...${NC}"
mkdir -p /opt/camera-agent/{models,venv}
mkdir -p /var/log/camera-agent
mkdir -p /var/lib/camera-agent
chown -R $ACTUAL_USER:$ACTUAL_USER /opt/camera-agent /var/log/camera-agent /var/lib/camera-agent
echo -e "${GREEN}✓ Directories created${NC}"

echo -e "${YELLOW}[4/12] Creating Python virtual environment...${NC}"
cd /opt/camera-agent
python3 -m venv venv
echo -e "${GREEN}✓ Virtual environment created${NC}"

echo -e "${YELLOW}[5/12] Installing Python packages...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install firebase-admin sqlalchemy flask requests
deactivate
echo -e "${GREEN}✓ Python packages installed${NC}"

echo -e "${YELLOW}[6/12] Creating camera agent placeholder...${NC}"
cat > /opt/camera-agent/camera_agent.py << 'AGENT_EOF'
#!/usr/bin/env python3
"""
Camera Agent Placeholder
Replace this with your actual camera_agent.py code
"""
import sys
import time
import json
from pathlib import Path

CONFIG_PATH = "/opt/camera-agent/config.json"

def main():
    print("Camera Agent Starting...")
    
    # Check for config
    if not Path(CONFIG_PATH).exists():
        print("ERROR: No config.json found. Camera not activated.")
        sys.exit(1)
    
    # Load config
    with open(CONFIG_PATH, 'r') as f:
        config = json.load(f)
    
    camera_id = config.get('cameraId', 'UNKNOWN')
    print(f"Camera ID: {camera_id}")
    print("Camera agent running (placeholder mode)")
    
    # Keep running
    while True:
        time.sleep(60)
        print(f"[{camera_id}] Agent heartbeat")

if __name__ == "__main__":
    main()
AGENT_EOF
chmod +x /opt/camera-agent/camera_agent.py
echo -e "${GREEN}✓ Camera agent placeholder created${NC}"
echo -e "${YELLOW}  NOTE: Replace /opt/camera-agent/camera_agent.py with your actual code${NC}"

echo -e "${YELLOW}[7/12] Creating camera agent systemd service...${NC}"
cat > /etc/systemd/system/camera-agent.service << SERVICE_EOF
[Unit]
Description=Camera Edge Agent for Object Detection
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$ACTUAL_USER
Group=$ACTUAL_USER
WorkingDirectory=/opt/camera-agent
Environment="PATH=/opt/camera-agent/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/opt/camera-agent/venv/bin/python /opt/camera-agent/camera_agent.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=camera-agent

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable camera-agent.service
echo -e "${GREEN}✓ Camera agent service created${NC}"

echo ""
echo -e "${BLUE}═══ PART 3: PROVISIONING PORTAL SETUP ═══${NC}"
echo ""

echo -e "${YELLOW}[8/12] Installing provisioning portal...${NC}"
cat > /opt/camera-agent/provisioning_portal.py << 'PORTAL_EOF'
#!/usr/bin/env python3
import os, sys, json, time, subprocess, logging
from pathlib import Path
from flask import Flask, request, jsonify, render_template_string
import requests

CONFIG_PATH = "/opt/camera-agent/config.json"
PROVISION_SERVER = "https://provision.yourcompany.com/api/v1/provision"
HOTSPOT_SSID_PREFIX = "Camera-Setup"
HOTSPOT_PASSWORD = "Activate2025"

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler('/var/log/camera-agent/provisioning.log'), logging.StreamHandler()])
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
<input type="text" id="token" name="token" placeholder="PT_XXXXXXXXXX" required>
<p class="help-text">Enter token from QR code sticker</p></div>
<button type="submit" class="btn" id="activate-btn">🚀 Activate Camera</button></form>
<div id="status" class="status"></div><div class="footer"><p>WiFi: {{ ssid }}</p><p>Portal closes after activation</p></div></div>
<script>function showStatus(msg,type){const s=document.getElementById('status');s.className='status '+type;s.style.display='block';
if(type==='loading'){s.innerHTML='<div class="spinner"></div>'+msg}else{s.innerHTML=(type==='success'?'✓ ':'✗ ')+msg}}
document.getElementById('activation-form').addEventListener('submit',async(e)=>{e.preventDefault();const token=document.getElementById('token').value.trim();
const btn=document.getElementById('activate-btn');if(!token){showStatus('Please enter token','error');return}
btn.disabled=true;btn.textContent='⏳ Activating...';showStatus('Activating camera...','loading');document.getElementById('status-text').textContent='Activating...';
try{const res=await fetch('/activate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token})});
const result=await res.json();if(res.ok&&result.status==='success'){showStatus('Camera activated! ID: '+result.cameraId,'success');
document.getElementById('status-text').textContent='Online ✓';btn.textContent='✓ Activated';
setTimeout(()=>{window.location.href='/complete'},5000)}else{showStatus(result.message||'Activation failed','error');btn.disabled=false;btn.textContent='🚀 Activate Camera'}}
catch(error){showStatus('Network error','error');btn.disabled=false;btn.textContent='🚀 Activate Camera'}});document.getElementById('token').focus();</script></body></html>"""

COMPLETE_HTML = """<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Complete</title><style>
body{font-family:sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.container{background:white;border-radius:20px;padding:60px 40px;text-align:center;max-width:500px}
.checkmark{width:80px;height:80px;border-radius:50%;background:#28a745;margin:0 auto 30px;display:flex;align-items:center;justify-content:center;font-size:50px;color:white}
h1{color:#333;margin-bottom:20px}p{color:#666;line-height:1.6}</style></head><body><div class="container">
<div class="checkmark">✓</div><h1>Camera Activated!</h1><p><strong>Camera ID:</strong> {{ camera_id }}</p>
<p>WiFi hotspot will close shortly.</p><p>You can close this window.</p></div></body></html>"""

class ProvisioningPortal:
    def __init__(self):
        self.device_info = self.get_device_info()
        self.hotspot_ssid = f"{HOTSPOT_SSID_PREFIX}-{self.device_info['hostname_short']}"
    def get_device_info(self):
        try:
            mac = subprocess.check_output("cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/wlan0/address", shell=True).decode().strip().upper()
            serial = subprocess.check_output("cat /proc/cpuinfo | grep Serial | awk '{print $3}'", shell=True).decode().strip()
            hostname = subprocess.check_output("hostname", shell=True).decode().strip()
            return {"macAddress": mac, "serialNumber": serial, "hostname": hostname, "hostname_short": hostname.split('.')[0][:8]}
        except: return {"macAddress": "UNKNOWN", "serialNumber": "UNKNOWN", "hostname": "camera", "hostname_short": "camera"}
    def create_hotspot(self):
        logger.info(f"Creating hotspot: {self.hotspot_ssid}")
        try:
            subprocess.run(["nmcli", "connection", "down", "Hotspot"], stderr=subprocess.DEVNULL)
            subprocess.run(["nmcli", "connection", "delete", "Hotspot"], stderr=subprocess.DEVNULL)
            result = subprocess.run(["nmcli", "device", "wifi", "hotspot", "ssid", self.hotspot_ssid, "password", HOTSPOT_PASSWORD, "con-name", "Hotspot"], capture_output=True, text=True)
            if result.returncode == 0:
                logger.info(f"✓ Hotspot: {self.hotspot_ssid} / {HOTSPOT_PASSWORD}")
                return True
            logger.error(f"Failed: {result.stderr}")
            return False
        except Exception as e:
            logger.error(f"Exception: {e}")
            return False
    def stop_hotspot(self):
        subprocess.run(["nmcli", "connection", "down", "Hotspot"], stderr=subprocess.DEVNULL)
        subprocess.run(["nmcli", "connection", "delete", "Hotspot"], stderr=subprocess.DEVNULL)
    def activate_camera(self, token):
        logger.info(f"Activating: {token}")
        try:
            response = requests.post(PROVISION_SERVER, json={"provisioningToken": token, "deviceInfo": self.device_info}, timeout=30, verify=True)
            if response.status_code == 200:
                result = response.json()
                config = result.get('config')
                camera_id = result.get('cameraId')
                if config:
                    Path(CONFIG_PATH).parent.mkdir(parents=True, exist_ok=True)
                    with open(CONFIG_PATH, 'w') as f: json.dump(config, f, indent=2)
                    os.chmod(CONFIG_PATH, 0o600)
                    logger.info(f"✓ Config saved: {camera_id}")
                    subprocess.run(["systemctl", "enable", "camera-agent"])
                    subprocess.run(["systemctl", "start", "camera-agent"])
                    return {"success": True, "cameraId": camera_id, "message": "Camera activated"}
                return {"success": False, "message": "Invalid response"}
            return {"success": False, "message": f"Error: {response.text}"}
        except Exception as e:
            return {"success": False, "message": str(e)}

portal = ProvisioningPortal()

@app.route('/')
def index():
    return render_template_string(PORTAL_HTML, hostname=portal.device_info['hostname'], 
        mac_address=portal.device_info['macAddress'], serial_number=portal.device_info['serialNumber'], ssid=portal.hotspot_ssid)

@app.route('/activate', methods=['POST'])
def activate():
    data = request.get_json()
    token = data.get('token', '').strip()
    if not token: return jsonify({"status": "error", "message": "Token required"}), 400
    result = portal.activate_camera(token)
    if result['success']:
        import threading
        def shutdown(): time.sleep(15); portal.stop_hotspot()
        threading.Thread(target=shutdown, daemon=True).start()
        return jsonify({"status": "success", "cameraId": result['cameraId'], "message": result['message']})
    return jsonify({"status": "error", "message": result['message']}), 400

@app.route('/complete')
def complete():
    camera_id = "Unknown"
    try:
        if Path(CONFIG_PATH).exists():
            with open(CONFIG_PATH) as f: camera_id = json.load(f).get('cameraId', 'Unknown')
    except: pass
    return render_template_string(COMPLETE_HTML, camera_id=camera_id)

def main():
    if Path(CONFIG_PATH).exists():
        logger.info("Already configured - exiting")
        sys.exit(0)
    logger.info("="*60)
    logger.info("PROVISIONING PORTAL STARTING")
    logger.info("="*60)
    if not portal.create_hotspot():
        logger.error("Failed to create hotspot")
        sys.exit(1)
    logger.info("")
    logger.info("="*60)
    logger.info("PORTAL READY")
    logger.info(f"WiFi: {portal.hotspot_ssid}")
    logger.info(f"Password: {HOTSPOT_PASSWORD}")
    logger.info("URL: http://192.168.4.1")
    logger.info("="*60)
    try: app.run(host='0.0.0.0', port=80, debug=False)
    except KeyboardInterrupt: portal.stop_hotspot()
    except Exception as e: logger.error(f"Error: {e}"); portal.stop_hotspot(); sys.exit(1)

if __name__ == "__main__": main()
PORTAL_EOF

chmod +x /opt/camera-agent/provisioning_portal.py
echo -e "${GREEN}✓ Provisioning portal installed${NC}"

echo -e "${YELLOW}[9/12] Creating provisioning portal service...${NC}"
cat > /etc/systemd/system/provisioning-portal.service << 'PORTAL_SERVICE_EOF'
[Unit]
Description=Camera Provisioning Portal
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/opt/camera-agent/config.json

[Service]
Type=simple
User=root
WorkingDirectory=/opt/camera-agent
ExecStart=/usr/bin/python3 /opt/camera-agent/provisioning_portal.py
Restart=no
StandardOutput=journal
StandardError=journal
SyslogIdentifier=provisioning-portal
RuntimeMaxSec=1800

[Install]
WantedBy=multi-user.target
PORTAL_SERVICE_EOF

systemctl daemon-reload
systemctl enable provisioning-portal.service
echo -e "${GREEN}✓ Provisioning portal service created${NC}"

echo ""
echo -e "${BLUE}═══ PART 4: HELPER SCRIPTS ═══${NC}"
echo ""

echo -e "${YELLOW}[10/12] Creating helper scripts...${NC}"

# Show info script
cat > /opt/camera-agent/show-info.sh << 'INFO_EOF'
#!/bin/bash
echo "═══════════════════════════════════════════════"
echo "      CAMERA DEVICE INFORMATION"
echo "═══════════════════════════════════════════════"
echo ""
echo "Hostname:       $(hostname)"
echo "IP Address:     $(hostname -I | awk '{print $1}')"
echo "MAC (eth0):     $(cat /sys/class/net/eth0/address 2>/dev/null || echo 'N/A')"
echo "MAC (wlan0):    $(cat /sys/class/net/wlan0/address 2>/dev/null || echo 'N/A')"
echo "Serial Number:  $(cat /proc/cpuinfo | grep Serial | awk '{print $3}')"
echo ""
echo "═══════════════════════════════════════════════"
echo "      SERVICE STATUS"
echo "═══════════════════════════════════════════════"
echo ""
echo -n "Camera Agent:        "
systemctl is-active camera-agent 2>/dev/null || echo "not started"
echo -n "Provisioning Portal: "
systemctl is-active provisioning-portal 2>/dev/null || echo "not started"
echo ""
if [ -f /opt/camera-agent/config.json ]; then
    echo "Configuration:   ✓ Activated"
    CAMERA_ID=$(cat /opt/camera-agent/config.json | grep -o '"cameraId"[^,]*' | cut -d'"' -f4)
    echo "Camera ID:       $CAMERA_ID"
else
    echo "Configuration:   ✗ Not activated (needs provisioning)"
fi
echo ""
INFO_EOF
chmod +x /opt/camera-agent/show-info.sh

# Deploy config script
cat > /opt/camera-agent/deploy-config.sh << 'DEPLOY_EOF'
#!/bin/bash
CONFIG_FILE="$1"

if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 <config.json>"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

echo "Deploying configuration..."
sudo cp "$CONFIG_FILE" /opt/camera-agent/config.json
sudo chmod 600 /opt/camera-agent/config.json

echo "Validating..."
python3 << PYEOF
import json
try:
    with open('/opt/camera-agent/config.json', 'r') as f:
        config = json.load(f)
    print(f"✓ Camera ID: {config.get('cameraId', 'Unknown')}")
    print(f"✓ Site ID: {config.get('siteId', 'Unknown')}")
except Exception as e:
    print(f"✗ Validation failed: {e}")
    exit(1)
PYEOF

if [ $? -eq 0 ]; then
    echo "Starting camera agent..."
    sudo systemctl enable camera-agent
    sudo systemctl restart camera-agent
    echo "✓ Deployment complete"
else
    echo "✗ Deployment failed"
    exit 1
fi
DEPLOY_EOF
chmod +x /opt/camera-agent/deploy-config.sh

echo -e "${GREEN}✓ Helper scripts created${NC}"

echo ""
echo -e "${BLUE}═══ PART 5: FINAL CONFIGURATION ═══${NC}"
echo ""

echo -e "${YELLOW}[11/12] Configuring NetworkManager...${NC}"
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/hotspot.conf << 'NM_EOF'
[main]
plugins=keyfile
NM_EOF
systemctl restart NetworkManager
echo -e "${GREEN}✓ NetworkManager configured${NC}"

echo -e "${YELLOW}[12/12] Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
  ufw allow 80/tcp
  ufw allow ssh
  echo -e "${GREEN}✓ Firewall configured${NC}"
else
  echo -e "${YELLOW}⚠ No firewall detected${NC}"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║              ✓ INSTALLATION COMPLETE!                          ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}═══ THIS RPi IS NOW DEPLOYMENT-READY! ═══${NC}"
echo ""
echo -e "${BLUE}What happens next:${NC}"
echo ""
echo -e "${YELLOW}1. BEFORE DEPLOYMENT:${NC}"
echo "   • Replace /opt/camera-agent/camera_agent.py with your actual code"
echo "   • Test activation with: sudo systemctl start provisioning-portal"
echo ""
echo -e "${YELLOW}2. ON FIRST BOOT (in the field):${NC}"
echo "   • RPi creates WiFi: Camera-Setup-XXXXXX"
echo "   • Password: Activate2025"
echo "   • Portal at: http://192.168.4.1"
echo ""
echo -e "${YELLOW}3. FIELD INSTALLER:${NC}"
echo "   • Connects to WiFi hotspot"
echo "   • Enters provisioning token"
echo "   • Camera activates automatically"
echo ""
echo -e "${GREEN}═══ USEFUL COMMANDS ═══${NC}"
echo ""
echo "Show device info:"
echo -e "  ${BLUE}/opt/camera-agent/show-info.sh${NC}"
echo ""
echo "Test provisioning portal:"
echo -e "  ${BLUE}sudo systemctl start provisioning-portal${NC}"
echo ""
echo "View portal logs:"
echo -e "  ${BLUE}sudo journalctl -u provisioning-portal -f${NC}"
echo ""
echo "View camera agent logs:"
echo -e "  ${BLUE}sudo journalctl -u camera-agent -f${NC}"
echo ""
echo "Deploy config manually:"
echo -e "  ${BLUE}/opt/camera-agent/deploy-config.sh /path/to/config.json${NC}"
echo ""
echo -e "${GREEN}═══ FILES INSTALLED ═══${NC}"
echo ""
echo "  /opt/camera-agent/camera_agent.py         (placeholder - replace with actual)"
echo "  /opt/camera-agent/provisioning_portal.py  (web activation portal)"
echo "  /opt/camera-agent/show-info.sh            (device information)"
echo "  /opt/camera-agent/deploy-config.sh        (manual config deployment)"
echo "  /opt/camera-agent/venv/                   (Python virtual environment)"
echo ""
echo "  /etc/systemd/system/camera-agent.service"
echo "  /etc/systemd/system/provisioning-portal.service"
echo ""
echo -e "${CYAN}Ready to ship and deploy!${NC}"
echo ""
