#!/bin/bash

# Setup Validator Node on node1.block52.xyz
# Downloads binary from GitHub, uses seed from seeds.txt, syncs blockchain state

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
NODE_HOST="${1:-node1.block52.xyz}"
NODE_USER="${2:-root}"
PRIMARY_NODE="node.texashodl.net"
PRIMARY_USER="root"
CHAIN_ID="pokerchain"
MONIKER="validator-node1"

# Get version from Makefile
VERSION=$(grep "^VERSION" Makefile | awk '{print $3}')
if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ Could not determine version from Makefile${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Setting up Validator Node: ${NODE_HOST}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Target: ${NODE_USER}@${NODE_HOST}"
echo "Primary: ${PRIMARY_USER}@${PRIMARY_NODE}"
echo "Version: ${VERSION}"
echo "Chain ID: ${CHAIN_ID}"
echo ""

# Read first seed from seeds.txt
if [ ! -f "seeds.txt" ]; then
    echo -e "${RED}❌ seeds.txt file not found${NC}"
    exit 1
fi

SEED_PHRASE=$(head -n 1 seeds.txt | grep -v "^#" | grep -v "^$")
if [ -z "$SEED_PHRASE" ]; then
    echo -e "${RED}❌ Could not read seed phrase from seeds.txt${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Seed phrase loaded from seeds.txt (line 1)"
echo ""

# Check genvalidatorkey tool
if [ ! -f "./genvalidatorkey" ]; then
    echo -e "${YELLOW}⚠️  genvalidatorkey not found, building it...${NC}"
    go build -o genvalidatorkey ./genvalidatorkey.go
    echo -e "${GREEN}✓${NC} genvalidatorkey built"
fi

# Generate validator key locally
echo -e "${YELLOW}Step 1: Generating validator key...${NC}"
TEMP_KEY="/tmp/priv_validator_key_$$.json"
./genvalidatorkey "$SEED_PHRASE" "$TEMP_KEY" 2>&1 || {
    echo -e "${RED}❌ Failed to generate validator key${NC}"
    rm -f "$TEMP_KEY"
    exit 1
}

if [ ! -f "$TEMP_KEY" ] || [ ! -s "$TEMP_KEY" ]; then
    echo -e "${RED}❌ Validator key file not created or is empty${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Validator key generated"
echo ""

# Step 2: Stop service if running
echo -e "${YELLOW}Step 2: Stopping pokerchaind service (if running)...${NC}"
ssh ${NODE_USER}@${NODE_HOST} "systemctl stop pokerchaind 2>/dev/null || true"
echo -e "${GREEN}✓${NC} Service stopped"
echo ""

# Step 3: Backup and download new binary
echo -e "${YELLOW}Step 3: Installing pokerchaind ${VERSION}...${NC}"
ssh ${NODE_USER}@${NODE_HOST} << ENDSSH
set -e

# Backup current binary if exists
if [ -f /usr/local/bin/pokerchaind ]; then
    cp /usr/local/bin/pokerchaind /usr/local/bin/pokerchaind.backup.\$(date +%Y%m%d_%H%M%S) || true
fi

# Download from GitHub release
cd /tmp
echo "Downloading ${VERSION}..."
wget -q https://github.com/block52/pokerchain/releases/download/${VERSION}/pokerchaind-linux-amd64-${VERSION}.tar.gz

# Extract and install
tar -xzf pokerchaind-linux-amd64-${VERSION}.tar.gz
mv pokerchaind-linux-amd64 /usr/local/bin/pokerchaind
chmod +x /usr/local/bin/pokerchaind

# Cleanup
rm pokerchaind-linux-amd64-${VERSION}.tar.gz

# Verify
/usr/local/bin/pokerchaind version
ENDSSH

echo -e "${GREEN}✓${NC} Binary installed"
echo ""

# Step 4: Reset blockchain data
echo -e "${YELLOW}Step 4: Resetting blockchain data...${NC}"
ssh ${NODE_USER}@${NODE_HOST} << ENDSSH
set -e

# Backup current data
if [ -d ~/.pokerchain/data ]; then
    mv ~/.pokerchain/data ~/.pokerchain/data.backup.\$(date +%Y%m%d_%H%M%S) || true
fi

# Reset using comet
pokerchaind comet unsafe-reset-all --home ~/.pokerchain 2>/dev/null || {
    # If that fails, just remove the data directory
    rm -rf ~/.pokerchain/data
    mkdir -p ~/.pokerchain/data
}

echo "Data reset complete"
ENDSSH

echo -e "${GREEN}✓${NC} Data reset"
echo ""

# Step 5: Copy validator key
echo -e "${YELLOW}Step 5: Installing validator key...${NC}"
scp "$TEMP_KEY" ${NODE_USER}@${NODE_HOST}:~/.pokerchain/config/priv_validator_key.json
rm -f "$TEMP_KEY"
echo -e "${GREEN}✓${NC} Validator key installed"
echo ""

# Step 6: Create priv_validator_state.json
echo -e "${YELLOW}Step 6: Creating priv_validator_state.json...${NC}"
ssh ${NODE_USER}@${NODE_HOST} << 'ENDSSH'
cat > ~/.pokerchain/data/priv_validator_state.json << 'EOF'
{
  "height": "0",
  "round": 0,
  "step": 0
}
EOF
ENDSSH

echo -e "${GREEN}✓${NC} priv_validator_state.json created"
echo ""

# Step 7: Copy genesis.json from primary node
echo -e "${YELLOW}Step 7: Copying genesis.json from primary node...${NC}"
scp ${PRIMARY_USER}@${PRIMARY_NODE}:~/.pokerchain/config/genesis.json /tmp/genesis.json.$$
scp /tmp/genesis.json.$$ ${NODE_USER}@${NODE_HOST}:~/.pokerchain/config/genesis.json
rm -f /tmp/genesis.json.$$
echo -e "${GREEN}✓${NC} genesis.json copied"
echo ""

# Step 8: Get primary node ID for peers
echo -e "${YELLOW}Step 8: Configuring peers...${NC}"
PRIMARY_NODE_ID=$(ssh ${PRIMARY_USER}@${PRIMARY_NODE} "pokerchaind comet show-node-id")
echo "Primary node ID: $PRIMARY_NODE_ID"

ssh ${NODE_USER}@${NODE_HOST} << ENDSSH
set -e

# Set persistent peers
sed -i.bak "s/^persistent_peers = .*/persistent_peers = \"${PRIMARY_NODE_ID}@${PRIMARY_NODE}:26656\"/" ~/.pokerchain/config/config.toml

# Set external address
sed -i.bak "s/^external_address = .*/external_address = \"${NODE_HOST}:26656\"/" ~/.pokerchain/config/config.toml

# Enable prometheus (optional)
sed -i.bak 's/^prometheus = false/prometheus = true/' ~/.pokerchain/config/config.toml

rm -f ~/.pokerchain/config/config.toml.bak

echo "Peers configured"
ENDSSH

echo -e "${GREEN}✓${NC} Peers configured"
echo ""

# Step 9: Copy app.toml from primary (for bridge config)
echo -e "${YELLOW}Step 9: Copying app.toml from primary node...${NC}"
scp ${PRIMARY_USER}@${PRIMARY_NODE}:~/.pokerchain/config/app.toml /tmp/app.toml.$$
scp /tmp/app.toml.$$ ${NODE_USER}@${NODE_HOST}:~/.pokerchain/config/app.toml
rm -f /tmp/app.toml.$$
echo -e "${GREEN}✓${NC} app.toml copied"
echo ""

# Step 10: Create/update systemd service
echo -e "${YELLOW}Step 10: Creating systemd service...${NC}"
ssh ${NODE_USER}@${NODE_HOST} << 'ENDSSH'
cat > /etc/systemd/system/pokerchaind.service << 'EOF'
[Unit]
Description=Pokerchain Validator Node
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/pokerchaind start --home /root/.pokerchain
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_HOME=/root/.pokerchain"
Environment="DAEMON_NAME=pokerchaind"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pokerchaind

echo "Service created"
ENDSSH

echo -e "${GREEN}✓${NC} Systemd service created"
echo ""

# Step 11: Start the service
echo -e "${YELLOW}Step 11: Starting pokerchaind service...${NC}"
ssh ${NODE_USER}@${NODE_HOST} "systemctl start pokerchaind"
sleep 3
echo -e "${GREEN}✓${NC} Service started"
echo ""

# Step 12: Check status
echo -e "${YELLOW}Step 12: Checking service status...${NC}"
ssh ${NODE_USER}@${NODE_HOST} "systemctl status pokerchaind --no-pager | head -15"
echo ""

# Step 13: Show sync status
echo ""
echo -e "${YELLOW}Step 13: Checking sync status...${NC}"
sleep 5
ssh ${NODE_USER}@${NODE_HOST} "curl -s http://localhost:26657/status | jq -r '.result.sync_info | {catching_up, latest_block_height, latest_block_time}'"
echo ""

# Get validator address
VALIDATOR_ADDR=$(ssh ${NODE_USER}@${NODE_HOST} "pokerchaind comet show-address")

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Validator node setup completed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Node: ${NODE_HOST}"
echo "Version: ${VERSION}"
echo "Validator Address: ${VALIDATOR_ADDR}"
echo ""
echo "The node is now syncing with the network."
echo "Wait for 'catching_up: false' before creating the validator."
echo ""
echo "To monitor sync progress:"
echo "  ssh ${NODE_USER}@${NODE_HOST} 'curl -s http://localhost:26657/status | jq .result.sync_info'"
echo ""
echo "To view logs:"
echo "  ssh ${NODE_USER}@${NODE_HOST} 'journalctl -u pokerchaind -f'"
echo ""
echo "Once synced, create the validator with:"
echo "  ./add-validator.sh"
echo ""
