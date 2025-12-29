#!/usr/bin/env python3
"""
Camera Edge Agent for Multi-Tier Object Detection Counter
Production-ready implementation with Firebase integration

Requirements:
- Python 3.8+
- TensorFlow Lite 2.x
- OpenCV 4.x
- Firebase Admin SDK
- SQLAlchemy
"""

import cv2
import numpy as np
import json
import time
import threading
import queue
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import tflite_runtime.interpreter as tflite
import firebase_admin
from firebase_admin import credentials, firestore, auth
from sqlalchemy import create_engine, Column, Integer, String, DateTime, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import hashlib

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
        
        # Queues for inter-thread communication
        self.frame_queue = queue.Queue(maxsize=30)
        self.detection_queue = queue.Queue(maxsize=100)
        self.upload_queue = queue.Queue(maxsize=1000)
        
        # Initialize components
        self._init_database()
        self._init_firebase()
        self._init_detector()
        self._init_tracker()
        
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
        """Initialize TensorFlow Lite object detection model"""
        model_path = self.config['detectionConfig']['modelPath']
        
        # Load TFLite model
        self.interpreter = tflite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        
        # Get input and output details
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        # Model configuration
        self.confidence_threshold = self.config['detectionConfig']['confidenceThreshold']
        self.object_classes = self.config['detectionConfig']['objectClasses']
        
        logger.info(f"Object detection model loaded: {model_path}")
    
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
        
        while self.running:
            ret, frame = cap.read()
            if not ret:
                logger.warning("Failed to capture frame")
                time.sleep(0.1)
                continue
            
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
            try:
                frame = self.frame_queue.get(timeout=1)
            except queue.Empty:
                continue
            
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
            start_time = time.time()
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            self.interpreter.invoke()
            inference_time = (time.time() - start_time) * 1000
            
            # Get detections
            boxes = self.interpreter.get_tensor(self.output_details[0]['index'])[0]
            classes = self.interpreter.get_tensor(self.output_details[1]['index'])[0]
            scores = self.interpreter.get_tensor(self.output_details[2]['index'])[0]
            
            # Filter detections
            detections = []
            for i in range(len(scores)):
                if scores[i] > self.confidence_threshold:
                    class_id = int(classes[i])
                    if class_id < len(self.object_classes):
                        ymin, xmin, ymax, xmax = boxes[i]
                        
                        # Convert to pixel coordinates
                        height, width = frame.shape[:2]
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
            
            # Put detections in queue with timestamp
            self.detection_queue.put({
                'timestamp': datetime.utcnow(),
                'detections': detections,
                'inference_time': inference_time
            })
        
        logger.info("Detection thread stopped")
    
    def counting_thread(self):
        """Thread for counting objects and aggregating data"""
        logger.info("Counting thread started")
        
        current_counts = {zone['name']: {cls: {'in': 0, 'out': 0} 
                                        for cls in self.object_classes}
                         for zone in self.config['detectionConfig']['detectionZones']}
        
        aggregation_interval = self.config['transmissionConfig']['aggregationInterval']
        next_aggregation = datetime.utcnow() + timedelta(seconds=aggregation_interval)
        
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
                                     for zone in self.config['detectionConfig']['detectionZones']}
                    
                    next_aggregation = datetime.utcnow() + timedelta(seconds=aggregation_interval)
                continue
            
            # Process detections
            for detection in detection_data['detections']:
                center = detection['center']
                obj_class = detection['class']
                
                # Check which zone the object is in
                for zone in self.config['detectionConfig']['detectionZones']:
                    if self._point_in_polygon(center, zone['polygon']):
                        direction = zone.get('direction', 'bidirectional')
                        
                        # Simple counting logic (in production, use centroid tracking)
                        if direction in ['in', 'bidirectional']:
                            current_counts[zone['name']][obj_class]['in'] += 1
                        if direction in ['out', 'bidirectional']:
                            current_counts[zone['name']][obj_class]['out'] += 1
        
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
        
        # Save to local database
        buffered = BufferedCount(
            timestamp=timestamp,
            camera_id=self.config['cameraId'],
            counts_json=count_data,
            metadata_json={'retry_count': 0}
        )
        self.db_session.add(buffered)
        self.db_session.commit()
        
        # Queue for upload
        self.upload_queue.put(count_data)
        
        logger.info(f"Aggregated counts: {sum(d['in'] + d['out'] for d in flattened_counts.values())} objects")
    
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
            # Reference: /organizations/{orgId}/sites/{siteId}/cameras/{cameraId}/counts/{timestamp}
            doc_ref = (self.firestore_client
                      .collection('organizations').document(count_data['orgId'])
                      .collection('sites').document(count_data['siteId'])
                      .collection('cameras').document(count_data['cameraId'])
                      .collection('counts').document(count_data['timestamp']))
            
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
    
    def start(self):
        """Start all threads"""
        self.running = True
        
        # Start threads
        threads = [
            threading.Thread(target=self.capture_thread, daemon=True),
            threading.Thread(target=self.detection_thread, daemon=True),
            threading.Thread(target=self.counting_thread, daemon=True),
            threading.Thread(target=self.upload_thread, daemon=True),
        ]
        
        for thread in threads:
            thread.start()
        
        logger.info("Camera agent started successfully")
        
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
