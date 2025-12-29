#!/usr/bin/env python3
"""
Camera Status Update Utility
Updates camera document in Firestore with real-time status metrics
"""

import firebase_admin
from firebase_admin import credentials, firestore
import psutil
import time
import os
import sys
from pathlib import Path
from typing import Dict, Optional


def get_system_health() -> Dict:
    """Get system health metrics"""
    health = {}
    
    # CPU temperature (Raspberry Pi)
    try:
        temp_file = Path("/sys/class/thermal/thermal_zone0/temp")
        if temp_file.exists():
            temp_raw = temp_file.read_text().strip()
            health['cpuTemp'] = float(temp_raw) / 1000.0  # Convert millidegrees to Celsius
    except Exception:
        pass
    
    # Hailo temperature (if available)
    try:
        import subprocess
        result = subprocess.run(
            ['hailortcli', 'fw-control', 'device', '0', 'temperatures'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            # Parse temperature from output (format varies)
            health['hailoTemp'] = 0.0  # Placeholder - parse actual output
    except Exception:
        pass
    
    # CPU and memory usage
    health['cpuUsage'] = psutil.cpu_percent(interval=1)
    health['memoryUsage'] = psutil.virtual_memory().percent
    
    return health


def update_camera_status(
    camera_id: str,
    fps: Optional[float] = None,
    frame_count: Optional[int] = None,
    detector_status: Optional[Dict] = None,
    system_health: Optional[Dict] = None,
    firestore_client=None,
    service_account_path: str = "/opt/camera-agent/config/service-account.json"
):
    """
    Update camera document in Firestore with status metrics
    
    Args:
        camera_id: Camera ID
        fps: Current frames per second
        frame_count: Total frames processed
        detector_status: Detector status dict
        system_health: System health dict (auto-detected if None)
        firestore_client: Firestore client (initialized if None)
        service_account_path: Path to service account JSON
    """
    # Initialize Firebase if needed
    if firestore_client is None:
        if not firebase_admin._apps:
            if not Path(service_account_path).exists():
                print(f"❌ Service account not found: {service_account_path}")
                return False
            
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
        
        firestore_client = firestore.client()
    
    # Get system health if not provided
    if system_health is None:
        system_health = get_system_health()
    
    # Prepare update data
    update_data = {
        'lastSeen': firestore.SERVER_TIMESTAMP,
        'status': 'online'
    }
    
    if fps is not None:
        update_data['fps'] = fps
    
    if frame_count is not None:
        update_data['frameCount'] = frame_count
    
    if detector_status:
        update_data['detectorStatus'] = detector_status
    
    if system_health:
        system_health['timestamp'] = firestore.SERVER_TIMESTAMP
        update_data['systemHealth'] = system_health
    
    try:
        # Update camera document
        camera_ref = firestore_client.collection('cameras').document(camera_id)
        camera_ref.update(update_data)
        return True
    except Exception as e:
        print(f"❌ Error updating camera status: {e}")
        return False


if __name__ == "__main__":
    """CLI usage"""
    if len(sys.argv) < 2:
        print("Usage: python update_camera_status.py <camera_id> [service_account_path]")
        sys.exit(1)
    
    camera_id = sys.argv[1]
    service_account_path = sys.argv[2] if len(sys.argv) > 2 else "/opt/camera-agent/config/service-account.json"
    
    print(f"Updating status for camera: {camera_id}")
    
    success = update_camera_status(
        camera_id=camera_id,
        fps=30.0,  # Example
        frame_count=1000,  # Example
        detector_status={
            'camera_active': True,
            'model_loaded': True,
            'fps': 30.0
        },
        service_account_path=service_account_path
    )
    
    if success:
        print("✅ Camera status updated successfully")
    else:
        print("❌ Failed to update camera status")
        sys.exit(1)
