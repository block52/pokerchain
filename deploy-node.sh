#!/bin/bash

# Complete deployment script for pokerchain
# Builds locally, then deploys binary, genesis, and scripts to remote node
# Usage: ./deploy-node.sh <remote-host> [remote-user] [moniker]

set -e

REMOTE_HOST="$1"
REMOTE_USER="${2:-$(whoami)}"
MONIKER="${3:-$REMOTE_HOST}"

if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 <remote-host> [remote-user] [moniker]"
    echo "Example: $0 node1.block52.xyz ubuntu node1.block52.xyz"
    exit 1
fi

echo "🚀 Pokerchain Complete Deployment"
echo "================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo "Moniker: $MONIKER"
echo ""

# Step 1: Build locally
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

# Step 2: Check prerequisites
echo ""
echo "🔍 Step 2: Checking prerequisites..."
echo "-----------------------------------"

# Check if genesis file exists
if [ ! -f "./genesis.json" ]; then
    echo "❌ Genesis file not found at ./genesis.json"
    exit 1
fi
echo "✅ Genesis file found"

# Check remote connectivity
echo "Testing connection to $REMOTE_HOST..."
if ! ssh -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_HOST" "echo 'Connection test successful'" 2>/dev/null; then
    echo "❌ Cannot connect to $REMOTE_USER@$REMOTE_HOST"
    echo "Please check:"
    echo "  - SSH access is configured"
    echo "  - Host is reachable"
    echo "  - Username is correct"
    exit 1
fi
echo "✅ Remote connection successful"

# Step 3: Deploy files
echo ""
echo "📤 Step 3: Deploying files to remote host..."
echo "--------------------------------------------"

# Use the enhanced install-binary script
./install-binary.sh "$REMOTE_HOST" "$REMOTE_USER" --with-genesis

# Step 4: Initialize node remotely
echo ""
echo "🔧 Step 4: Initializing remote node..."
echo "-------------------------------------"

echo "Initializing node with moniker: $MONIKER"
ssh "$REMOTE_USER@$REMOTE_HOST" "./second-node.sh '$MONIKER' genesis.json"

# Step 5: Get node information
echo ""
echo "📋 Step 5: Getting node information..."
echo "------------------------------------"

echo "Retrieving node peer information..."
NODE_INFO=$(ssh "$REMOTE_USER@$REMOTE_HOST" "./get-node-info.sh" 2>/dev/null || echo "Could not retrieve node info")

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "🖥️  Remote node ($REMOTE_HOST) is ready!"
echo ""
echo "Node Information:"
echo "----------------"
echo "$NODE_INFO"
echo ""
echo "🚀 To start the remote node:"
echo "ssh $REMOTE_USER@$REMOTE_HOST"
echo "pokerchaind start"
echo ""
echo "🔗 To connect your local node:"
echo "./connect-to-network.sh $REMOTE_HOST:26656"
echo ""
echo "📊 Monitor the network:"
echo "curl http://$REMOTE_HOST:26657/status"
echo "curl http://$REMOTE_HOST:26657/net_info"
echo ""
echo "🌐 Network endpoints:"
echo "- P2P: $REMOTE_HOST:26656"
echo "- RPC: $REMOTE_HOST:26657"
echo "- API: $REMOTE_HOST:1317"