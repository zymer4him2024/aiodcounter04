#!/usr/bin/env python3
"""
REST API Server for Camera Agent Control
Provides endpoints for start/stop detection and status monitoring
"""

from flask import Flask, request, jsonify
try:
    from flask_cors import CORS
    CORS_AVAILABLE = True
except ImportError:
    CORS_AVAILABLE = False
    print("Warning: flask-cors not installed, CORS disabled")
import threading
import logging
from datetime import datetime
from typing import Optional, Dict
import json

logger = logging.getLogger(__name__)

class CameraAgentAPI:
    """REST API server for controlling camera agent"""
    
    def __init__(self, agent, config: Dict, port: int = 5000):
        """
        Initialize API server
        
        Args:
            agent: CameraEdgeAgent instance
            config: Configuration dictionary
            port: Port to run API server on
        """
        self.agent = agent
        self.config = config
        self.port = port
        self.app = Flask(__name__)
        if CORS_AVAILABLE:
            CORS(self.app)  # Enable CORS for cross-origin requests
        
        # API state
        self.detection_active = False
        self.backend_url = None
        self.api_key = None
        self.report_interval = 5  # seconds
        self.started_at = None
        
        # Setup routes
        self._setup_routes()
        
        # API thread
        self.api_thread = None
        self.server_running = False
    
    def _setup_routes(self):
        """Setup API routes"""
        
        @self.app.route('/api/detection/start', methods=['POST'])
        def start_detection():
            """Start object detection"""
            try:
                data = request.get_json() or {}
                camera_id = data.get('camera_id') or self.config.get('cameraId')
                self.backend_url = data.get('backend_url')
                self.api_key = data.get('api_key')
                self.report_interval = data.get('report_interval', 5)
                
                if not self.detection_active:
                    # Start the agent if not already running
                    if not self.agent.running:
                        self.agent.start()
                    
                    # Update agent's detection state
                    self.agent.set_detection_active(True)
                    
                    # Update backend configuration if provided
                    if self.backend_url:
                        self.agent.set_backend_config(
                            backend_url=self.backend_url,
                            api_key=self.api_key,
                            report_interval=self.report_interval
                        )
                    
                    self.detection_active = True
                    self.started_at = datetime.utcnow()
                    
                    logger.info(f"Detection started via API for camera: {camera_id}")
                    
                    return jsonify({
                        'success': True,
                        'message': 'Detection started',
                        'camera_id': camera_id,
                        'status': 'detecting',
                        'started_at': self.started_at.isoformat()
                    }), 200
                else:
                    return jsonify({
                        'success': True,
                        'message': 'Detection already active',
                        'status': 'detecting'
                    }), 200
                    
            except Exception as e:
                logger.error(f"Error starting detection: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/detection/stop', methods=['POST'])
        def stop_detection():
            """Stop object detection"""
            try:
                if self.detection_active:
                    # Update agent's detection state
                    self.agent.set_detection_active(False)
                    
                    self.detection_active = False
                    # Note: We don't stop the agent, just mark detection as inactive
                    # The agent continues running but stops processing
                    
                    logger.info("Detection stopped via API")
                    
                    return jsonify({
                        'success': True,
                        'message': 'Detection stopped',
                        'status': 'idle',
                        'stopped_at': datetime.utcnow().isoformat()
                    }), 200
                else:
                    return jsonify({
                        'success': True,
                        'message': 'Detection already stopped',
                        'status': 'idle'
                    }), 200
                    
            except Exception as e:
                logger.error(f"Error stopping detection: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/api/detection/status', methods=['GET'])
        def get_status():
            """Get current detection status"""
            try:
                status = {
                    'success': True,
                    'camera_id': self.config.get('cameraId'),
                    'status': 'detecting' if self.detection_active else 'idle',
                    'agent_running': self.agent.running if hasattr(self.agent, 'running') else False,
                    'started_at': self.started_at.isoformat() if self.started_at else None,
                }
                
                # Add FPS and frame count if available
                if hasattr(self.agent, 'current_fps'):
                    status['fps'] = self.agent.current_fps
                if hasattr(self.agent, 'frame_count'):
                    status['frames_processed'] = self.agent.frame_count
                
                # Calculate runtime
                if self.started_at:
                    runtime = (datetime.utcnow() - self.started_at).total_seconds()
                    status['runtime_seconds'] = runtime
                
                # Add detector type
                if hasattr(self.agent, 'detector_type'):
                    status['detector_type'] = self.agent.detector_type
                
                return jsonify(status), 200
                
            except Exception as e:
                logger.error(f"Error getting status: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e)
                }), 500
        
        @self.app.route('/health', methods=['GET'])
        def health_check():
            """Health check endpoint (root path)"""
            return jsonify({
                'success': True,
                'status': 'healthy',
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        @self.app.route('/api/health', methods=['GET'])
        def health_check_api():
            """Health check endpoint (API path)"""
            return jsonify({
                'success': True,
                'status': 'healthy',
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        @self.app.route('/api/config', methods=['GET'])
        def get_config():
            """Get camera configuration (sanitized)"""
            try:
                safe_config = {
                    'cameraId': self.config.get('cameraId'),
                    'siteId': self.config.get('siteId'),
                    'deviceId': self.config.get('deviceId'),
                    'detectionConfig': {
                        'objectClasses': self.config.get('detectionConfig', {}).get('objectClasses', []),
                        'confidenceThreshold': self.config.get('detectionConfig', {}).get('confidenceThreshold'),
                    }
                }
                return jsonify({'success': True, 'config': safe_config}), 200
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500
    
    def start_server(self):
        """Start the API server in a separate thread"""
        if self.server_running:
            return
        
        def run_server():
            self.server_running = True
            logger.info(f"Starting Camera Agent API server on port {self.port}")
            # Run Flask in development mode (use waitress/gunicorn for production)
            self.app.run(host='0.0.0.0', port=self.port, debug=False, threaded=True)
        
        self.api_thread = threading.Thread(target=run_server, daemon=True)
        self.api_thread.start()
        logger.info(f"API server thread started")
    
    def stop_server(self):
        """Stop the API server"""
        self.server_running = False
        # Flask development server doesn't have a clean shutdown
        # In production, use a proper WSGI server with shutdown support
        logger.info("API server stopped")
    
    def should_detect(self) -> bool:
        """Check if detection should be active"""
        return self.detection_active and self.agent.running
    
    def get_backend_config(self) -> Dict:
        """Get backend API configuration"""
        return {
            'backend_url': self.backend_url,
            'api_key': self.api_key,
            'report_interval': self.report_interval
        }

