# Raspberry Pi Camera Agent API Testing Guide

## Quick Test Commands

All commands assume the RPi is accessible at `192.168.0.214:5000`. Adjust the IP address as needed.

### 1. Health Check

```bash
# Root health endpoint
curl http://192.168.0.214:5000/health

# API health endpoint (alternative)
curl http://192.168.0.214:5000/api/health
```

**Expected Response:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 2. Start Detection

```bash
curl -X POST http://192.168.0.214:5000/api/detection/start \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "camera_001",
    "backend_url": "https://your-backend.com",
    "api_key": "your_api_key",
    "report_interval": 5
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Detection started",
  "camera_id": "camera_001",
  "status": "detecting",
  "started_at": "2024-01-01T12:00:00Z"
}
```

**What happens:**
- Camera agent starts if not running
- Detection threads activate
- Backend URL configured for sending counts
- YOLOv8 inference begins on Hailo-8/TFLite

### 3. Check Detection Status

```bash
curl http://192.168.0.214:5000/api/detection/status
```

**Expected Response:**
```json
{
  "success": true,
  "camera_id": "camera_001",
  "status": "detecting",
  "agent_running": true,
  "started_at": "2024-01-01T12:00:00Z",
  "fps": 30.0,
  "frames_processed": 150,
  "runtime_seconds": 5.0,
  "detector_type": "hailo"
}
```

### 4. Stop Detection

```bash
curl -X POST http://192.168.0.214:5000/api/detection/stop
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Detection stopped",
  "status": "idle",
  "stopped_at": "2024-01-01T12:00:05Z"
}
```

**What happens:**
- Detection threads deactivate
- Final counts sent to backend
- Camera agent continues running (ready for next start)

### 5. Get Configuration

```bash
curl http://192.168.0.214:5000/api/config
```

**Expected Response:**
```json
{
  "success": true,
  "config": {
    "cameraId": "camera_001",
    "siteId": "site_001",
    "deviceId": "rpi-001",
    "detectionConfig": {
      "objectClasses": ["person", "car", "bicycle"],
      "confidenceThreshold": 0.5
    }
  }
}
```

## Integration with Backend

### Backend Calls RPi

When the frontend toggles detection ON, the backend will:

1. Call RPi start endpoint:
```javascript
POST http://192.168.0.214:5000/api/detection/start
{
  "camera_id": "camera_001",
  "backend_url": "https://your-backend.com",
  "api_key": "secret_key",
  "report_interval": 5
}
```

2. RPi responds with success

3. RPi starts sending counts every 5 seconds:
```javascript
POST https://your-backend.com/api/detection/counts
{
  "camera_id": "camera_001",
  "timestamp": "2024-01-01T12:00:05Z",
  "counts": {"person": 5, "car": 2},
  "total_objects": 7,
  "frames_processed": 150,
  "fps": 30.0,
  "runtime_seconds": 5.0
}
```

4. Backend saves to database and broadcasts via WebSocket

### Troubleshooting

#### RPi Not Responding
```bash
# Check if service is running
sudo systemctl status camera-agent

# Check logs
tail -f /var/log/camera_agent.log

# Test connectivity
ping 192.168.0.214
```

#### Detection Not Starting
```bash
# Check camera connection
lsusb | grep -i camera

# Check model file
ls -lh /opt/camera-agent/models/yolov8n.hef

# Check Hailo-8 (if using)
hailortcli scan-devices
```

#### Counts Not Reaching Backend
```bash
# Check backend URL is accessible from RPi
curl https://your-backend.com/health

# Check RPi can reach backend
curl -X POST https://your-backend.com/api/detection/counts \
  -H "Content-Type: application/json" \
  -d '{"camera_id": "test"}'

# Check backend logs
# Look for POST /api/detection/counts requests
```

## Test Script

Create a test script `test_rpi_api.sh`:

```bash
#!/bin/bash

RPI_IP="192.168.0.214"
RPI_PORT="5000"
BASE_URL="http://${RPI_IP}:${RPI_PORT}"

echo "=== Testing RPi Camera Agent API ==="
echo ""

echo "1. Health Check..."
curl -s "${BASE_URL}/health" | jq .
echo ""

echo "2. Get Config..."
curl -s "${BASE_URL}/api/config" | jq .
echo ""

echo "3. Start Detection..."
curl -s -X POST "${BASE_URL}/api/detection/start" \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "test_camera",
    "backend_url": "https://your-backend.com",
    "api_key": "test_key",
    "report_interval": 5
  }' | jq .
echo ""

sleep 3

echo "4. Check Status..."
curl -s "${BASE_URL}/api/detection/status" | jq .
echo ""

sleep 5

echo "5. Check Status Again..."
curl -s "${BASE_URL}/api/detection/status" | jq .
echo ""

echo "6. Stop Detection..."
curl -s -X POST "${BASE_URL}/api/detection/stop" | jq .
echo ""

echo "=== Test Complete ==="
```

Make it executable and run:
```bash
chmod +x test_rpi_api.sh
./test_rpi_api.sh
```

