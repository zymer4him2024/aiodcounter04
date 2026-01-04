const QRCode = require('qrcode');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
let db = null;
if (process.env.USE_POSTGRES !== 'true') {
  if (!admin.apps.length) {
    try {
      const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS
        ? require(process.env.GOOGLE_APPLICATION_CREDENTIALS)
        : require('../../firebase-backend/serviceAccountKey.json');
      
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } catch (error) {
      console.warn('Firebase Admin initialization warning:', error.message);
    }
  }
  db = admin.firestore();
}

// Initialize PostgreSQL models if available
let CamerasModel = null;
if (process.env.USE_POSTGRES === 'true' || process.env.DATABASE_URL) {
  try {
    const models = require('../database/models');
    CamerasModel = models.CamerasModel;
  } catch (error) {
    console.warn('PostgreSQL models not available:', error.message);
  }
}

class QRCodeController {
  /**
   * Generate QR code URL for camera provisioning
   * GET /api/cameras/:id/qr-code?rpi_ip=192.168.4.1&token=PT_XXX&include_api_key=true
   */
  async generateQRCode(req, res) {
    try {
      const cameraId = req.params.id;
      const { 
        rpi_ip = '192.168.4.1', 
        include_api_key = 'true',  // Default to true - API key is needed
        token  // Optional: specific token to use
      } = req.query;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }

      // Get camera data
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          cameraData = await CamerasModel.findById(cameraId);
        } catch (pgError) {
          console.warn('PostgreSQL camera lookup failed:', pgError.message);
        }
      }
      
      if (!cameraData && db) {
        try {
          const cameraRef = db.collection('cameras').doc(cameraId);
          const cameraDoc = await cameraRef.get();
          if (cameraDoc.exists) {
            cameraData = cameraDoc.data();
            cameraData.id = cameraId;
          }
        } catch (firestoreError) {
          console.warn('Firestore camera lookup failed:', firestoreError.message);
        }
      }

      if (!cameraData) {
        return res.status(404).json({
          success: false,
          error: 'Camera not found'
        });
      }

      // Build backend URL
      const backendUrl = process.env.BACKEND_URL || `${req.protocol}://${req.get('host')}`;
      const apiKey = process.env.API_KEY;

      // Look up provisioning token if not provided
      let provisioningToken = token;
      if (!provisioningToken && db) {
        try {
          // Search for unused token for this camera
          const tokensSnapshot = await db.collection('provisioningTokens')
            .where('camera_id', '==', cameraId)
            .where('used', '==', false)
            .limit(1)
            .get();
          
          if (!tokensSnapshot.empty) {
            provisioningToken = tokensSnapshot.docs[0].id;
            console.log(`Found existing token for camera ${cameraId}: ${provisioningToken}`);
          }
        } catch (error) {
          console.warn('Failed to lookup provisioning token:', error.message);
        }
      }

      // If still no token, generate one (but warn)
      if (!provisioningToken) {
        console.warn(`⚠️ No provisioning token found for camera ${cameraId}. QR code will not include token.`);
      }

      // Prepare QR code data with ALL required fields
      const qrData = {
        camera_id: cameraId,
        site_id: cameraData.siteId || cameraData.site_id,
        backend_url: backendUrl,
        rpi_ip: rpi_ip,
        report_interval: 5
      };

      // Add provisioning token (REQUIRED)
      if (provisioningToken) {
        qrData.token = provisioningToken;
      }

      // Add API key if available and requested (DEFAULT: true)
      if (apiKey && include_api_key !== 'false') {
        qrData.api_key = apiKey;
      }

      // Generate provisioning portal URL
      // Format: http://192.168.4.1/?qr={encoded_json_data}
      const qrUrl = `http://${rpi_ip}/?qr=${encodeURIComponent(JSON.stringify(qrData))}`;
      
      console.log(`✅ QR code generated for camera ${cameraId}:`, {
        has_token: !!provisioningToken,
        has_api_key: !!qrData.api_key,
        backend_url: backendUrl
      });

      // Generate QR code as data URL (for display in frontend)
      const qrCodeDataUrl = await QRCode.toDataURL(qrUrl, {
        errorCorrectionLevel: 'M',
        type: 'image/png',
        width: 512,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });

      // Also generate as buffer for direct download
      const qrCodeBuffer = await QRCode.toBuffer(qrUrl, {
        errorCorrectionLevel: 'M',
        type: 'image/png',
        width: 512,
        margin: 2
      });

      return res.json({
        success: true,
        data: {
          camera_id: cameraId,
          qr_url: qrUrl,
          qr_code_image: qrCodeDataUrl, // Base64 encoded image for <img src>
          qr_data: qrData, // The data that's encoded in the QR
          download_url: `${req.protocol}://${req.get('host')}/api/cameras/${cameraId}/qr-code/download?rpi_ip=${rpi_ip}`
        }
      });

    } catch (error) {
      console.error('❌ Failed to generate QR code:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Download QR code as PNG image
   * GET /api/cameras/:id/qr-code/download?rpi_ip=192.168.4.1
   */
  async downloadQRCode(req, res) {
    try {
      const cameraId = req.params.id;
      const { rpi_ip = '192.168.4.1' } = req.query;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }

      // Get camera data (reuse same logic)
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          cameraData = await CamerasModel.findById(cameraId);
        } catch (pgError) {
          // Ignore
        }
      }
      
      if (!cameraData && db) {
        try {
          const cameraRef = db.collection('cameras').doc(cameraId);
          const cameraDoc = await cameraRef.get();
          if (cameraDoc.exists) {
            cameraData = cameraDoc.data();
          }
        } catch (firestoreError) {
          // Ignore
        }
      }

      if (!cameraData) {
        return res.status(404).json({
          success: false,
          error: 'Camera not found'
        });
      }

      const backendUrl = process.env.BACKEND_URL || `${req.protocol}://${req.get('host')}`;
      const apiKey = process.env.API_KEY;
      
      // Look up provisioning token
      let provisioningToken = null;
      if (db) {
        try {
          const tokensSnapshot = await db.collection('provisioningTokens')
            .where('camera_id', '==', cameraId)
            .where('used', '==', false)
            .limit(1)
            .get();
          
          if (!tokensSnapshot.empty) {
            provisioningToken = tokensSnapshot.docs[0].id;
          }
        } catch (error) {
          console.warn('Failed to lookup provisioning token:', error.message);
        }
      }
      
      const qrData = {
        camera_id: cameraId,
        site_id: cameraData.siteId || cameraData.site_id,
        backend_url: backendUrl,
        rpi_ip: rpi_ip,
        report_interval: 5
      };
      
      // Add provisioning token if found
      if (provisioningToken) {
        qrData.token = provisioningToken;
      }
      
      // Add API key (default: include it)
      if (apiKey) {
        qrData.api_key = apiKey;
      }

      const qrUrl = `http://${rpi_ip}/?qr=${encodeURIComponent(JSON.stringify(qrData))}`;

      // Generate QR code as buffer
      const qrCodeBuffer = await QRCode.toBuffer(qrUrl, {
        errorCorrectionLevel: 'M',
        type: 'image/png',
        width: 512,
        margin: 2
      });

      // Set headers for download
      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Content-Disposition', `attachment; filename="camera-${cameraId}-qr-code.png"`);
      res.setHeader('Content-Length', qrCodeBuffer.length);

      return res.send(qrCodeBuffer);

    } catch (error) {
      console.error('❌ Failed to download QR code:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Generate provisioning token (for legacy compatibility)
   * This creates a token that can be used in the provisioning flow
   */
  async generateProvisioningToken(req, res) {
    try {
      const { camera_id, site_id, camera_name } = req.body;

      if (!camera_id || !site_id) {
        return res.status(400).json({
          success: false,
          error: 'camera_id and site_id are required'
        });
      }

      // Generate a simple token (or use Firebase Functions for secure token generation)
      const token = `PT_${Date.now()}_${camera_id.substring(0, 8).toUpperCase()}`;

      // Store token in database (optional - for validation)
      if (db) {
        try {
          await db.collection('provisioningTokens').doc(token).set({
            camera_id,
            site_id,
            camera_name: camera_name || `Camera ${camera_id}`,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            used: false
          });
        } catch (error) {
          console.warn('Failed to store token:', error.message);
        }
      }

      return res.json({
        success: true,
        data: {
          token,
          camera_id,
          site_id,
          camera_name: camera_name || `Camera ${camera_id}`
        }
      });

    } catch (error) {
      console.error('❌ Failed to generate token:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
}

module.exports = new QRCodeController();

