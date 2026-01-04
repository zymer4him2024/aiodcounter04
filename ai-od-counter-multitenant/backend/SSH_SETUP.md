# SSH Connection Setup - Backend to Raspberry Pi

This document explains how the backend server connects to Raspberry Pi devices via SSH for remote management.

## Overview

The backend can now execute commands directly on Raspberry Pi devices via SSH, eliminating the need to manually SSH into each device. This enables:

- Remote command execution
- Service management (start/stop/restart)
- Log retrieval
- System information gathering
- File operations

## Setup

### 1. Generate SSH Key (Already Done)

The SSH key has been generated and configured. The key is located at:
```
backend/.ssh/id_ed25519
```

### 2. Environment Variables

Add these to your `.env` file:

```env
# SSH Configuration for RPi
RPI_SSH_USER=digioptics_od
RPI_SSH_PORT=22
RPI_SSH_KEY_PATH=./.ssh/id_ed25519
RASPBERRY_PI_IP=192.168.0.214
```

### 3. Verify Connection

Test the SSH connection:

```bash
cd backend
ssh -i ./.ssh/id_ed25519 digioptics_od@192.168.0.214 'echo "Connection successful!"'
```

## API Endpoints

### Execute SSH Command

Execute any command on the RPi:

```http
POST /api/cameras/:id/ssh/execute
Content-Type: application/json

{
  "command": "systemctl status camera-agent",
  "raspberryPiIp": "192.168.0.214",
  "raspberryPiUser": "digioptics_od"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "stdout": "active (running)...",
    "stderr": "",
    "exitCode": 0
  }
}
```

### Get System Information

Retrieve system information from RPi:

```http
GET /api/cameras/:id/ssh/system-info?raspberryPiIp=192.168.0.214
```

**Response:**
```json
{
  "success": true,
  "data": {
    "hostname": "ShawnRaspberryPi",
    "uptime": "35 min",
    "disk": "/dev/root  15G  5.2G  8.8G  38% /",
    "memory": "3.8Gi 200Mi 3.6Gi",
    "load": "0.00, 0.07, 0.20",
    "camera_agent_running": true
  }
}
```

### Get Service Logs

Retrieve logs from a service on RPi:

```http
GET /api/cameras/:id/ssh/logs?service=camera-agent&lines=100&raspberryPiIp=192.168.0.214
```

**Response:**
```json
{
  "success": true,
  "data": {
    "service": "camera-agent",
    "lines": 100,
    "logs": "-- Logs begin at ..."
  }
}
```

### Restart Service

Restart a service on RPi:

```http
POST /api/cameras/:id/ssh/restart-service
Content-Type: application/json

{
  "service": "camera-agent",
  "raspberryPiIp": "192.168.0.214"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Service camera-agent restarted",
  "data": {
    "service": "camera-agent",
    "restarted": true
  }
}
```

## Usage Examples

### Using SSHClient in Code

```javascript
const SSHClient = require('./utils/sshClient');

// Create SSH client
const sshClient = new SSHClient({
  host: '192.168.0.214',
  user: 'digioptics_od'
});

// Execute command
const result = await sshClient.execute('ls -la /opt/camera-agent');
console.log(result.stdout);

// Check service status
const isRunning = await sshClient.isServiceRunning('camera-agent');

// Get logs
const logs = await sshClient.getServiceLogs('camera-agent', 50);

// Restart service
const restartResult = await sshClient.restartService('camera-agent');
```

## Security Notes

1. **SSH Key Security**: The private key (`id_ed25519`) should be kept secure and never committed to version control.

2. **Permissions**: The `.ssh` directory should have `700` permissions, and the key file should have `600` permissions.

3. **Host Key Verification**: By default, strict host key checking is disabled for convenience. In production, consider enabling it.

4. **Sudo Commands**: Some commands require sudo. Ensure the SSH user has passwordless sudo configured for necessary commands.

## Troubleshooting

### Connection Fails

1. Verify RPi is reachable:
   ```bash
   ping 192.168.0.214
   ```

2. Test SSH manually:
   ```bash
   ssh -i ./.ssh/id_ed25519 digioptics_od@192.168.0.214
   ```

3. Check key permissions:
   ```bash
   chmod 600 ./.ssh/id_ed25519
   chmod 700 ./.ssh
   ```

### Permission Denied

1. Verify the public key is in RPi's `~/.ssh/authorized_keys`:
   ```bash
   ssh digioptics_od@192.168.0.214 'cat ~/.ssh/authorized_keys'
   ```

2. Check RPi SSH permissions:
   ```bash
   ssh digioptics_od@192.168.0.214 'ls -la ~/.ssh'
   ```

### Sudo Commands Fail

Ensure passwordless sudo is configured on RPi:

```bash
# On RPi, edit sudoers
sudo visudo

# Add this line (replace with your user)
digioptics_od ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart camera-agent, /usr/bin/journalctl -u camera-agent*
```

## Re-running Setup

If you need to regenerate the SSH key or set it up again:

```bash
cd backend
bash scripts/setup-ssh-key.sh
```

Or manually:

```bash
# Generate key
ssh-keygen -t ed25519 -f ./.ssh/id_ed25519 -N "" -C "backend@$(hostname)"

# Copy to RPi
ssh-copy-id -i ./.ssh/id_ed25519.pub digioptics_od@192.168.0.214
```

