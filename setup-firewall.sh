#!/bin/bash
# Firewall setup script for pokerchaind nodes
# Usage: ./setup-firewall.sh [remote-host] [remote-user]

set -e

# Get remote host from arguments or prompt user
if [ -z "$1" ]; then
    echo "🔥 Setting up UFW Firewall for Pokerchaind"
    echo "=========================================="
    echo ""
    read -p "Enter remote host (hostname or IP): " REMOTE_HOST
    
    if [ -z "$REMOTE_HOST" ]; then
        echo "❌ Remote host cannot be empty"
        exit 1
    fi
else
    REMOTE_HOST="$1"
fi

REMOTE_USER="${2:-root}"

echo ""
echo "🔥 Setting up UFW Firewall for Pokerchaind"
echo "=========================================="
echo "Target: $REMOTE_USER@$REMOTE_HOST"
echo ""

# Setup firewall rules
echo "⚙️  Configuring firewall rules..."

ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo "📦 Installing UFW..."
    apt-get update -qq
    apt-get install -y ufw
fi

# Reset UFW to default state
echo "🔄 Resetting UFW to defaults..."
ufw --force reset

# Set default policies
echo "📋 Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (critical - do this first!)
echo "🔓 Allowing SSH (port 22)..."
ufw allow 22/tcp comment 'SSH'

# Allow P2P port for Tendermint
echo "🔓 Allowing P2P (port 26656)..."
ufw allow 26656/tcp comment 'Tendermint P2P'

# Allow RPC port for Tendermint
echo "🔓 Allowing RPC (port 26657)..."
ufw allow 26657/tcp comment 'Tendermint RPC'

# Allow API port for Cosmos SDK REST API
echo "🔓 Allowing API (port 1317)..."
ufw allow 1317/tcp comment 'Cosmos REST API'

# Allow gRPC port
echo "🔓 Allowing gRPC (port 9090)..."
ufw allow 9090/tcp comment 'gRPC'

# Allow gRPC-web port
echo "🔓 Allowing gRPC-web (port 9091)..."
ufw allow 9091/tcp comment 'gRPC-web'


# Allow HTTPS for NGINX (optional)
echo "🔓 Allowing HTTPS (port 443)..."
ufw allow 443/tcp comment 'HTTPS (NGINX)'

# Allow gRPC over HTTPS (optional)
echo "🔓 Allowing gRPC HTTPS (port 9443)..."
ufw allow 9443/tcp comment 'gRPC HTTPS (NGINX)'

# Enable UFW
echo "✅ Enabling UFW..."
ufw --force enable

# Show status
echo ""
echo "📊 Firewall Status:"
ufw status numbered
EOF

echo ""
echo "🎉 Firewall Setup Complete!"
echo "=========================="
echo ""
echo "📋 Allowed Ports:"
echo "  • 22    - SSH (management)"
echo "  • 443   - HTTPS (NGINX)"
echo "  • 1317  - Cosmos REST API (client access)"
echo "  • 9090  - gRPC (client access)"
echo "  • 9091  - gRPC-web (client access)"
echo "  • 9443  - gRPC HTTPS (NGINX)"
echo "  • 26656 - Tendermint P2P (peer connections)"
echo "  • 26657 - Tendermint RPC (queries)"
echo ""
echo "🔒 All other incoming connections are blocked"
echo ""
echo "📊 To check firewall status:"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'ufw status verbose'"
echo ""
echo "🛑 To disable firewall (not recommended):"
echo "ssh $REMOTE_USER@$REMOTE_HOST 'ufw disable'"
echo ""