# IDE/Linter Setup Guide

## Resolving Import Warnings

If you see import warnings like `Import "firebase_admin" could not be resolved` in your IDE, this is typically because the IDE is using a different Python interpreter than where packages are installed.

## Solution

### Option 1: Configure IDE Python Interpreter (Recommended)

Configure your IDE (VS Code, PyCharm, etc.) to use the Python interpreter where packages are installed:

**VS Code:**
1. Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Python: Select Interpreter"
3. Choose the Python interpreter (usually `/usr/local/bin/python3` or `/usr/bin/python3`)
4. Or select the one showing your user site-packages

**Find your Python interpreter:**
```bash
which python3
python3 -c "import sys; print(sys.executable)"
```

### Option 2: Use Virtual Environment (Best Practice)

Create a virtual environment for the project:

```bash
cd camera-system
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# or: venv\Scripts\activate  # On Windows
pip install -r requirements.txt
```

Then configure your IDE to use `venv/bin/python` as the interpreter.

### Option 3: Install Packages Globally (Current Setup)

Packages are installed in your user site-packages. Verify installation:

```bash
python3 -c "import firebase_admin; import psutil; print('✅ All packages installed')"
```

If this works, configure your IDE to use the same `python3` interpreter.

## Verify Installation

Run this to verify all dependencies are installed:

```bash
python3 -c "import firebase_admin, psutil, cv2, numpy, sqlalchemy; print('✅ All dependencies available')"
```

## Note

The linter warnings are IDE-specific and don't affect runtime execution. If the Python import test above succeeds, your code will run correctly.

