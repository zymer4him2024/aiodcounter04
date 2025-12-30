#!/usr/bin/env python3
"""
Camera Configuration Generator
Generates config.json for camera agent based on camera details from dashboard
"""

import json
import sys
import os
from pathlib import Path

# Default Firebase config (matches web dashboard)
DEFAULT_FIREBASE_CONFIG = {
    "apiKey": "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
    "authDomain": "aiodcouter04.firebaseapp.com",
    "projectId": "aiodcouter04",
    "storageBucket": "aiodcouter04.firebasestorage.app",
    "messagingSenderId": "87816815492",
    "appId": "1:87816815492:web:849f2866d2fd63baf393d1"
}

# Default detection config
DEFAULT_DETECTION_CONFIG = {
    "modelPath": "/opt/camera-agent/models/yolov8n.tflite",
    "objectClasses": ["person", "vehicle", "forklift"],
    "confidenceThreshold": 0.75,
    "detectionZones": []
}

# Default transmission config
DEFAULT_TRANSMISSION_CONFIG = {
    "aggregationInterval": 300,  # 5 minutes
    "maxRetries": 3,
    "timeout": 10000
}


def generate_config(camera_id, site_id, org_id="aiodcouter04", 
                   service_account_path="/opt/camera-agent/config/service-account.json",
                   output_path=None):
    """
    Generate camera configuration JSON
    
    Args:
        camera_id: Camera ID from dashboard (e.g., "CAM_ABC1234")
        site_id: Site ID from dashboard
        org_id: Organization ID (default: "aiodcouter04")
        service_account_path: Path to service account JSON
        output_path: Output file path (default: config.json in current directory)
    
    Returns:
        dict: Configuration dictionary
    """
    config = {
        "cameraId": camera_id,
        "siteId": site_id,
        "orgId": org_id,
        "serviceAccountPath": service_account_path,
        "firebaseConfig": DEFAULT_FIREBASE_CONFIG,
        "detectionConfig": DEFAULT_DETECTION_CONFIG,
        "transmissionConfig": DEFAULT_TRANSMISSION_CONFIG
    }
    
    if output_path:
        output_file = Path(output_path)
    else:
        output_file = Path("config.json")
    
    # Write to file
    with open(output_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Configuration generated: {output_file.absolute()}")
    print(f"\n📋 Configuration Summary:")
    print(f"   Camera ID: {camera_id}")
    print(f"   Site ID: {site_id}")
    print(f"   Service Account: {service_account_path}")
    print(f"\n📝 Next steps:")
    print(f"   1. Copy this file to RPi: /opt/camera-agent/config/config.json")
    print(f"   2. Ensure service account file exists at: {service_account_path}")
    print(f"   3. Start camera agent: sudo systemctl start camera-agent")
    
    return config


def main():
    """Interactive configuration generator"""
    print("=" * 60)
    print("Camera Configuration Generator")
    print("=" * 60)
    print()
    
    if len(sys.argv) >= 3:
        # Command line mode
        camera_id = sys.argv[1]
        site_id = sys.argv[2]
        org_id = sys.argv[3] if len(sys.argv) > 3 else "aiodcouter04"
        output_path = sys.argv[4] if len(sys.argv) > 4 else None
    else:
        # Interactive mode
        print("Enter camera details from dashboard:")
        print()
        camera_id = input("Camera ID (e.g., CAM_ABC1234): ").strip()
        site_id = input("Site ID: ").strip()
        org_id = input("Organization ID [aiodcouter04]: ").strip() or "aiodcouter04"
        
        output_path = input("Output file [config.json]: ").strip()
        if not output_path:
            output_path = None
    
    if not camera_id or not site_id:
        print("❌ Error: Camera ID and Site ID are required")
        sys.exit(1)
    
    generate_config(camera_id, site_id, org_id, output_path=output_path)


if __name__ == "__main__":
    main()



