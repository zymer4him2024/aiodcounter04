#!/usr/bin/env python3
"""
Raspberry Pi First Boot Registration Script
Reads /boot/provision.json, registers device with Firebase, and creates .env file
"""

import json
import os
import sys
import requests
import hashlib
from pathlib import Path
from typing import Dict, Optional

# Configuration
PROVISION_FILE = Path("/boot/provision.json")
PROVISION_DONE_FILE = Path("/boot/provision.done")
APP_DIR = Path(os.environ.get("APP_DIR", "/opt/aiodcounter03"))
ENV_FILE = APP_DIR / ".env"
FIREBASE_FUNCTION_URL = os.environ.get(
    "FIREBASE_FUNCTION_URL",
    "https://us-central1-aiodcouter04.cloudfunctions.net/registerDevice"
)


def read_provision_file() -> Optional[Dict]:
    """Read and parse /boot/provision.json"""
    if not PROVISION_FILE.exists():
        print(f"Provision file not found: {PROVISION_FILE}")
        return None
    
    try:
        with open(PROVISION_FILE, "r") as f:
            data = json.load(f)
        return data
    except json.JSONDecodeError as e:
        print(f"Error parsing provision file: {e}")
        return None
    except Exception as e:
        print(f"Error reading provision file: {e}")
        return None


def register_device(enroll_token: str, site_id: str, camera_id: str) -> Optional[Dict]:
    """Register device with Firebase Function"""
    headers = {
        "Content-Type": "application/json",
        "x-enroll-token": enroll_token,
    }
    
    payload = {
        "siteId": site_id,
        "cameraId": camera_id,
    }
    
    try:
        print(f"Registering device with Firebase...")
        response = requests.post(
            FIREBASE_FUNCTION_URL,
            headers=headers,
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            error_data = response.json() if response.content else {}
            print(f"Registration failed: {response.status_code}")
            print(f"Error: {error_data.get('message', 'Unknown error')}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"Network error during registration: {e}")
        return None


def write_env_file(registration_data: Dict, provision_data: Dict) -> bool:
    """Write .env file with configuration"""
    try:
        # Ensure app directory exists
        APP_DIR.mkdir(parents=True, exist_ok=True)
        
        # Build environment variables
        env_content = f"""# Firebase Configuration
FIREBASE_API_KEY={registration_data['apiKey']}
FIREBASE_API_URL={FIREBASE_FUNCTION_URL.replace('/registerDevice', '')}

# Device Configuration
DEVICE_ID={registration_data['deviceId']}
TENANT_ID={registration_data['tenantId']}
SITE_ID={registration_data['siteId']}
CAMERA_ID={provision_data.get('cameraId', '')}

# Application Configuration
WINDOW_SECONDS={provision_data.get('windowSeconds', 60)}
HEALTH_CHECK_URL={provision_data.get('healthCheckUrl', '')}
VALIDATE_URL={provision_data.get('validateUrl', '')}
"""
        
        # Write .env file
        with open(ENV_FILE, "w") as f:
            f.write(env_content)
        
        # Set appropriate permissions (readable by app user, not world-readable)
        os.chmod(ENV_FILE, 0o640)
        
        print(f"Created .env file at {ENV_FILE}")
        return True
    except Exception as e:
        print(f"Error writing .env file: {e}")
        return False


def mark_provision_done() -> bool:
    """Create provision.done marker file"""
    try:
        PROVISION_DONE_FILE.touch()
        print(f"Created provision marker: {PROVISION_DONE_FILE}")
        return True
    except Exception as e:
        print(f"Error creating provision marker: {e}")
        return False


def cleanup_provision_file() -> bool:
    """Delete /boot/provision.json after successful registration"""
    try:
        if PROVISION_FILE.exists():
            PROVISION_FILE.unlink()
            print(f"Removed provision file: {PROVISION_FILE}")
        return True
    except Exception as e:
        print(f"Error removing provision file: {e}")
        return False


def main():
    """Main registration flow"""
    print("=" * 60)
    print("Raspberry Pi First Boot Registration")
    print("=" * 60)
    
    # Check if already provisioned
    if PROVISION_DONE_FILE.exists():
        print("Device already provisioned. Skipping registration.")
        sys.exit(0)
    
    # Read provision file
    provision_data = read_provision_file()
    if not provision_data:
        print("No provision data found. Exiting.")
        sys.exit(1)
    
    # Extract required fields
    enroll_token = provision_data.get("enrollToken")
    site_id = provision_data.get("siteId")
    camera_id = provision_data.get("cameraId")
    
    if not all([enroll_token, site_id, camera_id]):
        print("Missing required fields in provision.json: enrollToken, siteId, cameraId")
        sys.exit(1)
    
    # Register device
    registration_data = register_device(enroll_token, site_id, camera_id)
    if not registration_data or not registration_data.get("ok"):
        print("Device registration failed.")
        sys.exit(1)
    
    # Write .env file
    if not write_env_file(registration_data, provision_data):
        print("Failed to write .env file.")
        sys.exit(1)
    
    # Mark as provisioned
    if not mark_provision_done():
        print("Warning: Failed to create provision marker.")
    
    # Cleanup provision file
    cleanup_provision_file()
    
    print("=" * 60)
    print("Registration completed successfully!")
    print(f"Device ID: {registration_data['deviceId']}")
    print(f"Site ID: {registration_data['siteId']}")
    print("=" * 60)
    sys.exit(0)


if __name__ == "__main__":
    main()

