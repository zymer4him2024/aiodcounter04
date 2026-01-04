# Camera Activation Endpoint

## Overview

The activation endpoint allows Raspberry Pi cameras to notify the backend when they have been successfully activated/provisioned.

## Endpoint

**POST** `/api/cameras/activate`

## Authentication

Requires Bearer token authentication:

```
Authorization: Bearer YOUR_API_TOKEN
```

The token must match the value in:
- `process.env.API_KEY`, or
- `process.env.AUTH_TOKEN`

## Request

### Headers
```
Authorization: Bearer YOUR_API_TOKEN
Content-Type: application/json
```

### Body
```json
{
  "camera_id": "camera_001",
  "site_id": "site_123",
  "status": "activated",
  "activated_at": "2025-12-30T19:51:06.123456Z"
}
```

### Parameters
- `camera_id` (required): Camera identifier
- `site_id` (optional): Site identifier
- `status` (optional): Activation status (default: "activated")
- `activated_at` (optional): ISO timestamp of activation (default: current time)

## Response

### Success (200 OK)
```json
{
  "success": true,
  "message": "Camera activated successfully",
  "data": {
    "camera_id": "camera_001",
    "site_id": "site_123",
    "status": "activated",
    "activated_at": "2025-12-30T19:51:06.123456Z"
  }
}
```

### Error Responses

#### 401 Unauthorized - Missing Token
```json
{
  "success": false,
  "error": "Missing or invalid Authorization header. Expected: Bearer <token>"
}
```

#### 403 Forbidden - Invalid Token
```json
{
  "success": false,
  "error": "Invalid authentication token"
}
```

#### 400 Bad Request - Missing Required Field
```json
{
  "success": false,
  "error": "camera_id is required"
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Error message"
}
```

## Usage Examples

### cURL
```bash
curl -X POST https://your-backend.com/api/cameras/activate \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "camera_001",
    "site_id": "site_123",
    "status": "activated",
    "activated_at": "2025-12-30T19:51:06.123456Z"
  }'
```

### JavaScript (Fetch)
```javascript
const response = await fetch('https://your-backend.com/api/cameras/activate', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_API_TOKEN',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    camera_id: 'camera_001',
    site_id: 'site_123',
    status: 'activated',
    activated_at: new Date().toISOString()
  })
});

const result = await response.json();
console.log(result);
```

### Python (Requests)
```python
import requests
from datetime import datetime

url = "https://your-backend.com/api/cameras/activate"
headers = {
    "Authorization": "Bearer YOUR_API_TOKEN",
    "Content-Type": "application/json"
}
data = {
    "camera_id": "camera_001",
    "site_id": "site_123",
    "status": "activated",
    "activated_at": datetime.utcnow().isoformat() + "Z"
}

response = requests.post(url, json=data, headers=headers)
print(response.json())
```

### From Raspberry Pi (camera_agent.py)
```python
import requests
import json
from datetime import datetime

def notify_activation(camera_id, site_id, backend_url, api_key):
    """Notify backend that camera has been activated"""
    url = f"{backend_url}/api/cameras/activate"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    data = {
        "camera_id": camera_id,
        "site_id": site_id,
        "status": "activated",
        "activated_at": datetime.utcnow().isoformat() + "Z"
    }
    
    try:
        response = requests.post(url, json=data, headers=headers, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Failed to notify activation: {e}")
        return None
```

## Database Updates

The endpoint updates both PostgreSQL and Firestore:

### PostgreSQL (`cameras` table)
- Sets `activated = true`
- Sets `activated_at` timestamp
- Updates `status` field
- Sets `site_id` if provided
- Updates `updated_at` timestamp

### Firestore (`cameras` collection)
- Sets `activated = true`
- Sets `activatedAt` timestamp
- Updates `status` field
- Sets `siteId` if provided
- Updates `lastUpdated` timestamp

If the camera doesn't exist, it will be created.

## WebSocket Events

When activation is successful, a WebSocket event is emitted:

```javascript
// Event name: 'camera_activated'
// Payload:
{
  camera_id: "camera_001",
  site_id: "site_123",
  status: "activated",
  activated_at: "2025-12-30T19:51:06.123456Z"
}
```

Frontend clients can listen for this event:
```javascript
socket.on('camera_activated', (data) => {
  console.log('Camera activated:', data.camera_id);
  // Update UI or refresh camera list
});
```

## Environment Variables

Set in your `.env` file:

```env
# API Key for authentication
API_KEY=your_secret_api_key_here

# OR use AUTH_TOKEN (API_KEY takes precedence)
AUTH_TOKEN=your_secret_token_here

# Backend URL (for reference)
BACKEND_URL=https://your-backend.com
```

## Security Notes

1. **Token Security**: Keep your API key secure. Never commit it to version control.
2. **HTTPS**: Always use HTTPS in production to protect tokens in transit.
3. **Token Rotation**: Consider implementing token rotation for enhanced security.
4. **Rate Limiting**: Consider adding rate limiting to prevent abuse.

## Testing

### Test with cURL
```bash
# Set your token
export API_TOKEN="your_api_key_here"

# Test activation
curl -X POST http://localhost:3001/api/cameras/activate \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "test_camera_001",
    "site_id": "test_site_123",
    "status": "activated"
  }'
```

### Test without authentication (will fail)
```bash
curl -X POST http://localhost:3001/api/cameras/activate \
  -H "Content-Type: application/json" \
  -d '{"camera_id": "test_camera_001"}'
# Expected: 401 Unauthorized
```

## Troubleshooting

### "Missing or invalid Authorization header"
- Ensure the `Authorization` header is present
- Format must be: `Bearer <token>` (with space after "Bearer")
- Check that the header name is spelled correctly

### "Invalid authentication token"
- Verify the token matches `API_KEY` or `AUTH_TOKEN` in `.env`
- Check for extra spaces or characters in the token
- Ensure the token is correctly extracted from the header

### Camera not appearing in database
- Check database connection (PostgreSQL or Firestore)
- Review server logs for database errors
- Verify camera_id format matches expected pattern

### WebSocket event not received
- Verify Socket.IO server is running
- Check WebSocket connection in frontend
- Ensure event listener is registered before activation


