# AIOD Counter Backend API

Express.js backend server for camera detection control and data collection.

## Features

- ✅ Start/Stop camera detection via REST API
- ✅ Receive detection counts from Raspberry Pi
- ✅ Real-time updates via WebSocket (Socket.IO)
- ✅ Firestore integration for data persistence
- ✅ Health check endpoints
- ✅ CORS and security middleware

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
PORT=3001
GOOGLE_APPLICATION_CREDENTIALS=../firebase-backend/serviceAccountKey.json
RASPBERRY_PI_IP=192.168.1.100
RASPBERRY_PI_PORT=5000
BACKEND_URL=http://localhost:3001
API_KEY=your-secret-api-key-here
FRONTEND_URL=http://localhost:3000
```

### 3. Firebase Setup

Ensure you have Firebase Admin credentials:
- Place `serviceAccountKey.json` in `../firebase-backend/`
- Or set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

### 4. Start Server

**Development:**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

## API Endpoints

### Start Detection
```http
POST /api/cameras/:id/start-detection
Content-Type: application/json

{
  "cameraId": "CAM_123",
  "raspberryPiIp": "192.168.1.100"  // Optional, uses camera data if not provided
}
```

### Stop Detection
```http
POST /api/cameras/:id/stop-detection
Content-Type: application/json

{
  "cameraId": "CAM_123",
  "raspberryPiIp": "192.168.1.100"  // Optional
}
```

### Get Detection Status
```http
GET /api/cameras/:id/detection-status?cameraId=CAM_123&raspberryPiIp=192.168.1.100
```

### Check RPi Health
```http
GET /api/cameras/:id/health?cameraId=CAM_123&raspberryPiIp=192.168.1.100
```

### Receive Detection Counts (called by RPi)
```http
POST /api/api/detection/counts
Content-Type: application/json

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

## WebSocket Events

The server uses Socket.IO for real-time updates.

### Client → Server

**Join Camera Room:**
```javascript
socket.emit('join_camera', 'CAM_123');
```

### Server → Client

**Detection Counts Update:**
```javascript
socket.on('detection_counts', (data) => {
  console.log('New counts:', data);
  // data: { camera_id, counts, total_objects, timestamp, fps, runtime_seconds }
});
```

## Data Storage

Counts are stored in Firestore:

- **Collection:** `detectionLogs`
- **Camera Stats:** Updated in `cameras/{cameraId}/lastDetectionStats`

## Integration with Frontend

Update your frontend to use the backend API:

```javascript
// Example: Start detection
const response = await fetch('http://localhost:3001/api/cameras/CAM_123/start-detection', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ cameraId: 'CAM_123' })
});
```

## Deployment

### Using PM2

```bash
npm install -g pm2
pm2 start server.js --name aiod-backend
pm2 save
pm2 startup
```

### Using Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3001
CMD ["node", "server.js"]
```

## Troubleshooting

### "Raspberry Pi IP address not configured"
- Ensure camera document in Firestore has `ipAddress` field
- Or set `RASPBERRY_PI_IP` in `.env`
- Or pass `raspberryPiIp` in request body

### "Firebase Admin initialization warning"
- Verify `GOOGLE_APPLICATION_CREDENTIALS` path is correct
- Ensure service account JSON file exists

### WebSocket not connecting
- Check `FRONTEND_URL` in `.env` matches your frontend
- Verify CORS settings in `server.js`


