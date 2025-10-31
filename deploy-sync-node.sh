#!/bin/bash

# Deploy sync node to a remote Linux server
#
# Features:
# - Always cross-compiles for Linux amd64 (for professionally hosted nodes)
# - Compatible with macOS and Linux build machines
# - Connects to node1.block52.xyz as persistent peer
# - Sets up systemd service for automatic startup
# - Configures firewall (UFW)
#
# Usage: ./deploy-sync-node.sh <REMOTE_HOST> [REMOTE_USER]
# Example: ./deploy-sync-node.sh node2.example.com root
#          ./deploy-sync-node.sh node.texashodl.net root

set -e

# Configuration
REMOTE_HOST="${1:-}"
REMOTE_USER="${2:-root}"
SEED_NODE_HOST="node1.block52.xyz"
SEED_NODE_ID="08890a89197b2afd56b115e9b749cef7d4578c5c"
SEED_NODE_PORT="26656"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if remote host is provided
if [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}❌ Error: Remote host not provided${NC}"
    echo ""
    echo "Usage: $0 <REMOTE_HOST> [REMOTE_USER]"
    echo ""
    echo "Example:"
    echo "  $0 node2.example.com root"
    echo "  $0 192.168.1.100 ubuntu"
    echo ""
    exit 1
fi

echo -e "${BLUE}🚀 Pokerchain Sync Node Deployment${NC}"
echo "===================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo "Seed Node: $SEED_NODE_ID@$SEED_NODE_HOST:$SEED_NODE_PORT"
echo ""

# Step 1: Build binary for Linux amd64
echo -e "${BLUE}🔧 Step 1: Building binary for Linux amd64...${NC}"
echo "----------------------------------------------"
BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

# Check if binary already exists
if [ -f "$BUILD_DIR/pokerchaind" ]; then
    EXISTING_VERSION=$("$BUILD_DIR/pokerchaind" version 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}⚠️  Found existing build at $BUILD_DIR/pokerchaind${NC}"
    echo "   Version: $EXISTING_VERSION"
    echo ""
    read -p "Do you want to rebuild it? (y/n): " REBUILD_CHOICE
    if [[ "$REBUILD_CHOICE" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}🔧 Rebuilding pokerchaind for Linux amd64...${NC}"
        echo "   Cross-compiling from $(uname -s)/$(uname -m)"
        go clean -cache
        rm -f "$BUILD_DIR/pokerchaind"
        if ! GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/pokerchaind" ./cmd/pokerchaind; then
            echo -e "${RED}❌ Build failed${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Build complete!${NC}"
    else
        echo -e "${GREEN}✅ Using existing build.${NC}"
    fi
else
    echo -e "${BLUE}🔧 Building pokerchaind for Linux amd64...${NC}"
    echo "   Cross-compiling from $(uname -s)/$(uname -m)"
    go clean -cache
    rm -f "$BUILD_DIR/pokerchaind"
    if ! GOOS=linux GOARCH=amd64 go build -o "$BUILD_DIR/pokerchaind" ./cmd/pokerchaind; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Build complete!${NC}"
fi

echo ""

LOCAL_BINARY="$BUILD_DIR/pokerchaind"
chmod +x "$LOCAL_BINARY"
BINARY_VERSION=$(${LOCAL_BINARY} version 2>/dev/null || echo "unknown")
BINARY_SIZE=$(ls -lh "$LOCAL_BINARY" | awk '{print $5}')
echo -e "${GREEN}✅ Build successful!${NC}"
echo "   Location: $LOCAL_BINARY"
echo "   Version: $BINARY_VERSION"
echo "   Size: $BINARY_SIZE"

# Step 2: Check configuration files
echo ""
echo -e "${BLUE}📋 Step 2: Checking configuration files...${NC}"
echo "------------------------------------------"

if [ ! -f "./genesis.json" ]; then
    echo -e "${RED}❌ Genesis file not found at ./genesis.json${NC}"
    exit 1
fi

if [ ! -f "./app.toml" ]; then
    echo -e "${RED}❌ app.toml not found${NC}"
    exit 1
fi

if [ ! -f "./config.toml" ]; then
    echo -e "${RED}❌ config.toml not found${NC}"
    exit 1
fi

if [ ! -f "./pokerchaind.service" ]; then
    echo -e "${RED}❌ pokerchaind.service not found${NC}"
    exit 1
fi

# Detect OS and use appropriate sha256 command
if [[ "$OSTYPE" == "darwin"* ]]; then
    LOCAL_GENESIS_HASH=$(shasum -a 256 "./genesis.json" | cut -d' ' -f1)
else
    LOCAL_GENESIS_HASH=$(sha256sum "./genesis.json" | cut -d' ' -f1)
fi
echo -e "${GREEN}✅ All files present!${NC}"
echo "   Genesis hash: $LOCAL_GENESIS_HASH"

# Step 3: Test connectivity to remote host
echo ""
echo -e "${BLUE}🌐 Step 3: Testing connectivity...${NC}"
echo "----------------------------------"

if ! ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to $REMOTE_USER@$REMOTE_HOST${NC}"
    echo "Please check:"
    echo "  - SSH access is configured"
    echo "  - Remote host is reachable"
    echo "  - User has proper permissions"
    exit 1
fi
echo -e "${GREEN}✅ Connection successful${NC}"

# Step 4: Stop remote services
echo ""
echo -e "${BLUE}⏹️  Step 4: Stopping services on remote node...${NC}"
echo "----------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
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
ENDSSH

# Step 5: Backup and clean old data
echo ""
echo -e "${BLUE}🗑️  Step 5: Cleaning old data on remote node...${NC}"
echo "-----------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
echo '📦 Creating backup of old data...'
BACKUP_DIR="/root/pokerchain-backup-$(date +%Y%m%d-%H%M%S)"
if [ -d '/root/.pokerchain' ]; then
    mkdir -p "$BACKUP_DIR"
    cp -r /root/.pokerchain/* "$BACKUP_DIR/" 2>/dev/null || true
    echo "✅ Backup created at $BACKUP_DIR"
else
    echo 'ℹ️  No existing data to backup'
fi

echo '🗑️  Removing old installation...'
sudo rm -f /usr/local/bin/pokerchaind
rm -rf /root/.pokerchain
echo '✅ Old data removed'
ENDSSH

# Step 6: Copy binary to remote
echo ""
echo -e "${BLUE}📤 Step 6: Copying binary to remote node...${NC}"
echo "-------------------------------------------"

scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"
ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind
sudo chmod +x /usr/local/bin/pokerchaind
sudo chown root:root /usr/local/bin/pokerchaind
echo '✅ Binary installed to /usr/local/bin/pokerchaind'

# Verify binary
REMOTE_VERSION=$(pokerchaind version 2>/dev/null || echo 'unknown')
echo "📌 Remote binary version: $REMOTE_VERSION"
ENDSSH

# Step 7: Initialize node and copy configuration
echo ""
echo -e "${BLUE}⚙️  Step 7: Initializing node and copying config...${NC}"
echo "--------------------------------------------------"

# Create temporary config files with updated persistent_peers
echo "📝 Preparing configuration files..."
TEMP_CONFIG=$(mktemp)
TEMP_APP=$(mktemp)

# Copy config.toml and update persistent_peers
cp "./config.toml" "$TEMP_CONFIG"

# macOS and Linux compatible sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^persistent_peers = .*|persistent_peers = \"${SEED_NODE_ID}@${SEED_NODE_HOST}:${SEED_NODE_PORT}\"|" "$TEMP_CONFIG"
else
    sed -i "s|^persistent_peers = .*|persistent_peers = \"${SEED_NODE_ID}@${SEED_NODE_HOST}:${SEED_NODE_PORT}\"|" "$TEMP_CONFIG"
fi

# Copy app.toml (no changes needed)
cp "./app.toml" "$TEMP_APP"

echo "📤 Uploading configuration files..."
scp "./genesis.json" "$REMOTE_USER@$REMOTE_HOST:/tmp/genesis.json"
scp "$TEMP_APP" "$REMOTE_USER@$REMOTE_HOST:/tmp/app.toml"
scp "$TEMP_CONFIG" "$REMOTE_USER@$REMOTE_HOST:/tmp/config.toml"

# Clean up temp files
rm -f "$TEMP_CONFIG" "$TEMP_APP"

# Get a unique moniker for this node
MONIKER="${REMOTE_HOST%%.*}-sync"

ssh "$REMOTE_USER@$REMOTE_HOST" << ENDSSH
echo '🔧 Initializing pokerchaind...'
pokerchaind init "$MONIKER" --chain-id pokerchain --home /root/.pokerchain

echo '📋 Installing genesis file...'
rm -f /root/.pokerchain/config/genesis.json
cp /tmp/genesis.json /root/.pokerchain/config/genesis.json

echo '⚙️  Installing configuration files...'
cp /tmp/app.toml /root/.pokerchain/config/app.toml
cp /tmp/config.toml /root/.pokerchain/config/config.toml

echo '🔍 Verifying genesis hash...'
REMOTE_HASH=\$(sha256sum /root/.pokerchain/config/genesis.json | cut -d' ' -f1)
echo "Remote genesis hash: \$REMOTE_HASH"

echo '🧹 Cleaning temporary files...'
rm -f /tmp/genesis.json /tmp/app.toml /tmp/config.toml

echo '✅ Configuration installed!'
ENDSSH

# Step 8: Configure firewall
echo ""
echo -e "${BLUE}🔥 Step 8: Configuring firewall (UFW)...${NC}"
echo "---------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
echo '🔍 Checking if UFW is installed...'
if command -v ufw &> /dev/null; then
    echo '✅ UFW is installed'
    
    echo '🔧 Configuring UFW rules...'
    
    # Allow SSH (important - don't lock yourself out!)
    sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
    
    # Allow Pokerchain ports
    sudo ufw allow 26656/tcp comment 'Pokerchain P2P' 2>/dev/null || true
    sudo ufw allow 26657/tcp comment 'Pokerchain RPC' 2>/dev/null || true
    sudo ufw allow 1317/tcp comment 'Pokerchain API' 2>/dev/null || true
    
    # Enable UFW if not already enabled
    echo '🚀 Enabling UFW...'
    sudo ufw --force enable 2>/dev/null || true
    
    echo ''
    echo '📋 Current UFW status:'
    sudo ufw status numbered
    
    echo '✅ Firewall configured!'
else
    echo '⚠️  UFW not installed, skipping firewall configuration'
    echo 'Install with: sudo apt-get install ufw'
fi
ENDSSH

# Step 9: Setup systemd service
echo ""
echo -e "${BLUE}🔧 Step 9: Setting up systemd service...${NC}"
echo "----------------------------------------"

scp "./pokerchaind.service" "$REMOTE_USER@$REMOTE_HOST:/tmp/"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
echo '📝 Installing systemd service...'
sudo mv /tmp/pokerchaind.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/pokerchaind.service
sudo chmod 644 /etc/systemd/system/pokerchaind.service

echo '🔄 Reloading systemd...'
sudo systemctl daemon-reload

echo '🚀 Enabling pokerchaind service...'
sudo systemctl enable pokerchaind

echo '✅ Systemd service configured!'
ENDSSH

# Step 10: Verify configuration
echo ""
echo -e "${BLUE}🔍 Step 10: Verifying configuration...${NC}"
echo "-------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
echo '📊 Configuration summary:'
echo "  Chain ID: pokerchain"
echo "  Node Moniker: $(grep '^moniker = ' /root/.pokerchain/config/config.toml | cut -d'"' -f2)"
echo '  Home: /root/.pokerchain'

echo ''
echo '🌐 API Configuration:'
grep -A 3 '\[api\]' /root/.pokerchain/config/app.toml | grep 'enable\|address\|swagger' || true

echo ''
echo '⚡ RPC Configuration:'
grep 'laddr = ' /root/.pokerchain/config/config.toml | head -1 || true

echo ''
echo '👥 Persistent Peers:'
grep '^persistent_peers = ' /root/.pokerchain/config/config.toml || true

echo ''
echo '🆔 Node ID:'
pokerchaind tendermint show-node-id --home /root/.pokerchain
ENDSSH

# Step 11: Start service
echo ""
echo -e "${BLUE}🚀 Step 11: Starting pokerchaind service...${NC}"
echo "------------------------------------------"

ssh "$REMOTE_USER@$REMOTE_HOST" << 'ENDSSH'
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
    echo ''
    echo '📊 Initial sync status:'
    curl -s http://localhost:26657/status | jq '.result.sync_info' || true
else
    echo '⚠️  RPC not responding yet (may take a moment to start)'
fi
ENDSSH

# Step 12: Display info
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "======================"
echo ""
echo "🖥️  Sync Node Information:"
echo "   Host: $REMOTE_HOST"
echo "   Chain ID: pokerchain"
echo "   Moniker: $MONIKER"
echo "   Mode: Read-Only Sync Node"
echo ""
echo "🌐 Network Endpoints:"
echo "   P2P:     $REMOTE_HOST:26656"
echo "   RPC:     http://$REMOTE_HOST:26657"
echo "   API:     http://$REMOTE_HOST:1317"
echo ""
echo "🔗 Connected to Seed Node:"
echo "   $SEED_NODE_ID@$SEED_NODE_HOST:$SEED_NODE_PORT"
echo ""
echo "📊 Monitor the service:"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'sudo systemctl status pokerchaind'"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'sudo journalctl -u pokerchaind -f'"
echo ""
echo "🔍 Check sync status:"
echo "   ssh $REMOTE_USER@$REMOTE_HOST 'curl -s http://localhost:26657/status | jq .result.sync_info'"
echo ""
echo "⚠️  Note: The node will sync blocks from the network. This may take time."
echo ""
