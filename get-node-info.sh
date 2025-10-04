#!/bin/bash

# Script to get node information for peer connections
# Usage: ./get-node-info.sh [node-home]

set -e

NODE_HOME="${1:-$HOME/.pokerchain}"

echo "Pokerchain Node Information"
echo "=========================="
echo ""

# Check if node is initialized
if [ ! -d "$NODE_HOME" ]; then
    echo "Error: Node not initialized at $NODE_HOME"
    echo "Run: pokerchaind init <moniker> --chain-id pokerchain"
    exit 1
fi

# Get node ID
echo "Node ID:"
pokerchaind tendermint show-node-id --home "$NODE_HOME"
echo ""

# Get validator info
echo "Validator Address:"
pokerchaind tendermint show-validator --home "$NODE_HOME"
echo ""

# Get node address info
echo "Node P2P Address (for peers):"
NODE_ID=$(pokerchaind tendermint show-node-id --home "$NODE_HOME")
echo "$NODE_ID@$(hostname -I | awk '{print $1}'):26656"
echo ""

# Check if node is running
echo "Node Status:"
if curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo "✅ Node is running"
    echo ""
    echo "Current Status:"
    curl -s http://localhost:26657/status | jq -r '.result.sync_info | "Block Height: \(.latest_block_height)\nCatching Up: \(.catching_up)\nLatest Block Time: \(.latest_block_time)"'
else
    echo "❌ Node is not running"
    echo "Start with: pokerchaind start --home $NODE_HOME"
fi
echo ""

# Show peer information
echo "Current Peers:"
if curl -s http://localhost:26657/net_info > /dev/null 2>&1; then
    curl -s http://localhost:26657/net_info | jq -r '.result.peers[] | "- \(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr | split(":")[2])"'
else
    echo "Node not running - cannot get peer info"
fi
echo ""

echo "Configuration Files:"
echo "- Config: $NODE_HOME/config/config.toml"
echo "- App: $NODE_HOME/config/app.toml"
echo "- Genesis: $NODE_HOME/config/genesis.json"
echo ""

echo "To add this node as a peer to another node:"
echo "Add this line to the other node's config.toml:"
echo "persistent_peers = \"$NODE_ID@YOUR_IP_ADDRESS:26656\""