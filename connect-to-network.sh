#!/bin/bash

# Script to connect local node to the pokerchain network
# Usage: ./connect-to-network.sh [peer-address]

set -e

CHAIN_ID="pokerchain"
NODE_HOME="$HOME/.pokerchain"
GENESIS_FILE="./genesis.json"
PEER_ADDRESS="${1:-node1.block52.xyz:26656}"

echo "Connecting to pokerchain network..."
echo "Peer address: $PEER_ADDRESS"

# Check if genesis file exists
if [ ! -f "$GENESIS_FILE" ]; then
    echo "Error: Genesis file not found at $GENESIS_FILE"
    echo "Make sure genesis.json is in the current directory"
    exit 1
fi

# Initialize local node if not already done
if [ ! -d "$NODE_HOME" ]; then
    echo "Initializing local node..."
    pokerchaind init "local-node" --chain-id "$CHAIN_ID" --home "$NODE_HOME"
fi

# Copy genesis file
echo "Updating genesis.json..."
cp "$GENESIS_FILE" "$NODE_HOME/config/genesis.json"

# Copy app.toml if it exists
APP_TOML_FILE="./app.toml"
if [ -f "$APP_TOML_FILE" ]; then
    echo "Updating app.toml..."
    cp "$APP_TOML_FILE" "$NODE_HOME/config/app.toml"
else
    echo "Note: app.toml not found in current directory, using default configuration"
fi

# Get peer ID from remote node (optional, requires access)
echo "Getting peer information..."
echo "Attempting to get peer ID from root@node1.block52.xyz..."

# Try to get peer ID automatically
PEER_ID=""
if command -v ssh &> /dev/null; then
    echo "Using SSH to get node ID from root@node1.block52.xyz..."
    PEER_ID=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@node1.block52.xyz 'pokerchaind tendermint show-node-id' 2>/dev/null || echo "")
    
    if [ -n "$PEER_ID" ]; then
        echo "✅ Successfully retrieved peer ID: $PEER_ID"
    else
        echo "❌ Failed to retrieve peer ID via SSH"
        echo "You can also run: ssh root@node1.block52.xyz 'pokerchaind tendermint show-node-id'"
        echo ""
        read -p "Enter the peer ID manually (or press Enter to skip): " PEER_ID
    fi
else
    echo "SSH not available. Please get peer ID manually:"
    echo "ssh root@node1.block52.xyz 'pokerchaind tendermint show-node-id'"
    echo ""
    read -p "Enter the peer ID from node1.block52.xyz: " PEER_ID
fi

# Configure persistent peers
CONFIG_FILE="$NODE_HOME/config/config.toml"

echo "Configuring network settings..."

if [ -n "$PEER_ID" ]; then
    FULL_PEER="$PEER_ID@$PEER_ADDRESS"
    echo "Adding peer: $FULL_PEER"
    sed -i '' "s/persistent_peers = \"\"/persistent_peers = \"$FULL_PEER\"/" "$CONFIG_FILE"
else
    echo "Warning: No peer ID provided. You'll need to configure it manually."
fi

# Configure other network settings
sed -i '' 's/create_empty_blocks = true/create_empty_blocks = false/' "$CONFIG_FILE"
sed -i '' 's/create_empty_blocks_interval = "0s"/create_empty_blocks_interval = "30s"/' "$CONFIG_FILE"

# Update app.toml
APP_CONFIG="$NODE_HOME/config/app.toml"
sed -i '' 's/enable = false/enable = true/' "$APP_CONFIG"
sed -i '' 's/swagger = false/swagger = true/' "$APP_CONFIG"

echo ""
echo "Configuration complete!"
echo ""
echo "Network information:"
echo "- Chain ID: $CHAIN_ID"
echo "- Genesis file: $NODE_HOME/config/genesis.json"
echo "- Config file: $CONFIG_FILE"
echo "- App config: $APP_CONFIG"
echo ""
echo "To start your node:"
echo "pokerchaind start --home $NODE_HOME"
echo ""
echo "To check sync status:"
echo "curl http://localhost:26657/status"
echo ""
echo "Your node will sync with the network automatically."