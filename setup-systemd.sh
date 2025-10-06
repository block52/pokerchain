#!/bin/bash

# Systemd service setup script for pokerchaind
# Usage: ./setup-systemd.sh [remote-host] [remote-user]

set -e

REMOTE_HOST="${1:-node1.block52.xyz}"
REMOTE_USER="${2:-root}"

echo "🚀 Setting up Systemd Service for Pokerchaind"
echo "============================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo ""

# Step 1: Copy systemd service file
echo "📤 Step 1: Copying systemd service file..."
scp pokerchaind.service "$REMOTE_USER@$REMOTE_HOST:/tmp/"

# Step 2: Install and configure systemd service
echo "⚙️ Step 2: Installing systemd service..."
ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
# Stop any running pokerchaind process
echo "Stopping any running pokerchaind processes..."
pkill -f pokerchaind || true
sleep 2

# Install systemd service
echo "Installing systemd service..."
mv /tmp/pokerchaind.service /etc/systemd/system/
chown root:root /etc/systemd/system/pokerchaind.service
chmod 644 /etc/systemd/system/pokerchaind.service

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Enable service (start on boot)
echo "Enabling pokerchaind service..."
systemctl enable pokerchaind

echo "Systemd service installed successfully!"
EOF

echo ""
echo "🎉 Systemd Service Setup Complete!"
echo "=================================="
echo ""
echo "🚀 To start the service:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'systemctl start pokerchaind'"
echo ""
echo "📋 To check status:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'systemctl status pokerchaind'"
echo ""
echo "📝 To view logs:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'journalctl -u pokerchaind -f'"
echo ""
echo "🛑 To stop the service:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'systemctl stop pokerchaind'"
echo ""
echo "🔄 Service will automatically start on system boot"