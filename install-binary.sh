#!/bin/bash

# Script to install pokerchaind binary on a remote node
# Usage: ./install-binary.sh <remote-host> [remote-user]

set -e

REMOTE_HOST="$1"
REMOTE_USER="${2:-$(whoami)}"
LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"
REMOTE_PATH="/usr/local/bin/pokerchaind"

if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 <remote-host> [remote-user]"
    echo "Example: $0 192.168.1.100 ubuntu"
    exit 1
fi

if [ ! -f "$LOCAL_BINARY" ]; then
    echo "Error: Binary not found at $LOCAL_BINARY"
    echo "Please build the binary first with: make install"
    exit 1
fi

echo "Copying pokerchaind binary to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

# Copy binary to remote host
scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"

# Install binary with proper permissions
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo mv /tmp/pokerchaind $REMOTE_PATH && sudo chmod +x $REMOTE_PATH"

echo "Binary installed successfully!"
echo "You can now run 'pokerchaind' on the remote host."

# Verify installation
echo "Verifying installation..."
ssh "$REMOTE_USER@$REMOTE_HOST" "pokerchaind version"