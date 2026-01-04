# System Architecture Documentation

## Complete System Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    AIOD COUNTER SYSTEM FLOW                     │
└─────────────────────────────────────────────────────────────────┘

1. User toggles switch ON in frontend
   ↓
2. Frontend → Backend: POST /api/cameras/123/detection/start
   ↓
3. Backend → RPi: POST http://192.168.0.214:5000/api/detection/start
   {
     "camera_id": "camera_001",
     "backend_url": "https://your-backend.com",
     "api_key": "your_api_key",
     "report_interval": 5
   }
   ↓
4. RPi starts YOLOv8 detection with Hailo-8 HAT
   - Camera agent activates detection threads
   - Object detection runs on Hailo-8 accelerator
   - Frames processed at ~30 FPS
   ↓
5. Every 5 seconds, RPi → Backend: POST /api/detection/counts
   {
     "camera_id": "camera_001",
     "timestamp": "2024-01-01T12:00:00Z",
     "counts": {"person": 5, "car": 2},
     "total_objects": 7,
     "frames_processed": 150,
     "fps": 30.0,
     "runtime_seconds": 5.0
   }
   ↓
6. Backend saves to database (PostgreSQL or Firestore)
   - Stores in detection_logs table
   - Updates camera status
   ↓
7. Backend → Frontend (WebSocket): Real-time count updates
   - Socket.IO emits 'detection_counts' event
   - Frontend receives live data
   ↓
8. User sees live object counts in UI
   - Counts update every 5 seconds
   - Visual indicators for active detection
   ↓
9. User toggles switch OFF
   ↓
10. Frontend → Backend: POST /api/cameras/123/detection/stop
    ↓
11. Backend → RPi: POST http://192.168.0.214:5000/api/detection/stop
    ↓
12. RPi stops detection and sends final counts
    - Detection threads deactivated
    - Final statistics sent to backend
```

## Component Architecture

### Raspberry Pi (Edge Device)

**Location:** `camera-system/`

#### Files:
- `camera_agent.py` - Main camera agent with detection logic
- `camera_agent_api.py` - REST API server (Flask)
- `generate_config.py` - Configuration generator

#### API Endpoints (Port 5000):

```bash
# Health check
GET /health
GET /api/health

# Start detection
POST /api/detection/start
Body: {
  "camera_id": "camera_001",
  "backend_url": "https://your-backend.com",
  "api_key": "your_api_key",
  "report_interval": 5
}

# Check status
GET /api/detection/status

# Stop detection
POST /api/detection/stop

# Get configuration
GET /api/config
```

#### Detection Pipeline:
1. **Capture Thread** - Captures frames from USB camera/RTSP (15 FPS)
2. **Detection Thread** - Runs YOLOv8 inference on Hailo-8 or TFLite
3. **Counting Thread** - Tracks objects, aggregates counts per zone
4. **Upload Thread** - Sends counts to backend every N seconds
5. **Status Thread** - Updates camera status in Firestore

### Backend Server

**Location:** `ai-od-counter-multitenant/backend/`

#### API Endpoints (Port 3001):

```bash
# Start detection (called by frontend)
POST /api/cameras/:id/detection/start
Body: {
  "raspberryPiIp": "192.168.0.214"  // optional
}

# Stop detection (called by frontend)
POST /api/cameras/:id/detection/stop

# Get detection status
GET /api/cameras/:id/detection/status

# Health check
GET /api/rpi/health?cameraId=123&raspberryPiIp=192.168.0.214

# Receive counts (called by RPi)
POST /api/detection/counts
Body: {
  "camera_id": "camera_001",
  "timestamp": "2024-01-01T12:00:00Z",
  "counts": {"person": 5, "car": 2},
  "total_objects": 7,
  "frames_processed": 150,
  "fps": 30.0,
  "runtime_seconds": 5.0
}

# Backend health
GET /health
```

#### Database Storage:

**PostgreSQL** (when `USE_POSTGRES=true`):
- `detection_logs` table - All detection count data
- `cameras` table - Camera configuration and status
- Models: `database/models.js`

**Firestore** (default or dual storage):
- `detectionLogs` collection - Detection count documents
- `cameras` collection - Camera documents

#### Real-time Updates:

**WebSocket (Socket.IO):**
- Clients join room: `camera_${cameraId}`
- Backend emits: `detection_counts` event
- Frontend subscribes to real-time updates

### Frontend Dashboard

**Location:** `ai-od-counter-multitenant/web-dashboard/`

#### Features:
- Toggle detection on/off per camera
- Real-time count display via WebSocket
- Camera status monitoring
- Historical data visualization

## Data Flow Diagram

```
┌─────────────┐
│   Frontend  │
│  (React)    │
└──────┬──────┘
       │ HTTP REST API
       ↓
┌──────────────────────────────────────┐
│         Backend Server               │
│  ┌────────────────────────────────┐  │
│  │  Express.js API Routes         │  │
│  │  - /api/cameras/:id/*          │  │
│  └──────────┬─────────────────────┘  │
│             │                         │
│  ┌──────────▼─────────────────────┐  │
│  │  CameraDetectionController     │  │
│  └──────┬──────────────────┬──────┘  │
│         │                  │          │
│         │                  │          │
│  ┌──────▼──────┐   ┌──────▼──────┐  │
│  │ PostgreSQL  │   │  Firestore  │  │
│  │   Models    │   │  Database   │  │
│  └─────────────┘   └─────────────┘  │
│                                     │
│  ┌────────────────────────────────┐  │
│  │  Socket.IO Server              │  │
│  │  (Real-time WebSocket)         │  │
│  └────────────────────────────────┘  │
└───────────┬──────────────────────────┘
            │ HTTP REST API
            ↓
┌──────────────────────────────────────┐
│      Raspberry Pi (Edge)             │
│  ┌────────────────────────────────┐  │
│  │  Camera Agent API (Flask)      │  │
│  │  - /api/detection/start        │  │
│  │  - /api/detection/stop         │  │
│  │  - /api/detection/status       │  │
│  └──────────┬─────────────────────┘  │
│             │                         │
│  ┌──────────▼─────────────────────┐  │
│  │  CameraEdgeAgent               │  │
│  │  - Capture Thread              │  │
│  │  - Detection Thread (Hailo-8)  │  │
│  │  - Counting Thread             │  │
│  │  - Upload Thread               │  │
│  └──────────┬─────────────────────┘  │
│             │                         │
│  ┌──────────▼─────────────────────┐  │
│  │  USB Camera / RTSP Stream      │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

## Testing the Integration

### 1. Test RPi API Directly

```bash
# Health check
curl http://192.168.0.214:5000/health

# Start detection
curl -X POST http://192.168.0.214:5000/api/detection/start \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "camera_001",
    "backend_url": "https://your-backend.com",
    "api_key": "your_api_key",
    "report_interval": 5
  }'

# Check status
curl http://192.168.0.214:5000/api/detection/status

# Stop detection
curl -X POST http://192.168.0.214:5000/api/detection/stop
```

### 2. Test Backend API

```bash
# Start detection via backend
curl -X POST http://localhost:3001/api/cameras/camera_001/detection/start \
  -H "Content-Type: application/json"

# Check status
curl http://localhost:3001/api/cameras/camera_001/detection/status

# Stop detection
curl -X POST http://localhost:3001/api/cameras/camera_001/detection/stop
```

### 3. Monitor Counts

The RPi will automatically send counts to:
```
POST http://your-backend.com/api/detection/counts
```

Check your database (PostgreSQL or Firestore) to verify counts are being stored.

## Configuration

### RPi Configuration (`config.json`):
```json
{
  "cameraId": "camera_001",
  "siteId": "site_001",
  "orgId": "org_001",
  "apiConfig": {
    "enabled": true,
    "port": 5000,
    "autoStart": false
  },
  "detectionConfig": {
    "modelPath": "/opt/camera-agent/models/yolov8n.hef",
    "confidenceThreshold": 0.5,
    "objectClasses": ["person", "car", "bicycle"]
  }
}
```

### Backend Environment Variables:
```env
# Server
PORT=3001
FRONTEND_URL=http://localhost:3000

# Database (PostgreSQL - optional)
USE_POSTGRES=true
DATABASE_URL=postgresql://user:pass@localhost:5432/aiodcounter

# Database (Firestore - default)
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json

# Backend API Key (sent to RPi)
API_KEY=your_secret_api_key
BACKEND_URL=https://your-backend.com
```

## Troubleshooting

### RPi Not Responding
1. Check if camera agent is running: `sudo systemctl status camera-agent`
2. Check API server logs: `/var/log/camera_agent.log`
3. Verify network connectivity: `ping 192.168.0.214`

### Counts Not Received
1. Verify backend URL is accessible from RPi
2. Check backend logs for POST `/api/detection/counts`
3. Verify database connection (PostgreSQL or Firestore)
4. Check RPi upload queue status

### Detection Not Starting
1. Verify camera is connected: `lsusb` or check RTSP stream
2. Check model file exists: `/opt/camera-agent/models/yolov8n.hef`
3. Verify Hailo-8 HAT is detected: `hailortcli scan-devices`
4. Check detection thread logs

## Performance Metrics

- **Detection FPS:** ~30 FPS (Hailo-8), ~10 FPS (TFLite)
- **Report Interval:** 5 seconds (configurable)
- **Network Latency:** <100ms (local network)
- **Database Write:** <50ms per count batch


