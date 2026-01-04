#!/bin/bash
# Setup SSH key for backend to RPi connection

RPI_HOST="${RPI_HOST:-192.168.0.214}"
RPI_USER="${RPI_USER:-digioptics_od}"
SSH_DIR="./.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Setting up SSH key for backend -> RPi connection            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate SSH key if it doesn't exist
if [ ! -f "$KEY_FILE" ]; then
    echo "[1/3] Generating SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "backend@$(hostname)"
    echo "✅ SSH key generated: $KEY_FILE"
else
    echo "[1/3] SSH key already exists: $KEY_FILE"
fi

# Display public key
echo ""
echo "[2/3] Your public key:"
echo "─────────────────────────────────────────────────────────────"
cat "${KEY_FILE}.pub"
echo "─────────────────────────────────────────────────────────────"
echo ""

# Copy key to RPi
echo "[3/3] Copying key to RPi..."
echo "   Target: ${RPI_USER}@${RPI_HOST}"
echo "   You may be prompted for the RPi password..."
echo ""

ssh-copy-id -i "${KEY_FILE}.pub" "${RPI_USER}@${RPI_HOST}" 2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ✅ SSH key setup complete!                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Backend can now SSH to RPi without password"
    echo ""
    echo "Test connection:"
    echo "   ssh -i $KEY_FILE ${RPI_USER}@${RPI_HOST} 'echo \"Connection successful!\"'"
    echo ""
else
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              ⚠️  Automatic copy failed                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Manual setup steps:"
    echo "   1. Copy the public key shown above"
    echo "   2. SSH to RPi: ssh ${RPI_USER}@${RPI_HOST}"
    echo "   3. Run: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo "   4. Add key: echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
    echo "   5. Set permissions: chmod 600 ~/.ssh/authorized_keys"
    echo ""
fi

