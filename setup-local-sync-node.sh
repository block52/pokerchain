#!/bin/bash

# Local Sync Node Setup Script
# Sets up a local read-only sync node that syncs from node1.block52.xyz
#
# Features:
# - Auto-detects CPU architecture and builds native binary
#   * ARM64 (M1/M2/M3 Mac)
#   * x86_64 (Intel Mac, Linux)
# - Uses local genesis.json file from repository
# - Configures node to connect to node1.block52.xyz as persistent peer
# - Runs in terminal foreground (not as systemd service)
# - macOS and Linux compatible
# - Development-friendly: no remote genesis verification (faster setup)
# - Interactive rebuild option for testing
#
# Usage: ./setup-local-sync-node.sh
#
# Note: When prompted to rebuild, answer 'y' to test with latest code changes

set -e

# Detect OS and set sha256 command
if [[ "$OSTYPE" == "darwin"* ]]; then
    SHA256="shasum -a 256"
else
    SHA256="sha256sum"
fi

# Configuration
CHAIN_ID="pokerchain"
HOME_DIR="$HOME/.pokerchain"
SEED_NODE_HOST="node1.block52.xyz"
SEED_NODE_ID="08890a89197b2afd56b115e9b749cef7d4578c5c"
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
echo -e "${BLUE}🔧 Step 1: Building pokerchaind binary...${NC}"
echo "----------------------------------------"

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s)
echo "Detected: $OS / $ARCH"

BINARY_PATH="$HOME/go/bin/pokerchaind"
if [ -f "$BINARY_PATH" ]; then
    EXISTING_VERSION=$(pokerchaind version 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}⚠️  Found existing pokerchaind binary${NC}"
    echo "   Path: $BINARY_PATH"
    echo "   Version: $EXISTING_VERSION"
    echo ""
    read -p "Do you want to rebuild it? (y/n): " REBUILD_CHOICE
    if [[ "$REBUILD_CHOICE" =~ ^[Yy]$ ]]; then
        echo ""
        echo "🔧 Rebuilding pokerchaind for $ARCH..."
        echo "   Building native binary (no cross-compilation)"
        if ! make install; then
            echo -e "${RED}❌ Build failed${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Build complete!${NC}"
    else
        echo -e "${GREEN}✅ Using existing binary.${NC}"
    fi
else
    echo "🔧 Building pokerchaind for $ARCH..."
    echo "   Building native binary (no cross-compilation)"
    if ! make install; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Build complete!${NC}"
fi

echo ""

# Verify installation and add to PATH if needed
export PATH="$HOME/go/bin:$PATH"

if ! command -v pokerchaind &> /dev/null; then
    echo -e "${RED}❌ pokerchaind not found even after adding to PATH${NC}"
    echo "Check if binary exists: ls -la $HOME/go/bin/pokerchaind"
    exit 1
fi

BINARY_VERSION=$(pokerchaind version 2>/dev/null || echo "unknown")
BINARY_SIZE=$(ls -lh "$BINARY_PATH" | awk '{print $5}')
echo ""
echo "📦 Binary Information:"
echo "   Version: $BINARY_VERSION"
echo "   Architecture: $ARCH ($OS)"
echo "   Size: $BINARY_SIZE"
echo "   Location: $(which pokerchaind)"
echo -e "${GREEN}✅ Binary ready for sync!${NC}"

# Step 2: Check configuration files
echo ""
echo -e "${BLUE}📋 Step 2: Checking configuration files...${NC}"
echo "------------------------------------------"

# Check for genesis file
if [ ! -f "./genesis.json" ]; then
    echo -e "${RED}❌ Genesis file not found at ./genesis.json${NC}"
    exit 1
fi

# Check for config files
if [ ! -f "./app.toml" ]; then
    echo -e "${RED}❌ app.toml not found${NC}"
    exit 1
fi

if [ ! -f "./config.toml" ]; then
    echo -e "${RED}❌ config.toml not found${NC}"
    exit 1
fi

LOCAL_GENESIS_HASH=$($SHA256 "./genesis.json" | cut -d' ' -f1)
echo -e "${GREEN}✅ All configuration files ready!${NC}"
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

# macOS and Linux compatible sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^persistent_peers = .*|persistent_peers = \"${SEED_NODE_ID}@${SEED_NODE_HOST}:${SEED_NODE_PORT}\"|" "$TEMP_CONFIG"
else
    sed -i "s|^persistent_peers = .*|persistent_peers = \"${SEED_NODE_ID}@${SEED_NODE_HOST}:${SEED_NODE_PORT}\"|" "$TEMP_CONFIG"
fi

echo "📋 Installing genesis file..."
cp "./genesis.json" "$HOME_DIR/config/genesis.json"

echo "⚙️  Installing app.toml..."
cp "./app.toml" "$HOME_DIR/config/app.toml"

echo "⚙️  Installing config.toml (with persistent peers)..."
cp "$TEMP_CONFIG" "$HOME_DIR/config/config.toml"

# Clean up temp file
rm -f "$TEMP_CONFIG"

echo "🔍 Verifying genesis hash..."
INSTALLED_HASH=$($SHA256 "$HOME_DIR/config/genesis.json" | cut -d' ' -f1)
echo "   Installed genesis hash: $INSTALLED_HASH"
echo "   Source genesis hash:    $LOCAL_GENESIS_HASH"

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

# Step 8: Start node in foreground
echo ""
echo -e "${BLUE}🚀 Step 8: Ready to start sync node!${NC}"
echo "-----------------------------------"

echo ""
echo -e "${GREEN}✅ Setup complete! Ready to start syncing from node1.block52.xyz${NC}"
echo ""
echo "📊 Useful commands (open in another terminal):"
echo "   Monitor sync:  curl -s http://localhost:26657/status | jq .result.sync_info"
echo "   Stop node:     pkill pokerchaind"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Press Enter to start the node in this terminal (Ctrl+C to stop)..."

echo ""
echo "🚀 Starting pokerchaind sync node..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start node in foreground
pokerchaind start --home "$HOME_DIR"
