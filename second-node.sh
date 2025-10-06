#!/bin/bash

# Script to set up a second node for pokerchain
# Usage: ./second-node.sh <node-moniker> [genesis-source]
# Example: ./second-node.sh node1.block52.xyz

set -e

MONIKER="${1:-node1.block52.xyz}"
CHAIN_ID="pokerchain"
GENESIS_SOURCE="${2:-./genesis.json}"
NODE_HOME="$HOME/.pokerchain"

echo "Setting up second node: $MONIKER"
echo "Chain ID: $CHAIN_ID"
echo "Genesis source: $GENESIS_SOURCE"

# Initialize the node
echo "Initializing node..."
pokerchaind init "$MONIKER" --chain-id "$CHAIN_ID" --home "$NODE_HOME"

# Copy genesis.json
echo "Copying genesis.json..."
if [ -f "$GENESIS_SOURCE" ]; then
    cp "$GENESIS_SOURCE" "$NODE_HOME/config/genesis.json"
    echo "Genesis file copied successfully"
else
    echo "Error: Genesis file not found at $GENESIS_SOURCE"
    exit 1
fi

# Fix minimum gas prices in app.toml
echo "Configuring minimum gas prices..."
sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "0stake"/' "$NODE_HOME/config/app.toml"
echo "Minimum gas prices set to '0stake'"

# Configure node settings
echo "Configuring node settings..."

# Update config.toml
CONFIG_FILE="$NODE_HOME/config/config.toml"

# Set external address (if this is node1.block52.xyz)
if [[ "$MONIKER" == *"block52.xyz"* ]]; then
    echo "Configuring for external node..."
    sed -i 's/external_address = ""/external_address = "node1.block52.xyz:26656"/' "$CONFIG_FILE"
fi

# Configure persistent peers (add your local node or other peers here)
# You'll need to add the peer ID and address of other nodes
# sed -i 's/persistent_peers = ""/persistent_peers = "PEER_ID@IP:PORT"/' "$CONFIG_FILE"

# Configure seeds if needed
# sed -i 's/seeds = ""/seeds = "SEED_ID@IP:PORT"/' "$CONFIG_FILE"

# Update app.toml for API settings
APP_CONFIG="$NODE_HOME/config/app.toml"

# Enable API server
sed -i 's/enable = false/enable = true/' "$APP_CONFIG"
sed -i 's/swagger = false/swagger = true/' "$APP_CONFIG"

# Configure CORS for API
sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP_CONFIG"

echo "Node configuration completed!"
echo ""
echo "Next steps:"
echo "1. Configure persistent_peers in $CONFIG_FILE"
echo "2. Update any firewall settings for ports 26656, 26657, 1317"
echo "3. Start the node with: pokerchaind start --home $NODE_HOME"
echo ""
echo "Important ports:"
echo "- P2P: 26656"
echo "- RPC: 26657" 
echo "- API: 1317"
echo ""
echo "To connect nodes, exchange peer information:"
echo "Get this node's peer ID: pokerchaind tendermint show-node-id --home $NODE_HOME"