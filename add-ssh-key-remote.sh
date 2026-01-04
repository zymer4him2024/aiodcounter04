#!/bin/bash
# Commands to run on the remote host (192.168.0.214) to add SSH key

echo "Run these commands on the remote host (ShawnRaspberryPi):"
echo ""
echo "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
echo "echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUKZzjGnNpIS7OAFnS7W5SM4gAuCE7riyuCwnVqZEEL digioptics_od@192.168.0.213' >> ~/.ssh/authorized_keys"
echo "chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "Or copy-paste this one-liner:"
echo "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUKZzjGnNpIS7OAFnS7W5SM4gAuCE7riyuCwnVqZEEL digioptics_od@192.168.0.213' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

