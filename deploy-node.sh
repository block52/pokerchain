#!/bin/bash

# Complete deployment script for pokerchain
# Usage: ./deploy-node.sh <remote-host> [remote-user]

set -e

REMOTE_HOST="$1"
REMOTE_USER="${2:-root}"

if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 <remote-host> [remote-user]"
    echo "Example: $0 node1.block52.xyz root"
    exit 1
fi

echo "🚀 Pokerchain Deployment"
echo "========================"
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo ""

# Step 1: Build binary locally
echo "🔨 Step 1: Building pokerchaind locally..."
echo "----------------------------------------"

# Clean and build
echo "Cleaning previous builds..."
go clean -cache
make clean 2>/dev/null || true

echo "Building pokerchaind..."
make install

LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"
if [ ! -f "$LOCAL_BINARY" ]; then
    echo "❌ Build failed. Binary not found at $LOCAL_BINARY"
    exit 1
fi

BINARY_VERSION=$(${LOCAL_BINARY} version 2>/dev/null || echo "unknown")
echo "✅ Build successful! Version: $BINARY_VERSION"

# Step 2: SSH to node and stop systemd service
echo ""
echo "� Step 2: Stopping services on remote node..."
echo "----------------------------------------------"

echo "Connecting to $REMOTE_USER@$REMOTE_HOST..."
ssh "$REMOTE_USER@$REMOTE_HOST" "
echo 'Stopping pokerchaind service...'
sudo systemctl stop pokerchaind 2>/dev/null || true
echo 'Checking if pokerchaind is still running...'
if pgrep pokerchaind; then
    echo 'Force killing pokerchaind processes...'
    sudo pkill -9 pokerchaind || true
    sleep 2
fi
echo '✅ Services stopped'
"

# Step 3: Remove old binary and genesis files
echo ""
echo "�️  Step 3: Removing old files on remote node..."
echo "------------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo 'Removing old binary...'
sudo rm -f /usr/local/bin/pokerchaind
echo 'Removing old pokerchaind data and config...'
rm -rf ~/.pokerchain /root/.pokerchain 2>/dev/null || true
echo '✅ Old files removed'
"

# Step 4: Copy binary to remote node
echo ""
echo "� Step 4: Copying binary to remote node..."
echo "-------------------------------------------"

echo "Copying pokerchaind binary..."
scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"
ssh "$REMOTE_USER@$REMOTE_HOST" "
sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind
sudo chmod +x /usr/local/bin/pokerchaind
sudo chown root:root /usr/local/bin/pokerchaind
echo '✅ Binary installed'
"

# Step 5: Copy genesis.json and config files from repo
echo ""
echo "� Step 5: Copying genesis and config files..."
echo "----------------------------------------------"

# Use genesis file from repo as source
if [ ! -f "./genesis.json" ]; then
    echo "❌ Genesis file not found in repo at ./genesis.json"
    exit 1
fi
echo "✅ Using genesis file from repo"

# Copy genesis file
echo "Copying genesis.json..."
LOCAL_HASH=$(sha256sum "./genesis.json" | cut -d' ' -f1)
echo "Local genesis hash: $LOCAL_HASH"
scp "./genesis.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/genesis.json"

# Copy validator files from repo testnet setup
echo "Copying validator files from repo..."
if [ -f "./.testnets/validator0/config/priv_validator_key.json" ] && [ -f "./.testnets/validator0/data/priv_validator_state.json" ]; then
    scp "./.testnets/validator0/config/priv_validator_key.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/priv_validator_key.json"
    scp "./.testnets/validator0/data/priv_validator_state.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/priv_validator_state.json"
    echo "✅ Validator files copied from repo"
else
    echo "⚠️  Warning: Validator files not found in .testnets/validator0/, node will generate new ones"
fi

# Initialize node and copy files to correct locations
ssh "$REMOTE_USER@$REMOTE_HOST" "
echo 'Initializing pokerchaind...'
pokerchaind init node1 --chain-id pokerchain --home /root/.pokerchain
echo 'Removing default genesis file...'
rm -f /root/.pokerchain/config/genesis.json
echo 'Copying genesis to correct location...'
cp /tmp/genesis.json /root/.pokerchain/config/genesis.json
echo 'Verifying genesis file hash...'
REMOTE_HASH=\$(sha256sum /root/.pokerchain/config/genesis.json | cut -d' ' -f1)
echo \"Remote genesis hash: \$REMOTE_HASH\"

# Copy validator files if they exist
if [ -f '/tmp/priv_validator_key.json' ] && [ -f '/tmp/priv_validator_state.json' ]; then
    echo 'Copying validator private key...'
    cp /tmp/priv_validator_key.json /root/.pokerchain/config/priv_validator_key.json
    chmod 600 /root/.pokerchain/config/priv_validator_key.json
    echo 'Creating data directory and copying validator state...'
    mkdir -p /root/.pokerchain/data
    cp /tmp/priv_validator_state.json /root/.pokerchain/data/priv_validator_state.json
    chmod 600 /root/.pokerchain/data/priv_validator_state.json
    echo '✅ Validator files installed from repo'
else
    echo '⚠️  Using generated validator files'
fi

echo 'Setting minimum gas prices...'
sed -i 's/minimum-gas-prices = \"\"/minimum-gas-prices = \"0stake\"/' /root/.pokerchain/config/app.toml
echo '✅ Genesis and config files installed'
"

# Step 6: Start service via systemd
echo ""
echo "🚀 Step 6: Starting service via systemd..."
echo "------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" "
echo 'Starting pokerchaind service...'
sudo systemctl start pokerchaind
sleep 3
echo 'Checking service status...'
sudo systemctl status pokerchaind --no-pager || true
echo '✅ Service started'
"

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "🖥️  Remote node ($REMOTE_HOST) should be running!"
echo ""
echo "📊 Monitor the service:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'sudo systemctl status pokerchaind'"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'sudo journalctl -u pokerchaind -f'"
echo ""
echo "🌐 Network endpoints:"
echo "- P2P: $REMOTE_HOST:26656"
echo "- RPC: $REMOTE_HOST:26657"
echo "- API: $REMOTE_HOST:1317"