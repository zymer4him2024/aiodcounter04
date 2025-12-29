# Firestore Structure Update Guide

## New Camera Document Fields

The camera document in Firestore (`cameras/{cameraId}`) now includes hardware monitoring fields:

### New Fields Structure

```javascript
{
  // Existing fields...
  name: "Camera Name",
  deviceId: "device-id",
  siteId: "site-id",
  status: "online",
  lastSeen: Timestamp,
  
  // NEW: Performance metrics
  fps: 65.3,              // Current frames per second
  frameCount: 125430,      // Total frames processed
  
  // NEW: Detector status
  detectorStatus: {
    camera_active: true,
    model_loaded: true,
    hailo_active: true,
    fps: 65.3,
    active_tracks: 3,
    total_counted: 1247,
    error_count: 0,
    uptime_seconds: 19380
  },
  
  // NEW: System health monitoring
  systemHealth: {
    cpuTemp: 65.3,        // Raspberry Pi CPU temperature (°C)
    hailoTemp: 58.2,      // Hailo chip temperature (°C)
    cpuUsage: 45.2,       // CPU usage percentage
    memoryUsage: 68.1,    // Memory usage percentage
    timestamp: Timestamp
  }
}
```

## Implementation

### 1. Python Camera Agent

Use the `update_camera_status.py` utility function:

```python
from update_camera_status import update_camera_status

# In your camera agent's heartbeat/status update thread (every 30-60 seconds):

detector_status = {
    'camera_active': self.camera is not None and self.camera.isOpened(),
    'model_loaded': self.detector is not None,
    'hailo_active': self.detector.vdevice is not None if hasattr(self.detector, 'vdevice') else False,
    'fps': self.current_fps,
    'active_tracks': len(self.tracker.tracked_objects) if hasattr(self, 'tracker') else 0,
    'total_counted': self.total_counted,
    'error_count': self.error_count,
    'uptime_seconds': int(time.time() - self.start_time)
}

update_camera_status(
    camera_id=self.config['cameraId'],
    fps=self.current_fps,
    frame_count=self.frame_count,
    detector_status=detector_status,
    firestore_client=self.firestore_client
)
```

### 2. Required Dependencies

Add to `requirements.txt`:
```
psutil>=5.9.0
```

### 3. System Health Auto-Detection

The `update_camera_status` function automatically detects:
- CPU temperature from `/sys/class/thermal/thermal_zone0/temp`
- CPU usage via `psutil`
- Memory usage via `psutil`
- Hailo temperature (if `hailortcli` is available)

### 4. Update Frequency

**Recommended:** Update every 30-60 seconds to balance:
- Real-time monitoring accuracy
- Firestore write costs
- Network bandwidth

### 5. Frontend Display

The `LiveCounts.jsx` component already supports displaying:
- `detectorStatus` fields (camera active, model loaded, hailo active, etc.)
- `systemHealth` fields (CPU temp, memory usage, etc.)

The component will automatically show this data when available in the camera document.

## Migration

### Existing Cameras

Existing camera documents will work without these fields. They are all optional:
- `fps?: number`
- `frameCount?: number`
- `detectorStatus?: {...}`
- `systemHealth?: {...}`

### New Cameras

New cameras created via provisioning will start with these fields once the camera agent begins updating them.

## Testing

1. **Check Firestore Console:**
   - Navigate to `cameras/{cameraId}`
   - Verify new fields appear after camera agent runs for 30-60 seconds

2. **Check Dashboard:**
   - Open "Live Counts" tab
   - Select a camera
   - Verify hardware status cards display the new data

3. **Monitor Updates:**
   - Watch Firestore document in real-time
   - Confirm `systemHealth.timestamp` updates every 30-60 seconds

## Troubleshooting

### Fields Not Appearing

1. **Check camera agent logs:**
   ```bash
   sudo journalctl -u camera-agent -f
   ```

2. **Verify Firestore permissions:**
   - Camera agent needs write access to `cameras/{cameraId}`

3. **Check Python dependencies:**
   ```bash
   pip3 install psutil
   ```

### Temperature Readings Fail

- **CPU temp:** Requires `/sys/class/thermal/thermal_zone0/temp` (standard on Raspberry Pi)
- **Hailo temp:** Requires `hailortcli` installed and Hailo device connected

### High Update Frequency

If you see too many Firestore writes:
- Increase update interval in camera agent
- Consider batching updates
- Use Firestore offline persistence for local buffering



