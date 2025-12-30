const express = require('express');
const router = express.Router();
const cameraController = require('../controllers/cameraDetectionController');

// Routes called BY your frontend
router.post('/cameras/:id/detection/start', cameraController.startDetection);
router.post('/cameras/:id/detection/stop', cameraController.stopDetection);
router.get('/cameras/:id/detection/status', cameraController.getDetectionStatus);
router.get('/rpi/health', cameraController.checkRPiHealth);

// Route called BY Raspberry Pi (to send counts)
router.post('/api/detection/counts', cameraController.receiveDetectionCounts);

module.exports = router;

