"""
Traffic Monitor Detection Plugin - Hailo Accelerated
Detects and counts: Cars, Buses, Trucks, Motorcycles, Pedestrians
Using Hailo-8 AI accelerator with YOLOv8
"""

import cv2
import numpy as np
from datetime import datetime
from typing import Dict, List, Any, Tuple
import time
from collections import defaultdict, deque
import logging

try:
    from hailo_platform import (HEF, VDevice, HailoStreamInterface, 
                                 InferVStreams, ConfigureParams,
                                 InputVStreamParams, OutputVStreamParams,
                                 FormatType)
except ImportError:
    HEF = None

import sys
sys.path.insert(0, '/opt/camera-agent')
from plugins.base_detector import BaseDetector

logger = logging.getLogger(__name__)


class LineCrossing:
    """Tracks objects crossing a virtual line."""
    
    def __init__(self, line_coords: List[Tuple[int, int]], name: str = "line"):
        self.p1 = np.array(line_coords[0])
        self.p2 = np.array(line_coords[1])
        self.name = name
        self.crossed_ids = set()
        self.counts = defaultdict(int)
        
    def check_crossing(self, track_id: int, prev_pos: np.ndarray, 
                      curr_pos: np.ndarray, obj_class: str) -> bool:
        if track_id in self.crossed_ids:
            return False
            
        line_vec = self.p2 - self.p1
        prev_vec = prev_pos - self.p1
        curr_vec = curr_pos - self.p1
        
        prev_cross = np.cross(line_vec, prev_vec)
        curr_cross = np.cross(line_vec, curr_vec)
        
        if prev_cross * curr_cross < 0:
            self.crossed_ids.add(track_id)
            self.counts[obj_class] += 1
            logger.debug(f"{obj_class} crossed {self.name} (ID: {track_id})")
            return True
            
        return False
    
    def reset(self):
        self.crossed_ids.clear()
        self.counts.clear()


class Detector(BaseDetector):
    """
    Hailo-accelerated traffic monitoring detector.
    
    Uses Hailo-8 AI processor for hardware-accelerated inference.
    Optimized for real-time performance on Raspberry Pi 5.
    """
    
    # COCO class IDs for traffic objects
    CLASS_MAPPING = {
        0: 'person',
        2: 'car',
        3: 'motorcycle',
        5: 'bus',
        7: 'truck'
    }
    
    COCO_CLASSES = [
        'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 
        'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign', 
        'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
        'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
        'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
        'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
        'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana',
        'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza',
        'donut', 'cake', 'chair', 'couch', 'potted plant', 'bed', 'dining table',
        'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone',
        'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock',
        'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
    ]
    
    def __init__(self):
        self.camera = None
        self.vdevice = None
        self.infer_pipeline = None
        self.hef = None
        self.config = None
        
        # Model parameters
        self.input_height = 640
        self.input_width = 640
        
        # Tracking
        self.tracks = {}
        self.next_track_id = 0
        self.max_track_age = 2.0
        
        # Counting
        self.lines = []
        self.total_counts = defaultdict(int)
        self.detections_log = []
        
        # Performance
        self.frame_count = 0
        self.fps = 0.0
        self.last_fps_update = time.time()
        self.fps_frame_count = 0
        
        # Status
        self.start_time = time.time()
        self.last_detection_time = None
        self.error_count = 0
        
    def initialize(self, config: Dict[str, Any]) -> bool:
        """Initialize camera, Hailo device, and model."""
        try:
            self.config = config
            logger.info("Initializing Hailo Traffic Monitor Plugin...")
            
            if HEF is None:
                logger.error("hailo_platform not installed. Run: pip install hailo-platform")
                return False
            
            # Initialize USB camera
            camera_index = config.get('camera_index', 0)
            logger.info(f"Opening USB camera {camera_index}...")
            
            self.camera = cv2.VideoCapture(camera_index)
            if not self.camera.isOpened():
                logger.error(f"Failed to open camera {camera_index}")
                return False
            
            # Set camera properties
            width, height = config.get('resolution', [1920, 1080])
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            self.camera.set(cv2.CAP_PROP_FPS, config.get('fps_target', 30))
            
            logger.info(f"Camera configured: {width}x{height}")
            
            # Load Hailo model
            model_path = config.get('model_path', '/opt/hailo-models/yolov8n.hef')
            logger.info(f"Loading Hailo model: {model_path}")
            
            self.hef = HEF(model_path)
            
            # Create Hailo device
            self.vdevice = VDevice()
            logger.info(f"✓ Hailo device created")
            
            # Configure network
            network_groups = self.vdevice.configure(self.hef)
            network_group = network_groups[0]
            
            # Get input/output streams
            input_vstreams_params = InputVStreamParams.make_from_network_group(
                network_group, quantized=False, format_type=FormatType.UINT8
            )
            output_vstreams_params = OutputVStreamParams.make_from_network_group(
                network_group, quantized=False, format_type=FormatType.FLOAT32
            )
            
            # Create inference pipeline
            self.infer_pipeline = InferVStreams(self.vdevice, input_vstreams_params, 
                                               output_vstreams_params)
            
            logger.info("✓ Hailo model loaded and configured")
            
            # Set confidence threshold
            self.confidence_threshold = config.get('confidence_threshold', 0.5)
            
            # Setup counting lines
            counting_lines = config.get('counting_lines', [])
            if not counting_lines:
                counting_lines = [{
                    'name': 'main_line',
                    'coords': [[0, height // 2], [width, height // 2]]
                }]
            
            for line_config in counting_lines:
                line = LineCrossing(
                    line_coords=line_config['coords'],
                    name=line_config.get('name', 'line')
                )
                self.lines.append(line)
                logger.info(f"✓ Counting line added: {line.name}")
            
            # Target classes
            self.target_classes = config.get('detection_classes', 
                                           ['person', 'car', 'motorcycle', 'bus', 'truck'])
            logger.info(f"Target classes: {self.target_classes}")
            
            logger.info("✓ Hailo Traffic Monitor initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Initialization failed: {e}", exc_info=True)
            self.error_count += 1
            return False
    
    def preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        """Preprocess frame for Hailo model input."""
        # Resize to model input size
        resized = cv2.resize(frame, (self.input_width, self.input_height))
        
        # Convert BGR to RGB
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        
        # Normalize to 0-255 uint8 (Hailo expects this)
        return rgb
    
    def postprocess_detections(self, outputs: List[np.ndarray], 
                               orig_width: int, orig_height: int) -> List[Dict]:
        """Post-process Hailo output to get detections."""
        detections = []
        
        # YOLOv8 output format: [batch, num_detections, 85]
        # 85 = [x, y, w, h, confidence, class_0, class_1, ..., class_79]
        output = outputs[0][0]  # Get first batch
        
        for detection in output:
            # Extract bbox and confidence
            x_center, y_center, w, h = detection[:4]
            obj_conf = detection[4]
            class_scores = detection[5:]
            
            # Get best class
            class_id = np.argmax(class_scores)
            class_conf = class_scores[class_id]
            
            # Total confidence
            confidence = obj_conf * class_conf
            
            if confidence < self.confidence_threshold:
                continue
            
            # Filter for target classes
            if class_id not in self.CLASS_MAPPING:
                continue
            
            obj_class = self.CLASS_MAPPING[class_id]
            if obj_class not in self.target_classes:
                continue
            
            # Convert from normalized to pixel coordinates
            x1 = int((x_center - w/2) * orig_width / self.input_width)
            y1 = int((y_center - h/2) * orig_height / self.input_height)
            x2 = int((x_center + w/2) * orig_width / self.input_width)
            y2 = int((y_center + h/2) * orig_height / self.input_height)
            
            # Clamp to frame bounds
            x1 = max(0, min(x1, orig_width))
            y1 = max(0, min(y1, orig_height))
            x2 = max(0, min(x2, orig_width))
            y2 = max(0, min(y2, orig_height))
            
            detections.append({
                'class': obj_class,
                'confidence': float(confidence),
                'bbox': [x1, y1, x2, y2],
                'center': [int((x1 + x2) / 2), int((y1 + y2) / 2)]
            })
        
        return detections
    
    def detect_frame(self) -> Dict[str, Any]:
        """Process one frame with Hailo acceleration."""
        try:
            # Capture frame
            ret, frame = self.camera.read()
            if not ret:
                logger.warning("Failed to capture frame")
                self.error_count += 1
                return {'detections': [], 'frame_number': self.frame_count,
                       'timestamp': datetime.utcnow().isoformat() + 'Z', 'fps': self.fps}
            
            self.frame_count += 1
            orig_height, orig_width = frame.shape[:2]
            
            # Preprocess
            input_data = self.preprocess_frame(frame)
            
            # Run Hailo inference
            with self.infer_pipeline as pipeline:
                input_dict = {pipeline.input_vstream_infos[0].name: input_data}
                output_dict = pipeline.infer(input_dict)
                outputs = list(output_dict.values())
            
            # Post-process
            detections = self.postprocess_detections(outputs, orig_width, orig_height)
            
            # Update tracking and counting
            current_time = time.time()
            for detection in detections:
                center = np.array(detection['center'])
                obj_class = detection['class']
                
                # Track object
                track_id = self._update_tracking(center, obj_class, current_time)
                detection['track_id'] = track_id
                
                # Check line crossings
                if track_id in self.tracks:
                    positions = self.tracks[track_id]['positions']
                    if len(positions) >= 2:
                        prev_pos = positions[-2]
                        curr_pos = positions[-1]
                        
                        for line in self.lines:
                            if line.check_crossing(track_id, prev_pos, curr_pos, obj_class):
                                self.total_counts[obj_class] += 1
                                self.detections_log.append({
                                    'timestamp': datetime.utcnow().isoformat() + 'Z',
                                    'class': obj_class,
                                    'confidence': detection['confidence'],
                                    'line': line.name,
                                    'track_id': track_id,
                                    'position': detection['center']
                                })
                                self.last_detection_time = datetime.utcnow().isoformat() + 'Z'
            
            # Cleanup old tracks
            self._cleanup_tracks(current_time)
            
            # Update FPS
            self._update_fps()
            
            return {
                'detections': detections,
                'frame_number': self.frame_count,
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'fps': self.fps,
                'active_tracks': len(self.tracks)
            }
            
        except Exception as e:
            logger.error(f"Error in detect_frame: {e}", exc_info=True)
            self.error_count += 1
            return {'detections': [], 'frame_number': self.frame_count,
                   'timestamp': datetime.utcnow().isoformat() + 'Z', 'fps': self.fps}
    
    def _update_tracking(self, center: np.ndarray, obj_class: str, 
                        current_time: float) -> int:
        """Simple centroid-based tracking."""
        max_distance = 100
        
        best_track_id = None
        best_distance = max_distance
        
        for track_id, track in self.tracks.items():
            if track['class'] != obj_class:
                continue
            if len(track['positions']) == 0:
                continue
                
            last_pos = track['positions'][-1]
            distance = np.linalg.norm(center - last_pos)
            
            if distance < best_distance:
                best_distance = distance
                best_track_id = track_id
        
        if best_track_id is not None:
            self.tracks[best_track_id]['positions'].append(center)
            self.tracks[best_track_id]['last_seen'] = current_time
            return best_track_id
        else:
            track_id = self.next_track_id
            self.next_track_id += 1
            self.tracks[track_id] = {
                'class': obj_class,
                'positions': deque([center], maxlen=10),
                'last_seen': current_time
            }
            return track_id
    
    def _cleanup_tracks(self, current_time: float):
        """Remove old tracks."""
        to_remove = [tid for tid, track in self.tracks.items() 
                    if current_time - track['last_seen'] > self.max_track_age]
        for tid in to_remove:
            del self.tracks[tid]
    
    def _update_fps(self):
        """Calculate FPS."""
        self.fps_frame_count += 1
        if time.time() - self.last_fps_update >= 1.0:
            self.fps = self.fps_frame_count / (time.time() - self.last_fps_update)
            self.fps_frame_count = 0
            self.last_fps_update = time.time()
    
    def get_counts(self) -> Dict[str, Any]:
        """Get accumulated counts."""
        counts = dict(self.total_counts)
        line_counts = {line.name: dict(line.counts) for line in self.lines}
        
        return {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'interval_seconds': 120,
            'counts': counts,
            'total': sum(counts.values()),
            'lines': line_counts
        }
    
    def get_detections_log(self) -> List[Dict[str, Any]]:
        """Get individual detection events."""
        return self.detections_log.copy()
    
    def reset_counts(self):
        """Reset counters."""
        self.total_counts.clear()
        self.detections_log.clear()
        for line in self.lines:
            line.reset()
        logger.info("Counts reset")
    
    def cleanup(self):
        """Release resources."""
        logger.info("Cleaning up Hailo Traffic Monitor...")
        
        if self.camera:
            self.camera.release()
            logger.info("✓ Camera released")
        
        if self.infer_pipeline:
            del self.infer_pipeline
            logger.info("✓ Pipeline released")
        
        if self.vdevice:
            del self.vdevice
            logger.info("✓ Hailo device released")
        
        logger.info("✓ Cleanup complete")
    
    def get_status(self) -> Dict[str, Any]:
        """Get status."""
        return {
            'camera_active': self.camera is not None and self.camera.isOpened(),
            'model_loaded': self.hef is not None,
            'hailo_active': self.vdevice is not None,
            'fps': round(self.fps, 2),
            'last_detection': self.last_detection_time,
            'total_frames_processed': self.frame_count,
            'active_tracks': len(self.tracks),
            'error_count': self.error_count,
            'uptime_seconds': int(time.time() - self.start_time),
            'total_counted': sum(self.total_counts.values())
        }
    
    def update_config(self, config: Dict[str, Any]) -> bool:
        """Update configuration."""
        try:
            if 'confidence_threshold' in config:
                self.confidence_threshold = config['confidence_threshold']
                logger.info(f"Updated confidence: {self.confidence_threshold}")
            
            if 'detection_classes' in config:
                self.target_classes = config['detection_classes']
                logger.info(f"Updated classes: {self.target_classes}")
            
            return True
        except Exception as e:
            logger.error(f"Config update failed: {e}")
            return False
    
    def get_plugin_info(self) -> Dict[str, str]:
        """Get plugin info."""
        return {
            'name': 'traffic_monitor_hailo',
            'version': '1.0.0',
            'description': 'Hailo-accelerated traffic monitoring with YOLOv8',
            'author': 'DigiOptics OD',
            'supported_classes': ['person', 'car', 'motorcycle', 'bus', 'truck'],
            'camera_type': 'USB',
            'accelerator': 'Hailo-8',
            'model': 'YOLOv8 (HEF)'
        }
