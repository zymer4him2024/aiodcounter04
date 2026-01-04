#!/bin/bash
# Development Environment Setup Script
# Installs Python dependencies for local development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

echo "=========================================="
echo "Camera System - Development Environment Setup"
echo "=========================================="
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found. Please install Python 3."
    exit 1
fi

# Check if pip3 is available
if ! command -v pip3 &> /dev/null; then
    echo "❌ Error: pip3 not found. Please install pip."
    exit 1
fi

echo "Python version: $(python3 --version)"
echo "pip version: $(pip3 --version)"
echo ""

# Check if requirements.txt exists
if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    echo "❌ Error: requirements.txt not found at $REQUIREMENTS_FILE"
    exit 1
fi

echo "Installing dependencies from $REQUIREMENTS_FILE..."
echo ""

# Install dependencies
pip3 install -r "$REQUIREMENTS_FILE"

echo ""
echo "=========================================="
echo "Verifying installation..."
echo "=========================================="

# Verify critical packages
python3 << EOF
import sys
errors = []

try:
    import firebase_admin
    print("✅ firebase_admin")
except ImportError as e:
    errors.append(f"❌ firebase_admin: {e}")

try:
    import cv2
    print("✅ opencv-python (cv2)")
except ImportError as e:
    errors.append(f"❌ opencv-python: {e}")

try:
    import numpy
    print("✅ numpy")
except ImportError as e:
    errors.append(f"❌ numpy: {e}")

try:
    import psutil
    print("✅ psutil")
except ImportError as e:
    errors.append(f"❌ psutil: {e}")

try:
    import sqlalchemy
    print("✅ sqlalchemy")
except ImportError as e:
    errors.append(f"❌ sqlalchemy: {e}")

if errors:
    print("\nErrors found:")
    for error in errors:
        print(f"  {error}")
    sys.exit(1)
else:
    print("\n✅ All critical dependencies installed successfully!")
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Development environment setup complete!"
    echo "=========================================="
    echo ""
    echo "You can now run the camera system scripts without import errors."
else
    echo ""
    echo "❌ Some dependencies failed to install. Please check the errors above."
    exit 1
fi


