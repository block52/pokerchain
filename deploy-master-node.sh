#!/bin/bash

# Deploy master node to node1.block52.xyz with pre-built binary
# Usage: ./deploy-master-node.sh

set -e

REMOTE_HOST="node1.block52.xyz"
REMOTE_USER="root"

echo "🚀 Pokerchain Master Node Deployment"
echo "===================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo ""

# Step 1: Build binary
echo "� Step 1: Building binary..."
echo "-----------------------------"

# Create build directory in repo
BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
go clean -cache
rm -f "$BUILD_DIR/pokerchaind"

# Build the binary
echo "🔧 Building pokerchaind..."
if ! go build -o "$BUILD_DIR/pokerchaind" ./cmd/pokerchaind; then
    echo "❌ Build failed"
    exit 1
fi

LOCAL_BINARY="$BUILD_DIR/pokerchaind"
chmod +x "$LOCAL_BINARY"

BINARY_VERSION=$(${LOCAL_BINARY} version 2>/dev/null || echo "unknown")
BINARY_SIZE=$(ls -lh "$LOCAL_BINARY" | awk '{print $5}')
echo "✅ Build successful!"
echo "   Location: $LOCAL_BINARY"
echo "   Version: $BINARY_VERSION"
echo "   Size: $BINARY_SIZE"

# Step 2: Check configuration files
echo ""
echo "📋 Step 2: Checking configuration files..."
echo "------------------------------------------"

if [ ! -f "./genesis.json" ]; then
    echo "❌ Genesis file not found at ./genesis.json"
    exit 1
fi

if [ ! -f "./app.toml" ]; then
    echo "❌ app.toml not found"
    exit 1
fi

if [ ! -f "./config.toml" ]; then
    echo "❌ config.toml not found"
    exit 1
fi

if [ ! -f "./.testnets/validator0/config/priv_validator_key.json" ]; then
    echo "❌ Validator key not found at .testnets/validator0/config/priv_validator_key.json"
    exit 1
fi

if [ ! -f "./.testnets/validator0/data/priv_validator_state.json" ]; then
    echo "❌ Validator state not found at .testnets/validator0/data/priv_validator_state.json"
    exit 1
fi

LOCAL_GENESIS_HASH=$(sha256sum "./genesis.json" | cut -d' ' -f1)
echo "✅ All files present!"
echo "   Genesis hash: $LOCAL_GENESIS_HASH"

# Step 3: Stop remote services
echo ""
echo "⏹️  Step 3: Stopping services on remote node..."
echo "----------------------------------------------"

echo "Connecting to $REMOTE_USER@$REMOTE_HOST..."
ssh "$REMOTE_USER@$REMOTE_HOST" "
echo '🛑 Stopping pokerchaind service...'
sudo systemctl stop pokerchaind 2>/dev/null || true
sleep 2
echo '🔍 Checking for running processes...'
if pgrep pokerchaind; then
    echo '💥 Force killing pokerchaind processes...'
    sudo pkill -9 pokerchaind || true
    sleep 2
fi
echo '✅ Services stopped'
"

# Step 4: Backup and clean old data
echo ""
echo "🗑️  Step 4: Cleaning old data on remote node..."
echo "-----------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo '📦 Creating backup of old data...'
BACKUP_DIR=\"/root/pokerchain-backup-\$(date +%Y%m%d-%H%M%S)\"
if [ -d '/root/.pokerchain' ]; then
    mkdir -p \"\$BACKUP_DIR\"
    cp -r /root/.pokerchain/* \"\$BACKUP_DIR/\" 2>/dev/null || true
    echo \"✅ Backup created at \$BACKUP_DIR\"
else
    echo 'ℹ️  No existing data to backup'
fi

echo '🗑️  Removing old installation...'
sudo rm -f /usr/local/bin/pokerchaind
rm -rf /root/.pokerchain
echo '✅ Old data removed'
"

# Step 5: Copy binary to remote
echo ""
echo "📤 Step 5: Copying binary to remote node..."
echo "-------------------------------------------"

echo "Uploading pokerchaind binary ($BINARY_SIZE)..."
scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"
ssh "$REMOTE_USER@$REMOTE_HOST" "
sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind
sudo chmod +x /usr/local/bin/pokerchaind
sudo chown root:root /usr/local/bin/pokerchaind
echo '✅ Binary installed to /usr/local/bin/pokerchaind'

# Verify binary
REMOTE_VERSION=\$(pokerchaind version 2>/dev/null || echo 'unknown')
echo \"📌 Remote binary version: \$REMOTE_VERSION\"
"

# Step 6: Initialize node and copy configuration
echo ""
echo "⚙️  Step 6: Initializing node and copying config..."
echo "--------------------------------------------------"

echo "Uploading configuration files..."
scp "./genesis.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/genesis.json"
scp "./app.toml" "$REMOTE_USER@$REMOTE_HOST:/tmp/app.toml"
scp "./config.toml" "$REMOTE_USER@$REMOTE_HOST:/tmp/config.toml"
scp "./.testnets/validator0/config/priv_validator_key.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/priv_validator_key.json"
scp "./.testnets/validator0/data/priv_validator_state.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/priv_validator_state.json"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo '🔧 Initializing pokerchaind...'
pokerchaind init node1 --chain-id pokerchain --home /root/.pokerchain

echo '📋 Installing genesis file...'
rm -f /root/.pokerchain/config/genesis.json
cp /tmp/genesis.json /root/.pokerchain/config/genesis.json

echo '⚙️  Installing configuration files...'
cp /tmp/app.toml /root/.pokerchain/config/app.toml
cp /tmp/config.toml /root/.pokerchain/config/config.toml

echo '🔑 Installing validator keys...'
cp /tmp/priv_validator_key.json /root/.pokerchain/config/priv_validator_key.json
chmod 600 /root/.pokerchain/config/priv_validator_key.json

echo '💾 Installing validator state...'
mkdir -p /root/.pokerchain/data
cp /tmp/priv_validator_state.json /root/.pokerchain/data/priv_validator_state.json
chmod 600 /root/.pokerchain/data/priv_validator_state.json

echo '🔍 Verifying genesis hash...'
REMOTE_HASH=\$(sha256sum /root/.pokerchain/config/genesis.json | cut -d' ' -f1)
echo \"Remote genesis hash: \$REMOTE_HASH\"

echo '🧹 Cleaning temporary files...'
rm -f /tmp/genesis.json /tmp/app.toml /tmp/config.toml /tmp/priv_validator_key.json /tmp/priv_validator_state.json

echo '✅ Configuration installed!'
"

# Step 7: Verify configuration
echo ""
echo "🔍 Step 7: Verifying configuration..."
echo "------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo '📊 Configuration summary:'
echo '  Chain ID: pokerchain'
echo '  Node Moniker: node1'
echo '  Home: /root/.pokerchain'

echo ''
echo '🌐 API Configuration:'
grep -A 3 '\[api\]' /root/.pokerchain/config/app.toml | grep 'enable\|address\|swagger' || true

echo ''
echo '⚡ RPC Configuration:'
grep 'laddr = \"tcp://' /root/.pokerchain/config/config.toml | head -1 || true

echo ''
echo '🔑 Validator address:'
pokerchaind tendermint show-validator --home /root/.pokerchain
"

# Step 8: Start service
echo ""
echo "🚀 Step 8: Starting pokerchaind service..."
echo "-----------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo '▶️  Starting pokerchaind service...'
sudo systemctl start pokerchaind
sleep 3

echo '📊 Service status:'
sudo systemctl status pokerchaind --no-pager -l || true

echo ''
echo '🔍 Checking if node is running...'
sleep 5
if curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo '✅ Node is responding on RPC port 26657'
else
    echo '⚠️  RPC not responding yet (may take a moment to start)'
fi
"

# Step 9: Display info
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "🖥️  Master Node Information:"
echo "   Host: $REMOTE_HOST"
echo "   Chain ID: pokerchain"
echo "   Moniker: node1"
echo "   Validator: Alice (validator0)"
echo ""
echo "🌐 Network Endpoints:"
echo "   P2P:     $REMOTE_HOST:26656"
echo "   RPC:     http://$REMOTE_HOST:26657"
echo "   API:     http://$REMOTE_HOST:1317"
echo "   Swagger: http://$REMOTE_HOST:1317/swagger/"
echo ""
echo "📊 Monitor the service:"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'sudo systemctl status pokerchaind'"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'sudo journalctl -u pokerchaind -f'"
echo ""
echo "🔍 Query the node:"
echo "   curl http://$REMOTE_HOST:26657/status"
echo "   curl http://$REMOTE_HOST:1317/cosmos/base/tendermint/v1beta1/node_info"
echo ""
echo "🎮 Get node ID for peers:"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'pokerchaind tendermint show-node-id --home /root/.pokerchain'"
echo ""
