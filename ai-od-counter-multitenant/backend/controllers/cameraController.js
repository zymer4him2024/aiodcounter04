const axios = require('axios');

class CameraDetectionController {
  /**
   * Start detection on Raspberry Pi
   * Called when user turns ON the switch in your UI
   */
  async startDetection(req, res) {
    try {
      const { cameraId, raspberryPiIp } = req.body;
      
      if (!raspberryPiIp) {
        return res.status(400).json({
          success: false,
          error: 'raspberryPiIp is required'
        });
      }
      
      // Your backend URL where RPi will send counts
      const backendUrl = process.env.BACKEND_URL || req.protocol + '://' + req.get('host');
      const apiKey = process.env.API_KEY;
      
      // Call RPi API to start detection
      const response = await axios.post(
        `http://${raspberryPiIp}:5000/api/detection/start`,
        {
          camera_id: cameraId,
          backend_url: backendUrl,
          api_key: apiKey,
          report_interval: 5
        },
        { timeout: 10000 }
      );
      
      // Update database - camera is now detecting
      // Note: Adjust this based on your database structure
      // await db.cameras.update({
      //   id: cameraId,
      //   status: 'detecting',
      //   started_at: new Date()
      // });
      
      return res.json({
        success: true,
        message: 'Detection started',
        data: response.data
      });
      
    } catch (error) {
      console.error('Failed to start detection:', error);
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
  
  /**
   * Stop detection on Raspberry Pi
   * Called when user turns OFF the switch in your UI
   */
  async stopDetection(req, res) {
    try {
      const { raspberryPiIp } = req.body;
      
      if (!raspberryPiIp) {
        return res.status(400).json({
          success: false,
          error: 'raspberryPiIp is required'
        });
      }
      
      // Call RPi API to stop detection
      const response = await axios.post(
        `http://${raspberryPiIp}:5000/api/detection/stop`,
        {},
        { timeout: 10000 }
      );
      
      // Update database
      // await db.cameras.update({
      //   id: cameraId,
      //   status: 'idle',
      //   stopped_at: new Date()
      // });
      
      return res.json({
        success: true,
        message: 'Detection stopped',
        data: response.data
      });
      
    } catch (error) {
      console.error('Failed to stop detection:', error);
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
  
  /**
   * Receive detection counts from Raspberry Pi
   * This endpoint is called BY the RPi every 5 seconds
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
      
      console.log(`Received counts from camera ${camera_id}:`, counts);
      
      // Save to database
      // await db.detectionLogs.create({
      //   camera_id,
      //   timestamp: new Date(timestamp),
      //   counts: JSON.stringify(counts),
      //   total_objects,
      //   frames_processed,
      //   fps,
      //   runtime_seconds
      // });
      
      // Emit real-time update via WebSocket (optional)
      // if (io) {
      //   io.to(`camera_${camera_id}`).emit('detection_update', {
      //     camera_id,
      //     counts,
      //     total_objects,
      //     timestamp
      //   });
      // }
      
      return res.json({ success: true, received: true });
      
    } catch (error) {
      console.error('Failed to save detection counts:', error);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
  
  /**
   * Get current detection status from RPi
   */
  async getDetectionStatus(req, res) {
    try {
      const { raspberryPiIp } = req.params;
      
      if (!raspberryPiIp) {
        return res.status(400).json({
          success: false,
          error: 'raspberryPiIp is required'
        });
      }
      
      const response = await axios.get(
        `http://${raspberryPiIp}:5000/api/detection/status`,
        { timeout: 5000 }
      );
      
      return res.json({
        success: true,
        data: response.data
      });
      
    } catch (error) {
      console.error('Failed to get status:', error);
      return res.status(500).json({
        success: false,
        error: error.message,
        details: error.response?.data
      });
    }
  }
}

module.exports = new CameraDetectionController();


