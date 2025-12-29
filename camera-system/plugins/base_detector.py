#!/usr/bin/env python3
"""
Base Detector Plugin Interface
All detector plugins should inherit from this class
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Tuple
import numpy as np


class BaseDetector(ABC):
    """Base class for object detection plugins"""
    
    def __init__(self, config: Dict):
        """
        Initialize detector with configuration
        
        Args:
            config: Dictionary containing detector configuration
        """
        self.config = config
        self.confidence_threshold = config.get('confidenceThreshold', 0.5)
        self.object_classes = config.get('objectClasses', [])
    
    @abstractmethod
    def detect(self, frame: np.ndarray) -> List[Dict]:
        """
        Detect objects in a frame
        
        Args:
            frame: Input frame as numpy array (BGR format)
            
        Returns:
            List of detections, each containing:
            - 'class': str - Object class name
            - 'confidence': float - Detection confidence (0-1)
            - 'bbox': [x1, y1, x2, y2] - Bounding box coordinates
            - 'center': (x, y) - Center point of bounding box
        """
        pass
    
    @abstractmethod
    def load_model(self, model_path: str):
        """
        Load the detection model
        
        Args:
            model_path: Path to the model file
        """
        pass
    
    def filter_detections(self, detections: List[Dict]) -> List[Dict]:
        """
        Filter detections by confidence threshold
        
        Args:
            detections: List of raw detections
            
        Returns:
            Filtered list of detections
        """
        return [
            det for det in detections 
            if det.get('confidence', 0) >= self.confidence_threshold
        ]




