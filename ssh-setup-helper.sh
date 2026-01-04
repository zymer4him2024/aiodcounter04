#!/bin/bash
# SSH Setup Helper Script for digioptics_od@192.168.0.213

HOST="192.168.0.213"
USER="digioptics_od"
KEY_FILE="$HOME/.ssh/id_ed25519.pub"

echo "=== SSH Setup Helper ==="
echo ""

# Check if host is reachable
echo "1. Checking host connectivity..."
if ping -c 2 -W 2 "$HOST" > /dev/null 2>&1; then
    echo "   ✅ Host is reachable"
    HOST_REACHABLE=true
else
    echo "   ❌ Host is not reachable (this is expected if device is off/not on network)"
    HOST_REACHABLE=false
fi

echo ""
echo "2. Your SSH public key:"
echo "   (Copy this to the remote host's ~/.ssh/authorized_keys)"
cat "$KEY_FILE"
echo ""

if [ "$HOST_REACHABLE" = true ]; then
    echo "3. Attempting to copy SSH key to remote host..."
    echo "   (You may be prompted for password)"
    ssh-copy-id -i "$KEY_FILE" "$USER@$HOST" 2>&1
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SSH key copied successfully!"
        echo "   You can now connect without password:"
        echo "   ssh $USER@$HOST"
    else
        echo ""
        echo "⚠️  Automatic copy failed. Manual steps:"
        echo "   1. SSH to the host: ssh $USER@$HOST"
        echo "   2. Run: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        echo "   3. Add this key to ~/.ssh/authorized_keys:"
        echo "      cat >> ~/.ssh/authorized_keys << 'EOF'"
        cat "$KEY_FILE"
        echo "      EOF"
        echo "   4. Set permissions: chmod 600 ~/.ssh/authorized_keys"
    fi
else
    echo "3. Manual setup (host not reachable):"
    echo "   Once the host is online, run:"
    echo "   ssh-copy-id -i $KEY_FILE $USER@$HOST"
    echo ""
    echo "   Or manually add the key above to:"
    echo "   $USER@$HOST:~/.ssh/authorized_keys"
fi

echo ""
echo "4. Testing SSH connection..."
if [ "$HOST_REACHABLE" = true ]; then
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$USER@$HOST" "echo 'SSH connection successful!'" 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ SSH key authentication working!"
    else
        echo "   ⚠️  SSH key not yet configured on remote host"
    fi
else
    echo "   ⏭️  Skipped (host not reachable)"
fi

echo ""
echo "=== Done ==="

