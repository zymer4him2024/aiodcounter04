# REST API Integration for Camera Agent

The camera agent now supports REST API endpoints for remote start/stop control and can send counts to your custom backend.

## Features

1. **Start/Stop Detection** - Control detection via HTTP API
2. **Status Monitoring** - Get real-time detection status
3. **Backend Integration** - Send counts to your custom backend API (in addition to Firebase)
4. **Health Checks** - Monitor agent health

## Installation

### On Raspberry Pi

Install Flask and dependencies:

```bash
sudo pip3 install --break-system-packages Flask flask-cors requests
```

## API Endpoints

### Start Detection
```bash
POST http://<RPI_IP>:5000/api/detection/start
Content-Type: application/json

{
  "camera_id": "CAM_123",
  "backend_url": "https://your-backend.com",
  "api_key": "your-api-key",
  "report_interval": 5
}
```

### Stop Detection
```bash
POST http://<RPI_IP>:5000/api/detection/stop
```

### Get Status
```bash
GET http://<RPI_IP>:5000/api/detection/status
```

Response:
```json
{
  "success": true,
  "camera_id": "CAM_123",
  "status": "detecting",
  "agent_running": true,
  "fps": 15.2,
  "frames_processed": 1250,
  "runtime_seconds": 82.5,
  "detector_type": "hailo"
}
```

### Health Check
```bash
GET http://<RPI_IP>:5000/api/health
```

## Configuration

Update `/opt/camera-agent/config.json`:

```json
{
  "apiConfig": {
    "enabled": true,
    "port": 5000,
    "autoStart": false
  },
  ...
}
```

- `enabled`: Enable/disable REST API server
- `port`: Port for API server (default: 5000)
- `autoStart`: Auto-start detection when agent starts (default: false)

## Backend Integration

Your backend can call the RPi API to control detection:

### Start Detection
```javascript
const response = await axios.post(
  `http://${raspberryPiIp}:5000/api/detection/start`,
  {
    camera_id: cameraId,
    backend_url: 'https://your-backend.com',
    api_key: 'your-api-key',
    report_interval: 5
  }
);
```

### Receive Counts from RPi

The RPi will send counts to your backend at:
```
POST https://your-backend.com/api/detection/counts
```

Payload:
```json
{
  "camera_id": "CAM_123",
  "timestamp": "2025-12-29T19:00:00.000Z",
  "counts": {
    "all_person": {"in": 5, "out": 3},
    "all_vehicle": {"in": 2, "out": 1}
  },
  "total_objects": 11,
  "frames_processed": 150,
  "fps": 15.2,
  "runtime_seconds": 10
}
```

## Backend Routes

Use the provided `backend/routes/cameraRoutes.js` and `backend/controllers/cameraController.js`:

```javascript
// In your Express app
const cameraRoutes = require('./routes/cameraRoutes');
app.use('/api', cameraRoutes);
```

## Testing

### Test Start Detection
```bash
curl -X POST http://<RPI_IP>:5000/api/detection/start \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "CAM_123",
    "backend_url": "https://your-backend.com",
    "report_interval": 5
  }'
```

### Test Status
```bash
curl http://<RPI_IP>:5000/api/detection/status
```

### Test Stop
```bash
curl -X POST http://<RPI_IP>:5000/api/detection/stop
```

## Firewall Configuration

Ensure port 5000 is open on your RPi:

```bash
sudo ufw allow 5000/tcp
```

## Notes

- Detection can be inactive while the agent is running (for resource efficiency)
- Counts are sent to both Firebase (primary) and your backend (if configured)
- The agent continues running even when detection is stopped
- Use `autoStart: true` in config if you want detection to start automatically

