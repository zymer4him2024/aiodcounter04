# QR Code Activation Flow - Complete Guide

## Overview

This guide explains the complete flow for activating a camera using QR code scanning.

## Flow Diagram

```
1. Generate QR Code (Backend/Dashboard)
   ↓
2. Print/Display QR Code
   ↓
3. Connect Phone to RPi Hotspot
   WiFi: AIOD-Camera-XXXXX
   Password: aiod2024
   ↓
4. Scan QR Code with Phone
   Opens: http://192.168.4.1/?qr={encoded_data}
   ↓
5. Portal Auto-Fills Token
   - Token pre-filled from QR
   - Camera info displayed
   - WiFi step optional
   ↓
6. Click "Activate Camera"
   - Uses token from QR
   - Uses backend_url from QR
   - Uses api_key from QR (if provided)
   ↓
7. Camera Activated ✅
   - Config saved
   - Service started
   - Portal closes
```

## Step-by-Step Process

### Step 1: Generate QR Code

From the dashboard, generate a QR code for a camera:

```javascript
// QR code contains:
{
  "camera_id": "camera_001",
  "site_id": "site_123",
  "backend_url": "https://your-backend.com",
  "token": "PT_XXXXXXXX",
  "rpi_ip": "192.168.4.1",
  "report_interval": 5,
  "api_key": "optional-api-key"
}
```

### Step 2: Connect to RPi Hotspot

1. On your phone, go to WiFi settings
2. Connect to: `AIOD-Camera-{hostname}`
3. Password: `aiod2024`
4. Wait for connection

### Step 3: Scan QR Code

1. Open camera app on phone
2. Scan the QR code
3. Phone opens browser automatically
4. URL: `http://192.168.4.1/?qr={encoded_data}`

### Step 4: Portal Auto-Processes QR

The portal automatically:
- ✅ Parses QR code data
- ✅ Pre-fills token
- ✅ Shows camera information
- ✅ Skips WiFi step (optional)
- ✅ Ready for activation

### Step 5: Activate Camera

1. Review camera information displayed
2. Click "🚀 Activate Camera" button
3. Portal sends activation request with:
   - Token from QR code
   - Backend URL from QR code
   - API key from QR code (if provided)
   - Camera ID and Site ID from QR code

### Step 6: Success

- ✅ Camera activated
- ✅ Config saved to `/opt/camera-agent/config.json`
- ✅ Camera-agent service started
- ✅ Success page shown
- ✅ Portal closes automatically

## QR Code Format

The QR code URL format is:

```
http://192.168.4.1/?qr={"camera_id":"camera_001","site_id":"site_123","backend_url":"https://your-backend.com","token":"PT_XXX","rpi_ip":"192.168.4.1","report_interval":5}
```

### Required Fields

- `token` - Provisioning token (required)
- `backend_url` - Backend API URL (required)
- `rpi_ip` - Hotspot IP (usually 192.168.4.1)
- `report_interval` - Count reporting interval in seconds

### Optional Fields

- `camera_id` - Camera identifier
- `site_id` - Site identifier
- `api_key` - API key for backend authentication

## Portal Features

### Auto-Fill from QR Code

When QR code is scanned:
- Token is automatically filled in
- Camera ID and Site ID are displayed
- Backend URL and API key are stored for activation

### WiFi Configuration (Optional)

- WiFi step is now optional
- Can skip WiFi and activate directly
- WiFi can be configured later if needed

### Activation Process

1. Portal sends activation request to Firebase
2. Receives camera configuration
3. Saves config with backend_url and api_key from QR
4. Starts camera-agent service
5. Shows success message

## Troubleshooting

### QR Code Not Scanning

1. **Check hotspot connection:**
   - Ensure phone is connected to RPi hotspot
   - SSID: `AIOD-Camera-XXXXX`
   - Password: `aiod2024`

2. **Check portal accessibility:**
   - Open browser: `http://192.168.4.1`
   - Should see portal page

3. **Check QR code format:**
   - Ensure QR contains `?qr=` parameter
   - Verify JSON is properly encoded

### Token Not Auto-Filled

1. **Check QR code data:**
   - Open browser console
   - Look for "QR Code data loaded" message
   - Verify token is in QR data

2. **Manual entry:**
   - Token can be entered manually
   - Copy from QR code if needed

### Activation Fails

1. **Check token validity:**
   - Verify token is correct
   - Check token hasn't expired
   - Ensure token matches camera

2. **Check network:**
   - RPi needs internet for activation
   - Can configure WiFi or use Ethernet
   - Check firewall settings

3. **Check logs:**
   ```bash
   sudo journalctl -u provisioning-portal -n 50
   ```

## Testing

### Test QR Code Generation

```bash
# From backend
curl "http://localhost:3001/api/cameras/camera_001/qr-code?rpi_ip=192.168.4.1"
```

### Test Portal Access

1. Connect to hotspot
2. Open: `http://192.168.4.1`
3. Should see portal page

### Test QR Code Scanning

1. Generate QR code
2. Connect to hotspot
3. Scan QR code
4. Verify token is auto-filled
5. Click activate
6. Verify success

## Files Modified

- `camera-system/provisioning_portal.py` - Updated portal with QR code support
- `ai-od-counter-multitenant/web-dashboard/src/Dashboard.js` - QR code generation
- `ai-od-counter-multitenant/backend/controllers/qrCodeController.js` - QR code API

## Summary

✅ **QR code scanning** - Auto-fills token and camera info  
✅ **WiFi optional** - Can activate without WiFi configuration  
✅ **Auto-activation** - One-click activation after scanning  
✅ **Backend integration** - Uses backend_url and api_key from QR  
✅ **Success feedback** - Clear success message and auto-close  

The complete flow is now streamlined for easy camera activation via QR code scanning!

