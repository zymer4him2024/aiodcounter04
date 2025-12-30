# Frontend/Backend Integration for Camera Control

This document explains how the frontend camera control component integrates with the backend REST API.

## Architecture Overview

```
Frontend (React) → Firebase Functions → Raspberry Pi API → Camera Agent
                  ↓
                Firestore (counts data)
```

## Components

### 1. Frontend Component: `CameraControl.jsx`

Located at: `ai-od-counter-multitenant/web-dashboard/src/components/CameraControl.jsx`

**Features:**
- Start/Stop detection toggle button
- Real-time status polling (every 5 seconds)
- Display FPS, frames processed, runtime
- Show detector type (Hailo-8 or TFLite)
- Error handling and user feedback

**Integrated into:** `Cameras.jsx` component (displays in each camera card)

### 2. Firebase Functions

Located at: `ai-od-counter-multitenant/firebase-backend/functions/src/index.ts`

**Functions Added:**
- `startCameraDetection` - Proxies start command to RPi
- `stopCameraDetection` - Proxies stop command to RPi
- `getCameraDetectionStatus` - Gets current detection status from RPi
- `receiveDetectionCounts` - Receives counts from RPi (HTTP endpoint)

**Benefits:**
- Authentication/authorization handled by Firebase
- Role-based access control (superadmin, subadmin, viewer)
- Secure proxy to RPi (avoids CORS issues)
- Centralized logging

### 3. Backend Controller (Express - Optional)

Located at: `ai-od-counter-multitenant/backend/controllers/cameraController.js`

**Note:** This is provided as an alternative if you want a standalone Express backend instead of Firebase Functions.

## Setup Steps

### 1. Install Dependencies

**Firebase Functions:**
```bash
cd ai-od-counter-multitenant/firebase-backend/functions
npm install axios
npm run build
```

**Web Dashboard:**
```bash
cd ai-od-counter-multitenant/web-dashboard
npm install  # axios should already be installed
```

### 2. Deploy Firebase Functions

```bash
cd ai-od-counter-multitenant
firebase deploy --only functions
```

### 3. Update Camera Configuration

Ensure cameras have `ipAddress` or `raspberryPiIp` field in Firestore:

```javascript
// In Firestore cameras collection
{
  cameraId: "CAM_123",
  ipAddress: "192.168.1.100",  // RPi IP address
  // ... other fields
}
```

### 4. Rebuild Dashboard

```bash
cd ai-od-counter-multitenant/web-dashboard
npm run build
cd ..
firebase deploy --only hosting
```

## Usage

### From Frontend

The `CameraControl` component is automatically displayed in each camera card. Users can:

1. Click "Start Detection" to begin object detection
2. Click "Stop Detection" to pause detection
3. View real-time stats (FPS, frames, runtime)

### Permissions

- **Superadmin**: Can control all cameras
- **Subadmin**: Can control cameras assigned to them
- **Viewer**: Read-only access (cannot control)

## API Flow

### Start Detection
```
User clicks "Start" 
→ CameraControl calls startCameraDetection Firebase Function
→ Firebase Function verifies permissions
→ Firebase Function calls RPi API (http://RPI_IP:5000/api/detection/start)
→ RPi starts detection and begins sending counts
```

### Stop Detection
```
User clicks "Stop"
→ CameraControl calls stopCameraDetection Firebase Function
→ Firebase Function verifies permissions
→ Firebase Function calls RPi API (http://RPI_IP:5000/api/detection/stop)
→ RPi stops detection
```

### Status Polling
```
Every 5 seconds:
→ CameraControl calls getCameraDetectionStatus Firebase Function
→ Firebase Function calls RPi API (http://RPI_IP:5000/api/detection/status)
→ Status displayed in UI (detecting/idle, FPS, frames, etc.)
```

## Data Flow

Counts are sent in two ways:

1. **Firebase (Primary)**: RPi agent sends counts directly to Firestore
   - Path: `/cameras/{cameraId}/counts/{timestamp}`
   - Used by `LiveCounts` component for analytics

2. **Backend API (Optional)**: If `backend_url` is configured, RPi also sends to your backend
   - Endpoint: `POST /api/detection/counts`
   - Useful for custom processing, webhooks, etc.

## Troubleshooting

### "Raspberry Pi IP address not configured"
- Ensure camera document has `ipAddress` or `raspberryPiIp` field
- Check Firestore camera document

### "Failed to toggle detection"
- Verify RPi is accessible from Firebase Functions (network/firewall)
- Check RPi API is running on port 5000
- Verify camera permissions (role-based access)

### Status not updating
- Check browser console for errors
- Verify RPi API `/api/detection/status` endpoint is working
- Test with direct curl: `curl http://RPI_IP:5000/api/detection/status`

### CORS errors (if calling RPi directly)
- Use Firebase Functions instead (recommended)
- Or configure CORS on RPi Flask server

## Testing

### Test RPi API directly:
```bash
# Get status
curl http://192.168.1.100:5000/api/detection/status

# Start detection
curl -X POST http://192.168.1.100:5000/api/detection/start \
  -H "Content-Type: application/json" \
  -d '{"camera_id": "CAM_123"}'

# Stop detection
curl -X POST http://192.168.1.100:5000/api/detection/stop
```

### Test Firebase Functions:
```javascript
// In browser console (while logged in)
import { httpsCallable } from 'firebase/functions';
import { functions } from './firebase';

const startDetection = httpsCallable(functions, 'startCameraDetection');
const result = await startDetection({
  cameraId: 'CAM_123',
  raspberryPiIp: '192.168.1.100'
});
console.log(result.data);
```

## Next Steps

1. **Deploy functions**: `firebase deploy --only functions`
2. **Update dashboard**: `npm run build && firebase deploy --only hosting`
3. **Test**: Open dashboard and try start/stop detection on a camera
4. **Monitor**: Check Firebase Functions logs for errors

