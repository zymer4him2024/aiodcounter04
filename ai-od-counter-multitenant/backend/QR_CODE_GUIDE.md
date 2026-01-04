# QR Code Generation for Camera Provisioning

This guide explains how to use the QR code generation API for camera provisioning.

## Overview

QR codes contain camera configuration data that can be scanned to open the provisioning portal with pre-loaded information. This simplifies the camera setup process.

## API Endpoints

### 1. Generate QR Code Data & Image

**Endpoint:** `GET /api/cameras/:id/qr-code?rpi_ip=192.168.4.1&include_token=false`

**Parameters:**
- `id` (path): Camera ID
- `rpi_ip` (query, optional): Raspberry Pi hotspot IP (default: `192.168.4.1`)
- `include_token` (query, optional): Include API key in QR (default: `false`)

**Response:**
```json
{
  "success": true,
  "data": {
    "camera_id": "camera_001",
    "qr_url": "http://192.168.4.1/?qr={\"camera_id\":\"camera_001\",...}",
    "qr_code_image": "data:image/png;base64,iVBORw0KGgo...",
    "qr_data": {
      "camera_id": "camera_001",
      "site_id": "site_123",
      "backend_url": "https://your-backend.com",
      "rpi_ip": "192.168.4.1",
      "report_interval": 5
    },
    "download_url": "https://your-backend.com/api/cameras/camera_001/qr-code/download?rpi_ip=192.168.4.1"
  }
}
```

### 2. Download QR Code as PNG

**Endpoint:** `GET /api/cameras/:id/qr-code/download?rpi_ip=192.168.4.1`

**Parameters:**
- `id` (path): Camera ID
- `rpi_ip` (query, optional): Raspberry Pi hotspot IP (default: `192.168.4.1`)

**Response:** PNG image file (downloadable)

### 3. Generate Provisioning Token (Legacy)

**Endpoint:** `POST /api/provisioning/token`

**Body:**
```json
{
  "camera_id": "camera_001",
  "site_id": "site_123",
  "camera_name": "Entrance Camera"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "PT_1234567890_CAMERA00",
    "camera_id": "camera_001",
    "site_id": "site_123",
    "camera_name": "Entrance Camera"
  }
}
```

## Usage Examples

### Frontend: Display QR Code

```javascript
// Fetch QR code data
const response = await fetch(`/api/cameras/${cameraId}/qr-code?rpi_ip=192.168.4.1`);
const { data } = await response.json();

// Display QR code image
<img src={data.qr_code_image} alt="Camera QR Code" />

// Or display QR URL as text
<p>Scan this QR code or visit: {data.qr_url}</p>
```

### Backend: Generate QR Code URL

```javascript
const qrData = {
  camera_id: "camera_001",
  site_id: "site_123",
  backend_url: "https://your-backend.com",
  token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
};

const qrUrl = `http://192.168.4.1/?qr=${encodeURIComponent(JSON.stringify(qrData))}`;
```

### cURL Examples

```bash
# Generate QR code
curl "http://localhost:3001/api/cameras/camera_001/qr-code?rpi_ip=192.168.4.1"

# Download QR code PNG
curl "http://localhost:3001/api/cameras/camera_001/qr-code/download?rpi_ip=192.168.4.1" \
  --output qr-code.png

# Generate provisioning token
curl -X POST "http://localhost:3001/api/provisioning/token" \
  -H "Content-Type: application/json" \
  -d '{
    "camera_id": "camera_001",
    "site_id": "site_123",
    "camera_name": "Entrance Camera"
  }'
```

## QR Code Data Structure

The QR code contains JSON data with the following structure:

```json
{
  "camera_id": "camera_001",
  "site_id": "site_123",
  "backend_url": "https://your-backend.com",
  "rpi_ip": "192.168.4.1",
  "report_interval": 5,
  "api_key": "optional-api-key"
}
```

## Provisioning Portal Integration

When the QR code is scanned, it opens the provisioning portal URL:

```
http://192.168.4.1/?qr={encoded_json_data}
```

The portal automatically:
1. Parses the QR data from the URL
2. Displays camera information
3. Pre-fills configuration if applicable
4. Uses backend_url and api_key for camera activation

## Workflow

1. **Backend generates QR code** with camera configuration
2. **QR code is displayed** in frontend or printed on sticker
3. **User scans QR code** with phone/tablet
4. **Portal opens** with pre-loaded camera data
5. **User completes WiFi setup** (if needed)
6. **Camera activates** using QR code data

## Security Considerations

- **API Key in QR**: Only include `api_key` if `include_token=true` is explicitly set
- **QR Code Storage**: Store QR codes securely if they contain sensitive data
- **Token Expiry**: Consider adding expiration to provisioning tokens
- **Access Control**: Ensure only authorized users can generate QR codes

## Troubleshooting

### QR Code Not Scanning
- Ensure QR code is large enough (minimum 512x512 pixels)
- Check error correction level (currently set to 'M' - Medium)
- Verify QR code image quality/contrast

### Portal Not Reading QR Data
- Check URL encoding (data should be properly encoded)
- Verify JSON format is valid
- Check browser console for parsing errors

### Camera Not Activating
- Verify backend_url is accessible from Raspberry Pi
- Check API key is correct (if included)
- Ensure camera_id exists in database


