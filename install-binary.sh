#!/bin/bash

# Script to install pokerchaind binary and genesis on a remote node
# Usage: ./install-binary.sh <remote-host> [remote-user] [--with-genesis]

set -e

REMOTE_HOST="$1"
REMOTE_USER="${2:-$(whoami)}"
WITH_GENESIS="$3"
BUILD_DIR="./build"
LOCAL_BINARY="$BUILD_DIR/pokerchaind"
GENESIS_FILE="./genesis-minimal-b52Token.json"
REMOTE_PATH="/usr/local/bin/pokerchaind"
REMOTE_HOME="/home/$REMOTE_USER"

if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 <remote-host> [remote-user] [--with-genesis]"
    echo "Example: $0 node1.block52.xyz ubuntu --with-genesis"
    exit 1
fi

echo "🚀 Installing pokerchaind on $REMOTE_USER@$REMOTE_HOST"
echo "=================================="

# Build binary if it doesn't exist
if [ ! -f "$LOCAL_BINARY" ]; then
    echo "❌ Binary not found at $LOCAL_BINARY"
    echo "Building pokerchaind..."
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Build to build directory
    go clean -cache
    if ! go build -o "$LOCAL_BINARY" ./cmd/pokerchaind; then
        echo "❌ Build failed. Please check the build process."
        exit 1
    fi
    
    chmod +x "$LOCAL_BINARY"
    echo "✅ pokerchaind built successfully"
else
    echo "✅ Using existing binary at $LOCAL_BINARY"
fi

# Get binary version
BINARY_VERSION=$(${LOCAL_BINARY} version 2>/dev/null || echo "unknown")
echo "📦 Binary version: $BINARY_VERSION"

echo ""
echo "📤 Copying binary to remote host..."

# Copy binary to remote host
scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"

# Install binary with proper permissions
echo "🔧 Installing binary with proper permissions..."
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo mv /tmp/pokerchaind $REMOTE_PATH && sudo chmod +x $REMOTE_PATH"

echo "✅ Binary installed successfully!"

# Copy genesis file if requested
if [[ "$WITH_GENESIS" == "--with-genesis" ]]; then
    echo ""
    echo "📋 Copying genesis.json..."
    
    if [ ! -f "$GENESIS_FILE" ]; then
        echo "❌ Genesis file not found at $GENESIS_FILE"
        exit 1
    fi
    
    # Remove any old genesis files in the remote home directory
    ssh "$REMOTE_USER@$REMOTE_HOST" 'rm -f ~/genesis.json ~/.pokerchain/config/genesis.json'
    # Copy genesis file to remote home directory
    scp "$GENESIS_FILE" "$REMOTE_USER@$REMOTE_HOST:~/genesis.json"
    echo "✅ Genesis file copied to $REMOTE_HOME/genesis.json"
fi

# Copy setup scripts
echo ""
echo "📜 Copying setup scripts..."
scp second-node.sh "$REMOTE_USER@$REMOTE_HOST:~/second-node.sh"
scp get-node-info.sh "$REMOTE_USER@$REMOTE_HOST:~/get-node-info.sh"
ssh "$REMOTE_USER@$REMOTE_HOST" "chmod +x *.sh"
echo "✅ Setup scripts copied and made executable"

echo ""
echo "🔍 Verifying installation..."
ssh "$REMOTE_USER@$REMOTE_HOST" "pokerchaind version"

echo ""
echo "🎉 Installation Complete!"
echo "========================"
echo ""
echo "What was installed:"
echo "✅ pokerchaind binary at $REMOTE_PATH"
if [[ "$WITH_GENESIS" == "--with-genesis" ]]; then
    echo "✅ genesis.json at $REMOTE_HOME/genesis.json"
fi
echo "✅ Setup scripts in $REMOTE_HOME/"
echo ""
echo "Next steps on $REMOTE_HOST:"
echo "1. Initialize node: ./second-node.sh <moniker-name>"
echo "2. Start the node: pokerchaind start"
echo "3. Get node info: ./get-node-info.sh"
echo ""
echo "🌐 Remember to configure firewall for ports:"
echo "   - P2P: 26656"
echo "   - RPC: 26657"
echo "   - API: 1317"