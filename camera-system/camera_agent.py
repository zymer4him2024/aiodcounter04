#!/usr/bin/env python3
"""
Camera Edge Agent for Multi-Tier Object Detection Counter
Production-ready implementation with Firebase integration

Supports:
- Hailo-8 AI Accelerator (Raspberry Pi 5 + Hailo-8 HAT+)
- TensorFlow Lite (fallback)

Requirements:
- Python 3.8+
- HailoRT (for Hailo-8) OR TensorFlow Lite 2.x (fallback)
- OpenCV 4.x
- Firebase Admin SDK
- SQLAlchemy
"""

import numpy as np  # type: ignore  # type: ignore
import json
import time
import threading
import queue
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import firebase_admin  # type: ignore[import-untyped]  # Installed via requirements.txt
from firebase_admin import credentials, firestore, auth  # type: ignore[import-untyped]  # Installed via requirements.txt
# Import SQLAlchemy with error handling
try:
    from sqlalchemy import create_engine, Column, Integer, String, DateTime, JSON  # type: ignore[import-untyped]
    # SQLAlchemy 2.0+ uses sqlalchemy.orm for declarative_base
    try:
        from sqlalchemy.orm import declarative_base, sessionmaker  # type: ignore[import-untyped]
    except ImportError:
        # Fallback for SQLAlchemy < 2.0
        from sqlalchemy.ext.declarative import declarative_base  # type: ignore[import-untyped]
        from sqlalchemy.orm import sessionmaker  # type: ignore[import-untyped]
except ImportError:
    raise ImportError(
        "SQLAlchemy is required but not installed.\n"
        "Please install it using: pip install sqlalchemy>=1.4.0\n"
        "Or on Raspberry Pi: pip3 install sqlalchemy"
    )

import hashlib
import requests  # type: ignore[import-untyped]  # type: ignore[import-untyped]

# Import OpenCV with error handling
try:
    import cv2  # type: ignore
except ImportError:
    raise ImportError(
        "OpenCV (cv2) is required but not installed.\n"
        "Please install it using: pip install opencv-python>=4.5.0\n"
        "Or on Raspberry Pi: sudo apt-get install -y python3-opencv"
    )

# Try to import Hailo first (preferred for RPi 5 + Hailo-8)
HAILO_AVAILABLE = False
try:
    from hailo_platform import HEF, VDevice, InferVStreams  # type: ignore[import-untyped]
    HAILO_AVAILABLE = True
    logger_detect = logging.getLogger(__name__)
    logger_detect.info("Hailo-8 AI accelerator detected")
except ImportError:
    pass

# Fallback to TensorFlow Lite if Hailo not available
TFLITE_AVAILABLE = False
tflite = None  # Will be set if import succeeds

if not HAILO_AVAILABLE:
    try:
        import tflite_runtime.interpreter as tflite  # type: ignore
        TFLITE_AVAILABLE = True
        logger_detect = logging.getLogger(__name__)
        logger_detect.info("Using TensorFlow Lite (Hailo-8 not available)")
    except ImportError:
        TFLITE_AVAILABLE = False
        raise ImportError("Neither Hailo-8 nor TensorFlow Lite available. Please install one of them.")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/camera_agent.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Database models for local buffering
Base = declarative_base()

class BufferedCount(Base):
    __tablename__ = 'buffered_counts'
    
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, nullable=False)
    camera_id = Column(String(50), nullable=False)
    counts_json = Column(JSON, nullable=False)
    metadata_json = Column(JSON)
    uploaded = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

class CameraEdgeAgent:
    """Main camera edge agent class"""
    
    def __init__(self, config_path: str):
        """Initialize camera agent with configuration"""
        self.config = self._load_config(config_path)
        self.running = False
        self.detection_active = False  # Controlled via API
        
        # Queues for inter-thread communication
        self.frame_queue = queue.Queue(maxsize=30)
        self.detection_queue = queue.Queue(maxsize=100)
        self.upload_queue = queue.Queue(maxsize=1000)
        
        # Backend API configuration (set via API calls)
        self.backend_url = None
        self.backend_api_key = None
        self.backend_report_interval = 5
        self.last_backend_report = None
        
        # Initialize components
        self._init_database()
        self._init_firebase()
        self._init_detector()
        self._init_tracker()
        
        # Initialize API server if enabled
        self.api_server = None
        if self.config.get('apiConfig', {}).get('enabled', True):
            self._init_api_server()
        
        logger.info(f"Camera agent initialized: {self.config['cameraId']}")
    
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from JSON file"""
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # Validate required fields
        required = ['cameraId', 'siteId', 'orgId', 'firebaseConfig', 'detectionConfig']
        for field in required:
            if field not in config:
                raise ValueError(f"Missing required config field: {field}")
        
        return config
    
    def _init_database(self):
        """Initialize local SQLite database for buffering"""
        db_path = f"/var/lib/camera_agent/{self.config['cameraId']}.db"
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        
        self.engine = create_engine(f'sqlite:///{db_path}')
        Base.metadata.create_all(self.engine)
        Session = sessionmaker(bind=self.engine)
        self.db_session = Session()
        
        logger.info(f"Local database initialized: {db_path}")
    
    def _init_firebase(self):
        """Initialize Firebase connection"""
        try:
            # Initialize Firebase app with service account
            cred = credentials.Certificate(self.config.get('serviceAccountPath', 'service-account.json'))
            firebase_admin.initialize_app(cred, {
                'projectId': self.config['firebaseConfig']['projectId']
            })
            
            self.firestore_client = firestore.client()
            logger.info("Firebase initialized successfully")
        except Exception as e:
            logger.error(f"Firebase initialization failed: {e}")
            # Agent can still run without Firebase (will buffer locally)
    
    def _init_detector(self):
        """Initialize object detection model (Hailo-8 or TensorFlow Lite)"""
        model_path = self.config['detectionConfig']['modelPath']
        
        # Check if model file exists
        if not Path(model_path).exists():
            error_msg = f"Model file not found: {model_path}"
            logger.error(error_msg)
            if HAILO_AVAILABLE:
                raise FileNotFoundError(
                    f"{error_msg}\n"
                    f"Please ensure the HEF model file is installed on the Raspberry Pi.\n"
                    f"Expected locations: /opt/camera-agent/models/yolov8n.hef or /opt/camera-agent/model.hef\n"
                    f"For Hailo-8, you need a HEF (Hailo Executable Format) file, not TFLite."
                )
            else:
                raise FileNotFoundError(
                    f"{error_msg}\n"
                    f"Please ensure the model file is installed on the Raspberry Pi.\n"
                    f"Expected locations: /opt/camera-agent/model.tflite or /opt/camera-agent/models/yolov8n.tflite"
                )
        
        # Model configuration
        self.confidence_threshold = self.config['detectionConfig']['confidenceThreshold']
        self.object_classes = self.config['detectionConfig']['objectClasses']
        self.detector_type = None
        
        # Try Hailo-8 first
        if HAILO_AVAILABLE and model_path.endswith('.hef'):
            self._init_hailo_detector(model_path)
        elif HAILO_AVAILABLE and TFLITE_AVAILABLE:
            # If Hailo available but model is .tflite, check if we should prefer Hailo
            logger.warning("Hailo-8 available but model is TFLite format. Using TFLite.")
            logger.warning("For better performance, use a HEF model file (.hef)")
            self._init_tflite_detector(model_path)
        elif TFLITE_AVAILABLE:
            self._init_tflite_detector(model_path)
        else:
            raise RuntimeError("No compatible inference engine available")
    
    def _init_hailo_detector(self, model_path: str):
        """Initialize Hailo-8 detector"""
        try:
            logger.info("Initializing Hailo-8 AI Accelerator...")
            
            # Load HEF model
            self.hef = HEF(model_path)
            
            # Create virtual device
            self.vdevice = VDevice()
            
            # Configure network group
            self.network_group = self.vdevice.configure(self.hef)
            
            # Get input/output vstreams
            self.network_group_params = self.network_group.create_params()
            
            # Get input/output shapes
            input_vstream_info = self.network_group.get_input_vstream_infos()[0]
            output_vstream_info = self.network_group.get_output_vstream_infos()[0]
            
            self.input_shape = input_vstream_info.shape
            self.output_shape = output_vstream_info.shape
            
            # Store network group params for inference
            # We'll create vstreams during each inference to ensure thread safety
            
            self.detector_type = 'hailo'
            
            logger.info(f"✓ Hailo-8 model loaded: {model_path}")
            logger.info(f"  Input shape: {self.input_shape}")
            logger.info(f"  Output shape: {self.output_shape}")
            logger.info(f"  Object classes: {self.object_classes}")
            logger.info(f"  Confidence threshold: {self.confidence_threshold}")
            logger.info("  Using Hailo-8 AI Accelerator for inference")
            
        except Exception as e:
            logger.error(f"Failed to initialize Hailo-8 detector: {e}")
            raise
    
    def _init_tflite_detector(self, model_path: str):
        """Initialize TensorFlow Lite detector (fallback)"""
        if not TFLITE_AVAILABLE or tflite is None:
            raise RuntimeError("TensorFlow Lite is not available")
        
        try:
            logger.info("Initializing TensorFlow Lite detector...")
            
            self.interpreter = tflite.Interpreter(model_path=model_path)
            self.interpreter.allocate_tensors()
            
            # Get input and output details
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            self.detector_type = 'tflite'
            
            logger.info(f"✓ TensorFlow Lite model loaded: {model_path}")
            logger.info(f"  Input shape: {self.input_details[0]['shape']}")
            logger.info(f"  Number of output tensors: {len(self.output_details)}")
            logger.info(f"  Object classes: {self.object_classes}")
            logger.info(f"  Confidence threshold: {self.confidence_threshold}")
            
        except Exception as e:
            logger.error(f"Failed to load TFLite model: {e}")
            raise
    
    def _init_tracker(self):
        """Initialize object tracker for preventing double counting"""
        self.tracked_objects = {}
        self.next_object_id = 0
        self.max_disappeared = 30  # frames
        self.max_distance = 50  # pixels
    
    def _point_in_polygon(self, point: Tuple[int, int], polygon: List[List[int]]) -> bool:
        """Check if point is inside polygon (detection zone)"""
        x, y = point
        n = len(polygon)
        inside = False
        
        j = n - 1
        for i in range(n):
            xi, yi = polygon[i]
            xj, yj = polygon[j]
            
            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
                inside = not inside
            j = i
        
        return inside
    
    def capture_thread(self):
        """Thread for capturing video frames"""
        cap = cv2.VideoCapture(0)  # USB camera or RTSP stream
        cap.set(cv2.CAP_PROP_FPS, 15)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        
        logger.info("Video capture started")
        
        last_fps_time = time.time()
        fps_frame_count = 0
        
        while self.running:
            ret, frame = cap.read()
            if not ret:
                logger.warning("Failed to capture frame")
                time.sleep(0.1)
                continue
            
            # Update frame count and FPS
            if hasattr(self, 'frame_count'):
                self.frame_count += 1
            fps_frame_count += 1
            
            # Calculate FPS every second
            current_time = time.time()
            if current_time - last_fps_time >= 1.0:
                if hasattr(self, 'current_fps'):
                    self.current_fps = fps_frame_count / (current_time - last_fps_time)
                fps_frame_count = 0
                last_fps_time = current_time
            
            # Put frame in queue (drop if full)
            try:
                self.frame_queue.put(frame, block=False)
            except queue.Full:
                pass  # Drop frame if queue is full
            
            time.sleep(1/15)  # 15 FPS
        
        cap.release()
        logger.info("Video capture stopped")
    
    def detection_thread(self):
        """Thread for running object detection on frames"""
        logger.info("Detection thread started")
        
        while self.running:
            # Skip detection if not active (controlled via API)
            if not self.detection_active:
                time.sleep(0.5)
                continue
            
            try:
                frame = self.frame_queue.get(timeout=1)
            except queue.Empty:
                continue
            
            # Run inference based on detector type
            if self.detector_type == 'hailo':
                detections, inference_time = self._run_hailo_inference(frame)
            else:  # tflite
                detections, inference_time = self._run_tflite_inference(frame)
            
            # Put detections in queue with timestamp
            self.detection_queue.put({
                'timestamp': datetime.utcnow(),
                'detections': detections,
                'inference_time': inference_time
            })
        
        logger.info("Detection thread stopped")
    
    def _run_hailo_inference(self, frame: np.ndarray) -> Tuple[List[Dict], float]:
        """Run inference using Hailo-8 accelerator"""
        start_time = time.time()
        
        # Get input shape (Hailo format: [batch, height, width, channels])
        input_height, input_width = self.input_shape[1], self.input_shape[2]
        
        # Preprocess frame
        resized_frame = cv2.resize(frame, (input_width, input_height))
        
        # Hailo expects NHWC format, normalized 0-255
        input_data = resized_frame.astype(np.uint8)
        input_data = np.expand_dims(input_data, axis=0)  # Add batch dimension
        
        try:
            # Create vstreams for this inference (thread-safe)
            with InferVStreams(self.network_group, self.network_group_params) as infer_pipeline:
                input_vstreams = infer_pipeline.input
                output_vstreams = infer_pipeline.output
                
                # Run inference on Hailo-8
                input_vstreams[0].send(input_data)
                output_data = output_vstreams[0].recv()
            
            inference_time = (time.time() - start_time) * 1000
            
            # Post-process Hailo output (format depends on YOLO model)
            # Hailo YOLO outputs: [batch, num_detections, 6] where 6 = [x, y, w, h, conf, class]
            # Or flattened format depending on model
            detections = self._parse_hailo_yolo_output(output_data, frame.shape[:2])
            
            return detections, inference_time
            
        except Exception as e:
            logger.error(f"Hailo inference error: {e}")
            return [], 0.0
    
    def _run_tflite_inference(self, frame: np.ndarray) -> Tuple[List[Dict], float]:
        """Run inference using TensorFlow Lite"""
        start_time = time.time()
        
        # Preprocess frame
        input_shape = self.input_details[0]['shape']
        input_height, input_width = input_shape[1], input_shape[2]
        
        resized_frame = cv2.resize(frame, (input_width, input_height))
        input_data = np.expand_dims(resized_frame, axis=0)
        
        if self.input_details[0]['dtype'] == np.uint8:
            input_data = input_data.astype(np.uint8)
        else:
            input_data = (input_data.astype(np.float32) - 127.5) / 127.5
        
        # Run inference
        self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self.interpreter.invoke()
        inference_time = (time.time() - start_time) * 1000
        
        # Get detections
        boxes = self.interpreter.get_tensor(self.output_details[0]['index'])[0]
        classes = self.interpreter.get_tensor(self.output_details[1]['index'])[0]
        scores = self.interpreter.get_tensor(self.output_details[2]['index'])[0]
        
        # Parse detections
        detections = self._parse_tflite_yolo_output(boxes, classes, scores, frame.shape[:2])
        
        return detections, inference_time
    
    def _parse_hailo_yolo_output(self, output_data: np.ndarray, frame_shape: Tuple[int, int]) -> List[Dict]:
        """Parse Hailo YOLO output format to detections"""
        detections = []
        height, width = frame_shape
        
        # Hailo YOLO output format varies by model
        # Common formats:
        # 1. [batch, num_detections, 6] - [x, y, w, h, conf, class_id]
        # 2. Separate tensors for boxes, scores, classes
        # 3. Flattened format
        
        output_shape = output_data.shape
        logger.debug(f"Hailo output shape: {output_shape}")
        
        # Handle different output formats
        if len(output_shape) == 3 and output_shape[2] >= 6:
            # Format: [batch, num_detections, 6+]
            num_detections = output_shape[1]
            for i in range(num_detections):
                det = output_data[0, i]
                if len(det) >= 6:
                    # Assuming format: [x_center, y_center, width, height, confidence, class_id, ...]
                    x_center, y_center, w, h, conf, class_id = det[0:6]
                    
                    if conf > self.confidence_threshold:
                        class_id = int(class_id)
                        if 0 <= class_id < len(self.object_classes):
                            # Convert normalized coordinates to pixel coordinates
                            x_center_px = int(x_center * width)
                            y_center_px = int(y_center * height)
                            w_px = int(w * width)
                            h_px = int(h * height)
                            
                            x1 = max(0, x_center_px - w_px // 2)
                            y1 = max(0, y_center_px - h_px // 2)
                            x2 = min(width, x_center_px + w_px // 2)
                            y2 = min(height, y_center_px + h_px // 2)
                            
                            detections.append({
                                'class': self.object_classes[class_id],
                                'confidence': float(conf),
                                'bbox': [x1, y1, x2, y2],
                                'center': (x_center_px, y_center_px)
                            })
        
        return detections
    
    def _parse_tflite_yolo_output(self, boxes: np.ndarray, classes: np.ndarray, scores: np.ndarray, frame_shape: Tuple[int, int]) -> List[Dict]:
        """Parse TFLite YOLO output format to detections"""
        detections = []
        height, width = frame_shape
        
        for i in range(len(scores)):
            if scores[i] > self.confidence_threshold:
                class_id = int(classes[i])
                if class_id < len(self.object_classes):
                    ymin, xmin, ymax, xmax = boxes[i]
                    
                    # Convert to pixel coordinates
                    x1 = int(xmin * width)
                    y1 = int(ymin * height)
                    x2 = int(xmax * width)
                    y2 = int(ymax * height)
                    
                    center_x = (x1 + x2) // 2
                    center_y = (y1 + y2) // 2
                    
                    detections.append({
                        'class': self.object_classes[class_id],
                        'confidence': float(scores[i]),
                        'bbox': [x1, y1, x2, y2],
                        'center': (center_x, center_y)
                    })
        
        return detections
    
    def counting_thread(self):
        """Thread for counting objects and aggregating data"""
        logger.info("Counting thread started")
        
        # Initialize counts structure
        # If no zones, create a default "all" zone to count everything
        zones = self.config['detectionConfig'].get('detectionZones', [])
        use_default_zone = len(zones) == 0
        
        if use_default_zone:
            # No zones defined - count everything in a default zone
            logger.info("No detection zones defined - counting all detections in 'all' zone")
            zones = [{'name': 'all', 'polygon': [], 'direction': 'bidirectional'}]
        
        current_counts = {zone['name']: {cls: {'in': 0, 'out': 0} 
                                        for cls in self.object_classes}
                         for zone in zones}
        
        aggregation_interval = self.config['transmissionConfig']['aggregationInterval']
        next_aggregation = datetime.utcnow() + timedelta(seconds=aggregation_interval)
        
        logger.info(f"Counting initialized with {len(zones)} zone(s), aggregation interval: {aggregation_interval}s")
        
        while self.running:
            try:
                detection_data = self.detection_queue.get(timeout=1)
            except queue.Empty:
                # Check if it's time to aggregate
                if datetime.utcnow() >= next_aggregation:
                    self._aggregate_and_queue(current_counts)
                    
                    # Reset counts
                    current_counts = {zone['name']: {cls: {'in': 0, 'out': 0} 
                                                    for cls in self.object_classes}
                                     for zone in zones}
                    
                    next_aggregation = datetime.utcnow() + timedelta(seconds=aggregation_interval)
                continue
            
            # Process detections
            for detection in detection_data['detections']:
                center = detection['center']
                obj_class = detection['class']
                
                # If no zones defined, count all detections in default 'all' zone
                if use_default_zone:
                    # Count all detections in the default 'all' zone
                    current_counts['all'][obj_class]['in'] += 1
                    current_counts['all'][obj_class]['out'] += 1
                else:
                    # Check which zone the object is in
                    counted = False
                    for zone in zones:
                        polygon = zone.get('polygon', [])
                        # If polygon is empty or point is in polygon, count it
                        if not polygon or self._point_in_polygon(center, polygon):
                            direction = zone.get('direction', 'bidirectional')
                            
                            # Simple counting logic (in production, use centroid tracking)
                            if direction in ['in', 'bidirectional']:
                                current_counts[zone['name']][obj_class]['in'] += 1
                            if direction in ['out', 'bidirectional']:
                                current_counts[zone['name']][obj_class]['out'] += 1
                            counted = True
                            break
                    
                    # If object not in any zone (shouldn't happen if zones cover full frame), still count it
                    if not counted:
                        logger.debug(f"Object {obj_class} at {center} not in any zone, counting in 'all' zone")
                        if 'all' not in current_counts:
                            current_counts['all'] = {cls: {'in': 0, 'out': 0} for cls in self.object_classes}
                        current_counts['all'][obj_class]['in'] += 1
        
        logger.info("Counting thread stopped")
    
    def _aggregate_and_queue(self, counts: Dict):
        """Aggregate counts and queue for upload"""
        timestamp = datetime.utcnow()
        
        # Flatten counts for storage
        flattened_counts = {}
        for zone_name, zone_counts in counts.items():
            for obj_class, directions in zone_counts.items():
                if directions['in'] > 0 or directions['out'] > 0:
                    flattened_counts[f"{zone_name}_{obj_class}"] = directions
        
        if not flattened_counts:
            return  # No counts to upload
        
        # Calculate total objects
        total_objects = sum(d['in'] + d['out'] for d in flattened_counts.values())
        
        count_data = {
            'timestamp': timestamp.isoformat(),
            'cameraId': self.config['cameraId'],
            'siteId': self.config['siteId'],
            'orgId': self.config['orgId'],
            'aggregationInterval': self.config['transmissionConfig']['aggregationInterval'],
            'counts': flattened_counts,
            'metadata': {
                'version': '1.0',
                'processingTime': 0  # Placeholder
            }
        }
        
        # Backend API format (for sending to custom backend)
        backend_count_data = {
            'camera_id': self.config['cameraId'],
            'timestamp': timestamp.isoformat(),
            'counts': flattened_counts,
            'total_objects': total_objects,
            'frames_processed': getattr(self, 'frame_count', 0),
            'fps': getattr(self, 'current_fps', 0.0),
            'runtime_seconds': (timestamp - getattr(self, 'start_time', timestamp)).total_seconds() if hasattr(self, 'start_time') else 0
        }
        
        # Save to local database
        buffered = BufferedCount(
            timestamp=timestamp,
            camera_id=self.config['cameraId'],
            counts_json=count_data,
            metadata_json={'retry_count': 0, 'backend_data': backend_count_data}
        )
        self.db_session.add(buffered)
        self.db_session.commit()
        
        # Queue for upload to Firebase
        self.upload_queue.put(count_data)
        
        # Send to backend API if configured
        if self.backend_url and self.should_send_to_backend():
            self._send_to_backend(backend_count_data)
        
        logger.info(f"Aggregated counts: {total_objects} objects")
    
    def should_send_to_backend(self) -> bool:
        """Check if we should send counts to backend API"""
        if not self.backend_url:
            return False
        
        now = datetime.utcnow()
        if self.last_backend_report is None:
            return True
        
        elapsed = (now - self.last_backend_report).total_seconds()
        return elapsed >= self.backend_report_interval
    
    def _send_to_backend(self, count_data: Dict):
        """Send count data to backend API"""
        try:
            url = f"{self.backend_url.rstrip('/')}/api/detection/counts"
            headers = {'Content-Type': 'application/json'}
            if self.backend_api_key:
                headers['Authorization'] = f'Bearer {self.backend_api_key}'
                headers['X-API-Key'] = self.backend_api_key
            
            response = requests.post(
                url,
                json=count_data,
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                self.last_backend_report = datetime.utcnow()
                logger.debug(f"Sent counts to backend: {url}")
            else:
                logger.warning(f"Backend API returned {response.status_code}: {response.text}")
                
        except Exception as e:
            logger.error(f"Failed to send counts to backend: {e}")
    
    def _init_api_server(self):
        """Initialize REST API server"""
        try:
            import sys
            from pathlib import Path
            
            # Try importing from same directory
            api_module_path = Path(__file__).parent / 'camera_agent_api.py'
            if api_module_path.exists():
                import importlib.util
                spec = importlib.util.spec_from_file_location("camera_agent_api", api_module_path)
                camera_agent_api = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(camera_agent_api)
                CameraAgentAPI = camera_agent_api.CameraAgentAPI
            else:
                from camera_agent_api import CameraAgentAPI
            
            api_port = self.config.get('apiConfig', {}).get('port', 5000)
            self.api_server = CameraAgentAPI(self, self.config, port=api_port)
            self.api_server.start_server()
            logger.info(f"REST API server initialized on port {api_port}")
        except ImportError as e:
            logger.warning(f"camera_agent_api not available, REST API disabled: {e}")
        except Exception as e:
            logger.error(f"Failed to initialize API server: {e}")
    
    def set_detection_active(self, active: bool):
        """Set detection active state (called by API)"""
        self.detection_active = active
        logger.info(f"Detection {'activated' if active else 'deactivated'}")
    
    def set_backend_config(self, backend_url: str = None, api_key: str = None, report_interval: int = 5):
        """Set backend API configuration (called by API)"""
        if backend_url:
            self.backend_url = backend_url
        if api_key:
            self.backend_api_key = api_key
        if report_interval:
            self.backend_report_interval = report_interval
        logger.info(f"Backend config updated: url={backend_url}, interval={report_interval}s")
    
    def upload_thread(self):
        """Thread for uploading data to Firebase"""
        logger.info("Upload thread started")
        
        max_retries = self.config['transmissionConfig']['maxRetries']
        retry_delay = 5  # seconds
        
        while self.running:
            try:
                count_data = self.upload_queue.get(timeout=1)
            except queue.Empty:
                # Try to upload any buffered data
                self._upload_buffered_data()
                continue
            
            # Upload to Firebase
            success = self._upload_to_firebase(count_data)
            
            if success:
                # Mark as uploaded in local database
                self.db_session.query(BufferedCount).filter(
                    BufferedCount.timestamp == datetime.fromisoformat(count_data['timestamp'])
                ).update({'uploaded': 1})
                self.db_session.commit()
            else:
                # Will be retried in next cycle
                logger.warning(f"Upload failed, will retry: {count_data['timestamp']}")
        
        logger.info("Upload thread stopped")
    
    def _upload_to_firebase(self, count_data: Dict) -> bool:
        """Upload count data to Firestore"""
        try:
            # Reference: /cameras/{cameraId}/counts/{timestamp}
            # This matches the web dashboard's expected structure
            camera_id = count_data['cameraId']
            timestamp_doc_id = count_data['timestamp'].replace(':', '_').replace('-', '_')
            
            doc_ref = (self.firestore_client
                      .collection('cameras')
                      .document(camera_id)
                      .collection('counts')
                      .document(timestamp_doc_id))
            
            doc_ref.set(count_data)
            logger.info(f"Uploaded to Firebase: {count_data['timestamp']}")
            return True
            
        except Exception as e:
            logger.error(f"Firebase upload error: {e}")
            return False
    
    def _upload_buffered_data(self):
        """Upload any data that failed to upload previously"""
        buffered = (self.db_session.query(BufferedCount)
                   .filter(BufferedCount.uploaded == 0)
                   .order_by(BufferedCount.timestamp)
                   .limit(10)
                   .all())
        
        for record in buffered:
            success = self._upload_to_firebase(record.counts_json)
            if success:
                record.uploaded = 1
                self.db_session.commit()
            else:
                break  # Stop trying if one fails (likely network issue)
    
    def status_update_thread(self):
        """Thread for updating camera status in Firestore"""
        logger.info("Status update thread started")
        
        while self.running:
            try:
                # Update camera status every 60 seconds
                self._update_camera_status()
                time.sleep(60)
            except Exception as e:
                logger.error(f"Status update error: {e}")
                time.sleep(60)
        
        logger.info("Status update thread stopped")
    
    def _update_camera_status(self):
        """Update camera document status in Firestore"""
        try:
            if not hasattr(self, 'firestore_client') or self.firestore_client is None:
                return
            
            camera_ref = self.firestore_client.collection('cameras').document(self.config['cameraId'])
            
            update_data = {
                'status': 'online',
                'lastSeen': firestore.SERVER_TIMESTAMP
            }
            
            # Add frame count if available
            if hasattr(self, 'frame_count'):
                update_data['frameCount'] = self.frame_count
            
            # Add FPS if calculated
            if hasattr(self, 'current_fps'):
                update_data['fps'] = self.current_fps
            
            camera_ref.update(update_data)
            logger.debug(f"Camera status updated: {self.config['cameraId']}")
            
        except Exception as e:
            logger.error(f"Failed to update camera status: {e}")
    
    def start(self):
        """Start all threads"""
        self.running = True
        # Detection starts inactive by default (controlled via API)
        self.detection_active = self.config.get('apiConfig', {}).get('autoStart', False)
        
        # Initialize counters
        self.frame_count = 0
        self.current_fps = 0.0
        self.start_time = time.time()
        
        # Start threads
        threads = [
            threading.Thread(target=self.capture_thread, daemon=True),
            threading.Thread(target=self.detection_thread, daemon=True),
            threading.Thread(target=self.counting_thread, daemon=True),
            threading.Thread(target=self.upload_thread, daemon=True),
            threading.Thread(target=self.status_update_thread, daemon=True),
        ]
        
        for thread in threads:
            thread.start()
        
        logger.info(f"Camera agent started successfully (detection: {'active' if self.detection_active else 'inactive'})")
        
        # Keep main thread alive
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Shutdown signal received")
            self.stop()
    
    def stop(self):
        """Stop all threads gracefully"""
        logger.info("Stopping camera agent...")
        self.running = False
        time.sleep(2)  # Allow threads to finish
        
        self.db_session.close()
        logger.info("Camera agent stopped")

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python camera_agent.py <config.json>")
        sys.exit(1)
    
    config_path = sys.argv[1]
    agent = CameraEdgeAgent(config_path)
    agent.start()
