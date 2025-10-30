#!/bin/bash

# Local Sync Node Setup Script
# Sets up a local read-only sync node using the same approach as remote deployment
# Usage: ./setup-local-sync-node.sh

set -e

# Configuration
CHAIN_ID="pokerchain"
HOME_DIR="$HOME/.pokerchain"
SEED_NODE_HOST="node1.block52.xyz"
SEED_NODE_ID="a429c82669d8932602ca43139733f98c42817464"
SEED_NODE_PORT="26656"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Pokerchain Local Sync Node Setup${NC}"
echo "===================================="
echo "Home Directory: $HOME_DIR"
echo "Seed Node: $SEED_NODE_ID@$SEED_NODE_HOST:$SEED_NODE_PORT"
echo ""

# Remove existing local data before setup
rm -rf "$HOME_DIR/data" "$HOME_DIR/config"

# Step 1: Build binary
echo -e "${BLUE}📦 Step 1: Building binary...${NC}"
echo "-----------------------------"

echo "🔧 Building pokerchaind with make..."
if ! make install; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Verify installation and add to PATH if needed
export PATH="$HOME/go/bin:$PATH"

if ! command -v pokerchaind &> /dev/null; then
    echo -e "${RED}❌ pokerchaind not found even after adding to PATH${NC}"
    echo "Check if binary exists: ls -la $HOME/go/bin/pokerchaind"
    exit 1
fi

BINARY_VERSION=$(pokerchaind version 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ Build successful!${NC}"
echo "   Version: $BINARY_VERSION"
echo "   Location: $(which pokerchaind)"

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

LOCAL_GENESIS_HASH=$(sha256sum "./genesis.json" | cut -d' ' -f1)
echo -e "${GREEN}✅ All files present!${NC}"
echo "   Genesis hash: $LOCAL_GENESIS_HASH"

# Step 3: Stop any running processes
echo ""
echo -e "${BLUE}⏹️  Step 3: Stopping any running pokerchaind...${NC}"
echo "----------------------------------------------"

if pgrep -x pokerchaind > /dev/null; then
    echo "🛑 Stopping pokerchaind processes..."
    pkill pokerchaind || true
    sleep 2
    echo "✅ Processes stopped"
else
    echo "✅ No running processes found"
fi

# Step 4: Backup and clean old data
echo ""
echo -e "${BLUE}🗑️  Step 4: Backing up old data...${NC}"
echo "----------------------------------"

if [ -d "$HOME_DIR" ]; then
    BACKUP_DIR="$HOME/pokerchain-backup-$(date +%Y%m%d-%H%M%S)"
    echo "📦 Creating backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$HOME_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✅ Backup created${NC}"
    
    echo "🗑️  Removing old data..."
    rm -rf "$HOME_DIR"
    echo "✅ Old data removed"
else
    echo "ℹ️  No existing data to backup"
fi

# Step 5: Initialize node
echo ""
echo -e "${BLUE}⚙️  Step 5: Initializing node...${NC}"
echo "--------------------------------"

echo "🔧 Initializing pokerchaind..."
pokerchaind init local-sync --chain-id $CHAIN_ID --home "$HOME_DIR"

echo -e "${GREEN}✅ Node initialized${NC}"

# Step 6: Install configuration files
echo ""
echo -e "${BLUE}📝 Step 6: Installing configuration files...${NC}"
echo "-------------------------------------------"

# Create temporary config with updated persistent_peers
TEMP_CONFIG=$(mktemp)
cp "./config.toml" "$TEMP_CONFIG"
sed -i "s|^persistent_peers = .*|persistent_peers = \"${SEED_NODE_ID}@${SEED_NODE_HOST}:${SEED_NODE_PORT}\"|" "$TEMP_CONFIG"

echo "📋 Installing genesis file..."
cp "./genesis.json" "$HOME_DIR/config/genesis.json"

echo "⚙️  Installing app.toml..."
cp "./app.toml" "$HOME_DIR/config/app.toml"

echo "⚙️  Installing config.toml (with persistent peers)..."
cp "$TEMP_CONFIG" "$HOME_DIR/config/config.toml"

# Clean up temp file
rm -f "$TEMP_CONFIG"

echo "🔍 Verifying genesis hash..."
INSTALLED_HASH=$(sha256sum "$HOME_DIR/config/genesis.json" | cut -d' ' -f1)
echo "   Installed genesis hash: $INSTALLED_HASH"

if [ "$LOCAL_GENESIS_HASH" = "$INSTALLED_HASH" ]; then
    echo -e "${GREEN}✅ Genesis hash matches!${NC}"
else
    echo -e "${RED}❌ Genesis hash mismatch!${NC}"
    exit 1
fi

# Step 7: Verify configuration
echo ""
echo -e "${BLUE}🔍 Step 7: Verifying configuration...${NC}"
echo "------------------------------------"

echo "📊 Configuration summary:"
echo "  Chain ID: $CHAIN_ID"
echo "  Node Moniker: LocalSyncNode"
echo "  Home: $HOME_DIR"
echo ""
echo "🌐 API Configuration:"
grep -A 3 '\[api\]' $HOME_DIR/config/app.toml | grep 'enable\|address\|swagger' || true
echo ""
echo "⚡ RPC Configuration:"
grep 'laddr = ' $HOME_DIR/config/config.toml | head -1 || true
echo ""
echo "👥 Persistent Peers:"
grep '^persistent_peers = ' $HOME_DIR/config/config.toml || true
echo ""
echo "🆔 Node ID:"
pokerchaind tendermint show-node-id --home "$HOME_DIR"

# Step 8: Start node
echo ""
echo -e "${BLUE}🚀 Step 8: Starting node...${NC}"
echo "-------------------------"

echo ""
echo "You can start the node in two ways:"
echo ""
echo "1️⃣  Run in foreground (for testing):"
echo "   pokerchaind start --home $HOME_DIR"
echo ""
echo "2️⃣  Run in background:"
echo "   nohup pokerchaind start --home $HOME_DIR > $HOME_DIR/pokerchaind.log 2>&1 &"
echo ""
echo "📊 Monitor sync status:"
echo "   curl -s http://localhost:26657/status | jq .result.sync_info"
echo ""
echo "📝 View logs (if running in background):"
echo "   tail -f $HOME_DIR/pokerchaind.log"
echo ""

read -p "Would you like to start the node now in the background? (y/n): " start_now

if [[ "$start_now" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting pokerchaind in background..."
    nohup pokerchaind start --home "$HOME_DIR" > "$HOME_DIR/pokerchaind.log" 2>&1 &
    NODE_PID=$!
    echo "✅ Node started with PID: $NODE_PID"
    
    echo ""
    echo "⏳ Waiting for node to start (5 seconds)..."
    sleep 5
    
    echo ""
    echo "🔍 Checking node status..."
    if curl -s http://localhost:26657/status > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Node is responding on RPC port 26657${NC}"
        echo ""
        echo "📊 Initial sync status:"
        curl -s http://localhost:26657/status | jq '.result.sync_info' || echo "Install jq for formatted output: sudo apt-get install jq"
    else
        echo -e "${YELLOW}⚠️  RPC not responding yet (may take a moment)${NC}"
        echo "Check logs: tail -f $HOME_DIR/pokerchaind.log"
    fi
fi

# Final summary
echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo "=================="
echo ""
echo "🖥️  Local Sync Node Information:"
echo "   Chain ID: $CHAIN_ID"
echo "   Home: $HOME_DIR"
echo "   Mode: Read-Only Sync Node"
echo ""
echo "🌐 Local Endpoints:"
echo "   RPC: http://localhost:26657"
echo "   API: http://localhost:1317"
echo ""
echo "🔗 Connected to:"
echo "   $SEED_NODE_ID@$SEED_NODE_HOST:$SEED_NODE_PORT"
echo ""
echo "📊 Useful commands:"
echo "   Check status:  curl -s http://localhost:26657/status | jq .result.sync_info"
echo "   View logs:     tail -f $HOME_DIR/pokerchaind.log"
echo "   Stop node:     pkill pokerchaind"
echo "   Restart node:  pokerchaind start --home $HOME_DIR"
echo ""
