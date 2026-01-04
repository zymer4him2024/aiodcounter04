const axios = require('axios');
const admin = require('firebase-admin');
const SSHClient = require('../utils/sshClient');

// Initialize Firebase Admin if not already initialized
let db = null;
if (process.env.USE_POSTGRES !== 'true') {
  if (!admin.apps.length) {
    try {
      // Try to use existing initialization or service account
      const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS
        ? require(process.env.GOOGLE_APPLICATION_CREDENTIALS)
        : require('../../firebase-backend/serviceAccountKey.json');
      
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } catch (error) {
      console.warn('Firebase Admin initialization warning:', error.message);
      console.warn('Make sure Firebase Admin is initialized before using this controller');
    }
  }
  db = admin.firestore();
}

// Initialize PostgreSQL models if available
let DetectionLogsModel = null;
let CamerasModel = null;
if (process.env.USE_POSTGRES === 'true' || process.env.DATABASE_URL) {
  try {
    const models = require('../database/models');
    DetectionLogsModel = models.DetectionLogsModel;
    CamerasModel = models.CamerasModel;
  } catch (error) {
    console.warn('PostgreSQL models not available:', error.message);
  }
}

/**
 * Get RPi base URL from environment or camera data
 */
function getRPiBaseUrl(cameraData) {
  const rpiIp = process.env.RASPBERRY_PI_IP || cameraData?.ipAddress || cameraData?.raspberryPiIp;
  const rpiPort = process.env.RASPBERRY_PI_PORT || '5000';
  
  if (!rpiIp) {
    throw new Error('Raspberry Pi IP address not configured');
  }
  
  return `http://${rpiIp}:${rpiPort}`;
}

class CameraDetectionController {
  
  /**
   * START Detection - Called when user toggles switch ON
   */
  async startDetection(req, res) {
    try {
      const cameraId = req.params.id || req.body.cameraId;
      const { raspberryPiIp } = req.body;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }
      
      console.log(`🚀 Starting detection for camera: ${cameraId}`);
      
      // Get camera data (try PostgreSQL first, fallback to Firestore)
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          const camera = await CamerasModel.findById(cameraId);
          if (camera) {
            cameraData = camera;
          }
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
      
      const rpiBaseUrl = getRPiBaseUrl({ ...cameraData, ipAddress: raspberryPiIp || cameraData.raspberry_pi_ip || cameraData.ipAddress });
      
      // Backend URL for RPi to send counts to
      const backendUrl = process.env.BACKEND_URL || `${req.protocol}://${req.get('host')}`;
      const apiKey = process.env.API_KEY;
      
      // Call RPi API to start detection
      const response = await axios.post(
        `${rpiBaseUrl}/api/detection/start`,
        {
          camera_id: cameraId,
          backend_url: backendUrl,
          api_key: apiKey,
          report_interval: 5  // Send counts every 5 seconds
        },
        { timeout: 10000 }
      );
      
      // Update camera status (PostgreSQL)
      if (CamerasModel) {
        try {
          await CamerasModel.updateDetectionStatus(
            cameraId,
            'active',
            new Date(),
            null
          );
        } catch (pgError) {
          console.error('PostgreSQL update error:', pgError.message);
        }
      }
      
      // Update Firestore - camera is now detecting
      if (db) {
        try {
          const cameraRef = db.collection('cameras').doc(cameraId);
          await cameraRef.update({
            detectionStatus: 'active',
            detectionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } catch (firestoreError) {
          console.error('Firestore update error:', firestoreError.message);
        }
      }
      
      console.log(`✅ Detection started for camera: ${cameraId}`);
      
      return res.json({
        success: true,
        message: 'Detection started',
        data: response.data
      });
      
    } catch (error) {
      console.error('❌ Failed to start detection:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
  
  /**
   * STOP Detection - Called when user toggles switch OFF
   */
  async stopDetection(req, res) {
    try {
      const cameraId = req.params.id || req.body.cameraId;
      const { raspberryPiIp } = req.body;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }
      
      console.log(`🛑 Stopping detection for camera: ${cameraId}`);
      
      // Get camera data (try PostgreSQL first, fallback to Firestore)
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          const camera = await CamerasModel.findById(cameraId);
          if (camera) {
            cameraData = camera;
          }
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
      
      const rpiBaseUrl = getRPiBaseUrl({ ...cameraData, ipAddress: raspberryPiIp || cameraData.raspberry_pi_ip || cameraData.ipAddress });
      
      // Call RPi API to stop detection
      const response = await axios.post(
        `${rpiBaseUrl}/api/detection/stop`,
        {},
        { timeout: 10000 }
      );
      
      // Update camera status (PostgreSQL)
      if (CamerasModel) {
        try {
          await CamerasModel.updateDetectionStatus(
            cameraId,
            'inactive',
            null,
            new Date()
          );
        } catch (pgError) {
          console.error('PostgreSQL update error:', pgError.message);
        }
      }
      
      // Update Firestore
      if (db) {
        try {
          const cameraRef = db.collection('cameras').doc(cameraId);
          await cameraRef.update({
            detectionStatus: 'inactive',
            detectionStoppedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } catch (firestoreError) {
          console.error('Firestore update error:', firestoreError.message);
        }
      }
      
      console.log(`✅ Detection stopped for camera: ${cameraId}`);
      
      return res.json({
        success: true,
        message: 'Detection stopped',
        data: response.data
      });
      
    } catch (error) {
      console.error('❌ Failed to stop detection:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
  
  /**
   * RECEIVE Counts - Called BY RPi every 5 seconds
   */
  async receiveDetectionCounts(req, res) {
    try {
      const {
        camera_id,
        timestamp,
        counts,
        total_objects,
        frames_processed,
        fps,
        runtime_seconds
      } = req.body;
      
      if (!camera_id) {
        return res.status(400).json({
          success: false,
          error: 'camera_id is required'
        });
      }
      
      console.log(`📊 Received counts from camera ${camera_id}:`, {
        total_objects,
        fps,
        runtime_seconds
      });
      
      // Save to PostgreSQL if available
      if (DetectionLogsModel) {
        try {
          await DetectionLogsModel.create({
            camera_id,
            timestamp: new Date(timestamp),
            counts: counts || {},
            total_objects: total_objects || 0,
            frames_processed: frames_processed || 0,
            fps: fps || null,
            runtime_seconds: runtime_seconds || null
          });
          console.log(`✅ Saved to PostgreSQL: camera ${camera_id}`);
        } catch (pgError) {
          console.error('PostgreSQL save error:', pgError.message);
        }
      }
      
      // Save to Firestore (fallback or dual storage)
      if (db) {
        try {
          const logRef = db.collection('detectionLogs').doc();
          await logRef.set({
            camera_id,
            timestamp: admin.firestore.Timestamp.fromDate(new Date(timestamp)),
            counts: counts || {},
            total_objects: total_objects || 0,
            frames_processed: frames_processed || 0,
            fps: fps || 0,
            runtime_seconds: runtime_seconds || 0,
            created_at: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`✅ Saved to Firestore: camera ${camera_id}`);
        } catch (firestoreError) {
          console.error('Firestore save error:', firestoreError.message);
        }
      }
      
      // Update camera document with latest stats (PostgreSQL)
      if (CamerasModel) {
        try {
          await CamerasModel.updateLastDetectionStats(camera_id, {
            total_objects,
            fps,
            runtime_seconds,
            frames_processed
          });
        } catch (pgError) {
          console.error('PostgreSQL camera update error:', pgError.message);
        }
      }
      
      // Update camera document with latest stats (Firestore)
      if (db) {
        try {
          const cameraRef = db.collection('cameras').doc(camera_id);
          await cameraRef.update({
            lastDetectionStats: {
              total_objects,
              fps,
              runtime_seconds,
              frames_processed,
              last_count_update: admin.firestore.FieldValue.serverTimestamp()
            },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });
        } catch (firestoreError) {
          console.error('Firestore camera update error:', firestoreError.message);
        }
      }
      
      // Optional: Emit to WebSocket for real-time UI updates
      if (global.io) {
        global.io.to(`camera_${camera_id}`).emit('detection_counts', {
          camera_id,
          counts,
          total_objects,
          timestamp,
          fps,
          runtime_seconds
        });
      }
      
      return res.json({ 
        success: true, 
        received: true,
        message: 'Counts saved successfully'
      });
      
    } catch (error) {
      console.error('❌ Failed to save detection counts:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
  
  /**
   * GET Status - Check current detection status from RPi
   */
  async getDetectionStatus(req, res) {
    try {
      const cameraId = req.params.id || req.query.cameraId;
      const { raspberryPiIp } = req.query;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }
      
      // Get camera data (try PostgreSQL first, fallback to Firestore)
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          const camera = await CamerasModel.findById(cameraId);
          if (camera) {
            cameraData = camera;
          }
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
      
      const rpiBaseUrl = getRPiBaseUrl({ ...cameraData, ipAddress: raspberryPiIp || cameraData.raspberry_pi_ip || cameraData.ipAddress });
      
      // Call RPi API to get status
      const response = await axios.get(
        `${rpiBaseUrl}/api/detection/status`,
        { timeout: 5000 }
      );
      
      return res.json({
        success: true,
        data: response.data
      });
      
    } catch (error) {
      console.error('❌ Failed to get status:', error.message);
      
      // Return partial success if we can get database data
      try {
        const fallbackCameraId = req.params.id || req.query.cameraId;
        if (fallbackCameraId) {
          let fallbackCameraData = null;
          
          // Try PostgreSQL
          if (CamerasModel) {
            try {
              fallbackCameraData = await CamerasModel.findById(fallbackCameraId);
            } catch (pgError) {
              // Ignore
            }
          }
          
          // Try Firestore
          if (!fallbackCameraData && db) {
            try {
              const cameraRef = db.collection('cameras').doc(fallbackCameraId);
              const cameraDoc = await cameraRef.get();
              if (cameraDoc.exists) {
                fallbackCameraData = cameraDoc.data();
              }
            } catch (firestoreError) {
              // Ignore
            }
          }
          
          if (fallbackCameraData) {
            return res.json({
              success: true,
              data: {
                camera_id: fallbackCameraId,
                status: fallbackCameraData.detection_status || fallbackCameraData.detectionStatus || 'unknown',
                error: 'RPi unreachable',
                last_known: fallbackCameraData.lastDetectionStats || {}
              }
            });
          }
        }
      } catch (fallbackError) {
        // Ignore fallback errors
      }
      
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
  
  /**
   * Health Check - Verify RPi is reachable
   */
  async checkRPiHealth(req, res) {
    try {
      const { cameraId, raspberryPiIp } = req.query;
      
      if (!cameraId) {
        return res.status(400).json({
          success: false,
          error: 'cameraId is required'
        });
      }
      
      // Get camera data (try PostgreSQL first, fallback to Firestore)
      let cameraData = null;
      
      if (CamerasModel) {
        try {
          const camera = await CamerasModel.findById(cameraId);
          if (camera) {
            cameraData = camera;
          }
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
      
      const rpiBaseUrl = getRPiBaseUrl({ ...cameraData, ipAddress: raspberryPiIp || cameraData.raspberry_pi_ip || cameraData.ipAddress });
      
      // Try to reach RPi health endpoint
      const response = await axios.get(
        `${rpiBaseUrl}/api/health`,
        { timeout: 3000 }
      );
      
      return res.json({
        success: true,
        rpi_status: 'online',
        data: response.data
      });
      
    } catch (error) {
      return res.json({
        success: false,
        rpi_status: 'offline',
        error: error.message,
        message: 'Raspberry Pi is not reachable'
      });
    }
  }

  /**
   * ACTIVATE Camera - Called BY Raspberry Pi after successful activation
   * POST /api/cameras/activate
   * Headers: Authorization: Bearer YOUR_TOKEN
   */
  async activateCamera(req, res) {
    try {
      // Verify authentication token
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          success: false,
          error: 'Missing or invalid Authorization header. Expected: Bearer <token>'
        });
      }

      const token = authHeader.substring(7); // Remove 'Bearer ' prefix
      const expectedToken = process.env.API_KEY || process.env.AUTH_TOKEN;

      if (expectedToken && token !== expectedToken) {
        return res.status(403).json({
          success: false,
          error: 'Invalid authentication token'
        });
      }

      // Extract activation data from request body
      const {
        camera_id,
        site_id,
        status = 'activated',
        activated_at
      } = req.body;

      if (!camera_id) {
        return res.status(400).json({
          success: false,
          error: 'camera_id is required'
        });
      }

      const activationTimestamp = activated_at ? new Date(activated_at) : new Date();

      console.log(`✅ Camera activation received: ${camera_id}, site: ${site_id}`);

      // Update camera status in PostgreSQL
      if (CamerasModel) {
        try {
          // Check if camera exists, create if not
          let camera = await CamerasModel.findById(camera_id);
          
          // Update or create camera with activation status
          await CamerasModel.upsert({
            id: camera_id,
            name: camera?.name || `Camera ${camera_id}`,
            raspberry_pi_ip: camera?.raspberry_pi_ip || null,
            detection_status: camera?.detection_status || 'inactive', // Activation doesn't mean detection is active
            activated: true,
            activated_at: activationTimestamp,
            status: status,
            site_id: site_id || camera?.site_id || null
          });
          
          console.log(`✅ Camera activation saved to PostgreSQL: ${camera_id}`);
        } catch (pgError) {
          console.error('PostgreSQL activation update error:', pgError.message);
        }
      }

      // Update camera status in Firestore
      if (db) {
        try {
          const cameraRef = db.collection('cameras').doc(camera_id);
          
          // Check if camera exists
          const cameraDoc = await cameraRef.get();
          
          const updateData = {
            status: status,
            activated: true,
            activatedAt: admin.firestore.Timestamp.fromDate(activationTimestamp),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          };

          if (site_id) {
            updateData.siteId = site_id;
          }

          if (cameraDoc.exists) {
            await cameraRef.update(updateData);
          } else {
            // Create camera record if it doesn't exist
            await cameraRef.set({
              id: camera_id,
              name: `Camera ${camera_id}`,
              detectionStatus: 'inactive',
              ...updateData,
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }

          console.log(`✅ Camera activation saved to Firestore: ${camera_id}`);
        } catch (firestoreError) {
          console.error('Firestore activation update error:', firestoreError.message);
        }
      }

      // Optional: Emit WebSocket event for real-time UI updates
      if (global.io) {
        global.io.emit('camera_activated', {
          camera_id,
          site_id,
          status,
          activated_at: activationTimestamp.toISOString()
        });
      }

      return res.json({
        success: true,
        message: 'Camera activated successfully',
        data: {
          camera_id,
          site_id,
          status,
          activated_at: activationTimestamp.toISOString()
        }
      });

    } catch (error) {
      console.error('❌ Failed to activate camera:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Execute SSH command on RPi
   * POST /api/cameras/:id/ssh/execute
   */
  async executeSSHCommand(req, res) {
    try {
      const cameraId = req.params.id || req.body.cameraId;
      const { command, raspberryPiIp, raspberryPiUser } = req.body;

      if (!command) {
        return res.status(400).json({
          success: false,
          error: 'command is required'
        });
      }

      // Get camera data to find RPi IP
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
          }
        } catch (firestoreError) {
          console.warn('Firestore camera lookup failed:', firestoreError.message);
        }
      }

      const rpiIp = raspberryPiIp || 
        cameraData?.raspberry_pi_ip || 
        cameraData?.ipAddress || 
        process.env.RASPBERRY_PI_IP || 
        '192.168.0.214';

      const sshClient = new SSHClient({
        host: rpiIp,
        user: raspberryPiUser || 'digioptics_od'
      });

      const result = await sshClient.execute(command);

      return res.json({
        success: result.success,
        data: {
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.code
        }
      });

    } catch (error) {
      console.error('❌ SSH command execution failed:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Get RPi system information via SSH
   * GET /api/cameras/:id/ssh/system-info
   */
  async getRPiSystemInfo(req, res) {
    try {
      const cameraId = req.params.id || req.query.cameraId;
      const { raspberryPiIp, raspberryPiUser } = req.query;

      // Get camera data
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

      const rpiIp = raspberryPiIp || 
        cameraData?.raspberry_pi_ip || 
        cameraData?.ipAddress || 
        process.env.RASPBERRY_PI_IP || 
        '192.168.0.214';

      const sshClient = new SSHClient({
        host: rpiIp,
        user: raspberryPiUser || 'digioptics_od'
      });

      const systemInfo = await sshClient.getSystemInfo();
      const cameraAgentRunning = await sshClient.isServiceRunning('camera-agent');

      return res.json({
        success: true,
        data: {
          ...systemInfo,
          camera_agent_running: cameraAgentRunning
        }
      });

    } catch (error) {
      console.error('❌ Failed to get system info:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Get service logs from RPi via SSH
   * GET /api/cameras/:id/ssh/logs?service=camera-agent&lines=100
   */
  async getRPiServiceLogs(req, res) {
    try {
      const cameraId = req.params.id || req.query.cameraId;
      const { raspberryPiIp, raspberryPiUser, service = 'camera-agent', lines = 50 } = req.query;

      // Get camera data
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

      const rpiIp = raspberryPiIp || 
        cameraData?.raspberry_pi_ip || 
        cameraData?.ipAddress || 
        process.env.RASPBERRY_PI_IP || 
        '192.168.0.214';

      const sshClient = new SSHClient({
        host: rpiIp,
        user: raspberryPiUser || 'digioptics_od'
      });

      const logs = await sshClient.getServiceLogs(service, parseInt(lines));

      return res.json({
        success: true,
        data: {
          service,
          lines: parseInt(lines),
          logs
        }
      });

    } catch (error) {
      console.error('❌ Failed to get service logs:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * Restart service on RPi via SSH
   * POST /api/cameras/:id/ssh/restart-service
   */
  async restartRPiService(req, res) {
    try {
      const cameraId = req.params.id || req.body.cameraId;
      const { raspberryPiIp, raspberryPiUser, service = 'camera-agent' } = req.body;

      // Get camera data
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

      const rpiIp = raspberryPiIp || 
        cameraData?.raspberry_pi_ip || 
        cameraData?.ipAddress || 
        process.env.RASPBERRY_PI_IP || 
        '192.168.0.214';

      const sshClient = new SSHClient({
        host: rpiIp,
        user: raspberryPiUser || 'digioptics_od'
      });

      const result = await sshClient.restartService(service);

      return res.json({
        success: result.success,
        message: result.message,
        data: {
          service,
          restarted: result.success
        }
      });

    } catch (error) {
      console.error('❌ Failed to restart service:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
}

module.exports = new CameraDetectionController();

