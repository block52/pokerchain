#!/bin/bash

# Deploy Sync Node to Remote Server
# Sets up a read-only sync node on a remote Linux server
# Syncs from the production network (node1.block52.xyz)

set -e

# Configuration
CHAIN_BINARY="pokerchaind"
CHAIN_ID="pokerchain"
NODE_HOME="/root/.pokerchain"
SYNC_NODE="node1.block52.xyz"
SYNC_NODE_RPC="http://node1.block52.xyz:26657"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get remote host and user
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <remote-host> [remote-user]${NC}"
    echo ""
    echo "Example:"
    echo "  $0 node2.example.com root"
    echo "  $0 192.168.1.100 ubuntu"
    exit 1
fi

REMOTE_HOST="$1"
REMOTE_USER="${2:-root}"

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║        🎲 Deploy Pokerchain Sync Node to Remote Server 🎲        ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "Target Server: ${CYAN}$REMOTE_USER@$REMOTE_HOST${NC}"
    echo "Sync Source:   ${CYAN}$SYNC_NODE${NC}"
    echo ""
}

# Check SSH connectivity
check_ssh() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Checking SSH Connectivity${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH connection successful"
    else
        echo -e "${RED}❌ Cannot connect to $REMOTE_USER@$REMOTE_HOST${NC}"
        echo ""
        echo "Please ensure:"
        echo "  1. SSH key is set up (ssh-copy-id $REMOTE_USER@$REMOTE_HOST)"
        echo "  2. Host is accessible"
        echo "  3. User has sudo privileges"
        exit 1
    fi
}

# Detect target architecture
detect_remote_arch() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Detecting Remote Architecture${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local arch=$(ssh "$REMOTE_USER@$REMOTE_HOST" 'uname -m')
    local os=$(ssh "$REMOTE_USER@$REMOTE_HOST" 'uname -s' | tr '[:upper:]' '[:lower:]')
    
    echo "Remote OS: $os"
    echo "Remote Architecture: $arch"
    
    if [ "$os" != "linux" ]; then
        echo -e "${RED}❌ Only Linux is supported for remote deployment${NC}"
        exit 1
    fi
    
    case "$arch" in
        x86_64)
            TARGET_ARCH="amd64"
            BUILD_TARGET="linux-amd64"
            ;;
        aarch64|arm64)
            TARGET_ARCH="arm64"
            BUILD_TARGET="linux-arm64"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓${NC} Target: linux/$TARGET_ARCH"
}

# Build binary for target architecture
build_binary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Building Binary for $BUILD_TARGET${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    LOCAL_BINARY="./build/pokerchaind-${BUILD_TARGET}"
    
    # Check if binary already exists and is correct architecture
    if [ -f "$LOCAL_BINARY" ]; then
        if command -v file &> /dev/null; then
            local file_output=$(file "$LOCAL_BINARY")
            if echo "$file_output" | grep -q "Linux"; then
                echo -e "${GREEN}✓${NC} Found existing binary: $LOCAL_BINARY"
                
                read -p "Use existing binary? (y/n): " use_existing
                if [[ $use_existing =~ ^[Yy]$ ]]; then
                    return 0
                fi
            fi
        fi
    fi
    
    # Build the binary
    mkdir -p ./build
    
    echo "Building pokerchaind for linux/$TARGET_ARCH..."
    
    if [ -f "Makefile" ] && grep -q "build-${BUILD_TARGET}:" Makefile; then
        make build-${BUILD_TARGET}
    else
        GOOS=linux GOARCH=$TARGET_ARCH go build -o "$LOCAL_BINARY" ./cmd/pokerchaind
    fi
    
    if [ -f "$LOCAL_BINARY" ]; then
        echo -e "${GREEN}✓${NC} Build successful: $LOCAL_BINARY"
        
        if command -v file &> /dev/null; then
            file "$LOCAL_BINARY"
        fi
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
}

# Upload binary
upload_binary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Uploading Binary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "Uploading $LOCAL_BINARY to remote server..."
    
    scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind
        sudo chmod +x /usr/local/bin/pokerchaind
        sudo chown root:root /usr/local/bin/pokerchaind
    "
    
    echo -e "${GREEN}✓${NC} Binary installed to /usr/local/bin/pokerchaind"
    
    # Verify binary works
    echo ""
    echo "Verifying binary..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "pokerchaind version" || echo "Version: unknown"
}

# Initialize remote node
initialize_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Initializing Remote Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check if node already exists
    local exists=$(ssh "$REMOTE_USER@$REMOTE_HOST" "[ -d $NODE_HOME ] && echo 'yes' || echo 'no'")
    
    if [ "$exists" = "yes" ]; then
        echo -e "${YELLOW}⚠ Node directory already exists on remote server${NC}"
        echo ""
        read -p "Reset node data? (y/n): " reset_node
        
        if [[ $reset_node =~ ^[Yy]$ ]]; then
            echo "Removing existing node data..."
            ssh "$REMOTE_USER@$REMOTE_HOST" "
                sudo systemctl stop pokerchaind 2>/dev/null || true
                pkill -9 pokerchaind 2>/dev/null || true
                rm -rf $NODE_HOME
            "
        else
            echo "Using existing node data"
            return 0
        fi
    fi
    
    local moniker="sync-node-$REMOTE_HOST"
    
    echo "Initializing node on remote server..."
    echo "  Moniker: $moniker"
    echo "  Chain ID: $CHAIN_ID"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        pokerchaind init '$moniker' --chain-id $CHAIN_ID --home $NODE_HOME
    "
    
    echo -e "${GREEN}✓${NC} Node initialized"
}

# Download genesis
download_genesis() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Downloading Genesis${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "Downloading genesis from $SYNC_NODE_RPC..."
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        curl -s '$SYNC_NODE_RPC/genesis' | jq -r .result.genesis > $NODE_HOME/config/genesis.json
        
        if [ -f $NODE_HOME/config/genesis.json ] && [ -s $NODE_HOME/config/genesis.json ]; then
            echo 'Genesis downloaded successfully'
        else
            echo 'Failed to download genesis'
            exit 1
        fi
    "
    
    echo -e "${GREEN}✓${NC} Genesis downloaded"
}

# Configure node
configure_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Configuring Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Upload template app.toml if it exists
    if [ -f "./template-app.toml" ]; then
        echo "Uploading template app.toml..."
        scp ./template-app.toml "$REMOTE_USER@$REMOTE_HOST:/tmp/app.toml"
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            mv /tmp/app.toml $NODE_HOME/config/app.toml
        "
    fi
    
    # Get sync node ID
    echo "Getting sync node ID from $SYNC_NODE..."
    local sync_node_id=$(curl -s "$SYNC_NODE_RPC/status" | jq -r .result.node_info.id 2>/dev/null)
    
    if [ -n "$sync_node_id" ] && [ "$sync_node_id" != "null" ]; then
        echo -e "${GREEN}✓${NC} Sync node ID: $sync_node_id"
        local persistent_peer="${sync_node_id}@${SYNC_NODE}:26656"
        
        echo "Configuring node settings..."
        ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
            # Set persistent peer
            sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$persistent_peer\"/g" $NODE_HOME/config/config.toml
            
            # Enable API
            sed -i.bak 's/enable = false/enable = true/g' $NODE_HOME/config/app.toml
            sed -i.bak 's|address = "tcp://localhost:1317"|address = "tcp://0.0.0.0:1317"|g' $NODE_HOME/config/app.toml
            
            # Enable Swagger
            sed -i.bak 's/swagger = false/swagger = true/g' $NODE_HOME/config/app.toml
            
            # Set minimum gas prices
            if grep -q 'minimum-gas-prices = ""' $NODE_HOME/config/app.toml; then
                sed -i.bak 's/minimum-gas-prices = ""/minimum-gas-prices = "0.001stake"/g' $NODE_HOME/config/app.toml
            elif grep -q "minimum-gas-prices = ''" $NODE_HOME/config/app.toml; then
                sed -i.bak "s/minimum-gas-prices = ''/minimum-gas-prices = \"0.001stake\"/g" $NODE_HOME/config/app.toml
            fi
            
            # Development-friendly settings
            sed -i.bak 's/addr_book_strict = true/addr_book_strict = false/g' $NODE_HOME/config/config.toml
            
            # Bind RPC to all interfaces (optional, comment out for localhost only)
            sed -i.bak 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|g' $NODE_HOME/config/config.toml
            
            # Clean up backup files
            rm -f $NODE_HOME/config/*.bak
EOF
        
        echo -e "${GREEN}✓${NC} Node configured"
        echo ""
        echo "Configuration:"
        echo "  Sync Peer: $persistent_peer"
        echo "  RPC: http://$REMOTE_HOST:26657"
        echo "  API: http://$REMOTE_HOST:1317"
    else
        echo -e "${YELLOW}⚠ Could not get sync node ID${NC}"
        echo "You may need to manually configure persistent_peers"
    fi
}

# Setup systemd service
setup_systemd() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up Systemd Service${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check if pokerchaind.service exists
    if [ ! -f "./pokerchaind.service" ]; then
        echo -e "${YELLOW}⚠ pokerchaind.service not found, creating default service file${NC}"
        
        # Create a default service file
        cat > /tmp/pokerchaind.service << 'EOFSERVICE'
[Unit]
Description=Pokerchain Node
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/pokerchaind start --home /root/.pokerchain --minimum-gas-prices="0.001stake"
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOFSERVICE
        
        LOCAL_SERVICE_FILE="/tmp/pokerchaind.service"
    else
        LOCAL_SERVICE_FILE="./pokerchaind.service"
    fi
    
    echo "Uploading systemd service file..."
    scp "$LOCAL_SERVICE_FILE" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind.service"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
        # Stop any running pokerchaind
        systemctl stop pokerchaind 2>/dev/null || true
        pkill -9 pokerchaind 2>/dev/null || true
        sleep 2
        
        # Install service
        mv /tmp/pokerchaind.service /etc/systemd/system/
        chmod 644 /etc/systemd/system/pokerchaind.service
        
        # Reload systemd
        systemctl daemon-reload
        
        # Enable service
        systemctl enable pokerchaind
EOF
    
    echo -e "${GREEN}✓${NC} Systemd service installed and enabled"
}

# Setup firewall
setup_firewall() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up Firewall${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Configure UFW firewall? (y/n): " setup_fw
    
    if [[ ! $setup_fw =~ ^[Yy]$ ]]; then
        echo "Skipping firewall configuration"
        return 0
    fi
    
    echo "Configuring UFW firewall..."
    
    ssh "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
        # Install UFW if not present
        if ! command -v ufw &> /dev/null; then
            echo "Installing UFW..."
            apt-get update -qq
            apt-get install -y ufw
        fi
        
        # Reset UFW to default state
        ufw --force reset
        
        # Set default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH (critical!)
        ufw allow 22/tcp comment 'SSH'
        
        # Allow P2P port for Tendermint
        ufw allow 26656/tcp comment 'Tendermint P2P'
        
        # Allow RPC port for Tendermint
        ufw allow 26657/tcp comment 'Tendermint RPC'
        
        # Allow API port for Cosmos SDK REST API
        ufw allow 1317/tcp comment 'Cosmos REST API'
        
        # Allow gRPC port
        ufw allow 9090/tcp comment 'gRPC'
        
        # Allow gRPC-web port
        ufw allow 9091/tcp comment 'gRPC-web'
        
        # Enable UFW
        ufw --force enable
        
        # Show status
        echo ""
        echo "Firewall Status:"
        ufw status numbered
EOF
    
    echo -e "${GREEN}✓${NC} Firewall configured"
}

# Start node
start_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Start node now? (y/n): " start_now
    
    if [[ $start_now =~ ^[Yy]$ ]]; then
        echo "Starting pokerchaind service..."
        ssh "$REMOTE_USER@$REMOTE_HOST" "systemctl start pokerchaind"
        
        echo ""
        echo "Waiting for node to start..."
        sleep 5
        
        # Check status
        ssh "$REMOTE_USER@$REMOTE_HOST" "systemctl status pokerchaind --no-pager -l" || true
        
        echo ""
        echo -e "${GREEN}✓${NC} Node started"
    else
        echo "Node not started. Start manually with:"
        echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl start pokerchaind'"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                    ║${NC}"
    echo -e "${GREEN}║            🎉 Deployment Complete! 🎉                             ║${NC}"
    echo -e "${GREEN}║                                                                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Node Information:${NC}"
    echo "  Host: $REMOTE_HOST"
    echo "  Type: Read-only sync node"
    echo "  Syncing from: $SYNC_NODE"
    echo ""
    echo -e "${YELLOW}Endpoints:${NC}"
    echo "  RPC:  http://$REMOTE_HOST:26657"
    echo "  API:  http://$REMOTE_HOST:1317"
    echo "  gRPC: $REMOTE_HOST:9090"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  # Check service status"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl status pokerchaind'"
    echo ""
    echo "  # View logs"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'journalctl -u pokerchaind -f'"
    echo ""
    echo "  # Check sync status"
    echo "  curl http://$REMOTE_HOST:26657/status | jq .result.sync_info"
    echo ""
    echo "  # Stop node"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl stop pokerchaind'"
    echo ""
    echo "  # Restart node"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl restart pokerchaind'"
    echo ""
    echo -e "${YELLOW}Note: Initial sync may take some time.${NC}"
    echo -e "${YELLOW}Watch for 'catching_up: false' in the sync status.${NC}"
    echo ""
}

# Main function
main() {
    print_header
    
    # Preflight checks
    check_ssh
    detect_remote_arch
    
    # Build and deploy
    build_binary
    upload_binary
    
    # Initialize and configure
    initialize_node
    download_genesis
    configure_node
    
    # Setup infrastructure
    setup_systemd
    setup_firewall
    
    # Start node
    start_node
    
    # Show summary
    show_summary
}

# Run main
main