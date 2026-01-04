const express = require('express');
const router = express.Router();
const cameraController = require('../controllers/cameraDetectionController');
const qrCodeController = require('../controllers/qrCodeController');

// Routes called BY your frontend
router.post('/cameras/:id/detection/start', cameraController.startDetection);
router.post('/cameras/:id/detection/stop', cameraController.stopDetection);
router.get('/cameras/:id/detection/status', cameraController.getDetectionStatus);
router.get('/rpi/health', cameraController.checkRPiHealth);

// QR Code generation routes
router.get('/cameras/:id/qr-code', qrCodeController.generateQRCode);
router.get('/cameras/:id/qr-code/download', qrCodeController.downloadQRCode);
router.post('/provisioning/token', qrCodeController.generateProvisioningToken);

// Route called BY Raspberry Pi (to send counts)
router.post('/api/detection/counts', cameraController.receiveDetectionCounts);

// Route called BY Raspberry Pi (to notify activation)
router.post('/api/cameras/activate', cameraController.activateCamera);

// SSH management routes
router.post('/cameras/:id/ssh/execute', cameraController.executeSSHCommand);
router.get('/cameras/:id/ssh/system-info', cameraController.getRPiSystemInfo);
router.get('/cameras/:id/ssh/logs', cameraController.getRPiServiceLogs);
router.post('/cameras/:id/ssh/restart-service', cameraController.restartRPiService);

module.exports = router;

