#!/bin/bash

# Master Production Node Deployment Script
# Deploys a pre-configured production node to a remote server

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROD_DIR="./production"

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🎲 Production Node Deployment 🎲"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Show usage
usage() {
    echo "Usage: $0 <node-number> <remote-host> [remote-user]"
    echo ""
    echo "Arguments:"
    echo "  node-number   - Number of the node to deploy (from ./production/nodeX/)"
    echo "  remote-host   - Hostname or IP of the remote server"
    echo "  remote-user   - SSH user (default: root)"
    echo ""
    echo "Examples:"
    echo "  $0 1 node2.block52.xyz"
    echo "  $0 2 192.168.1.100 ubuntu"
    echo "  $0 3 node3.example.com root"
    echo ""
    echo "Prerequisites:"
    echo "  1. Run ./setup-production-cluster.sh to generate node configs"
    echo "  2. Ensure SSH access to the remote server"
    echo "  3. Remote server should be Linux (Ubuntu/Debian recommended)"
    echo ""
}

# Check if node directory exists
check_node_dir() {
    local node_num=$1
    local node_dir="$PROD_DIR/node$node_num"
    
    if [ ! -d "$node_dir" ]; then
        echo -e "${RED}❌ Error: Node directory not found: $node_dir${NC}"
        echo ""
        echo "Please generate the node configuration first:"
        echo "  ./setup-production-cluster.sh"
        echo ""
        exit 1
    fi
    
    if [ ! -f "$node_dir/config/genesis.json" ]; then
        echo -e "${RED}❌ Error: Genesis file not found in: $node_dir/config/${NC}"
        echo ""
        echo "Node configuration appears incomplete."
        echo "Please regenerate with: ./setup-production-cluster.sh"
        echo ""
        exit 1
    fi
}

# Test SSH connection
test_ssh() {
    local remote_host=$1
    local remote_user=$2
    
    echo "Testing SSH connection to $remote_user@$remote_host..."
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$remote_user@$remote_host" "echo 'SSH connection successful'" > /dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to $remote_user@$remote_host${NC}"
        echo ""
        echo "Please ensure:"
        echo "  1. SSH is running on the remote server"
        echo "  2. You have SSH key access configured"
        echo "  3. The hostname/IP is correct"
        echo ""
        echo "Test manually with:"
        echo "  ssh $remote_user@$remote_host"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✅ SSH connection successful${NC}"
}

# Clean up old installation
cleanup_old_installation() {
    local remote_host=$1
    local remote_user=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: Cleaning Up Old Installation${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Stopping pokerchaind service (if exists)..."
    ssh "$remote_user@$remote_host" "
        # Stop systemd service
        sudo systemctl stop pokerchaind 2>/dev/null || echo 'Service not found (ok)'
        sudo systemctl disable pokerchaind 2>/dev/null || true
        
        # Kill any running pokerchaind processes
        pkill -9 pokerchaind 2>/dev/null || echo 'No running processes (ok)'
        
        # Wait for processes to die
        sleep 2
        
        # Verify no processes running
        if pgrep pokerchaind > /dev/null; then
            echo 'Warning: pokerchaind still running, forcing kill...'
            killall -9 pokerchaind 2>/dev/null || true
            sleep 1
        fi
        
        echo 'All pokerchaind processes stopped'
    "
    
    echo ""
    echo "Backing up existing data (if any)..."
    ssh "$remote_user@$remote_host" "
        if [ -d ~/.pokerchain ]; then
            BACKUP_DIR=~/pokerchain-backup-\$(date +%Y%m%d-%H%M%S)
            echo \"Creating backup: \$BACKUP_DIR\"
            mkdir -p \$BACKUP_DIR
            cp -r ~/.pokerchain/* \$BACKUP_DIR/ 2>/dev/null || true
            echo \"Backup created: \$BACKUP_DIR\"
        else
            echo 'No existing data to backup'
        fi
    "
    
    echo ""
    echo "Removing old chain data and configuration..."
    ssh "$remote_user@$remote_host" "
        rm -rf ~/.pokerchain
        echo 'Old data removed'
    "
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Build binary
build_binary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Building Linux Binary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if ! command -v make &> /dev/null; then
        echo -e "${RED}❌ make not found${NC}"
        exit 1
    fi
    
    echo "Building for Linux (amd64)..."
    GOOS=linux GOARCH=amd64 make build
    
    if [ ! -f "build/pokerchaind" ]; then
        echo -e "${RED}❌ Build failed - binary not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Binary built successfully${NC}"
}

# Deploy binary
deploy_binary() {
    local remote_host=$1
    local remote_user=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Deploying Binary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Copying pokerchaind to $remote_user@$remote_host:/usr/local/bin/"
    scp build/pokerchaind "$remote_user@$remote_host:/tmp/pokerchaind"
    
    echo "Installing binary..."
    ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind && \
        sudo chmod +x /usr/local/bin/pokerchaind"
    
    echo "Verifying installation..."
    local version=$(ssh "$remote_user@$remote_host" "/usr/local/bin/pokerchaind version" 2>/dev/null || echo "unknown")
    echo "Remote pokerchaind version: $version"
    
    echo -e "${GREEN}✅ Binary deployed successfully${NC}"
}

# Deploy configuration
deploy_config() {
    local node_num=$1
    local remote_host=$2
    local remote_user=$3
    local node_dir="$PROD_DIR/node$node_num"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Deploying Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Creating directories on remote server..."
    ssh "$remote_user@$remote_host" "mkdir -p ~/.pokerchain/config ~/.pokerchain/data"
    
    echo "Copying configuration files..."
    scp -r "$node_dir/config/"* "$remote_user@$remote_host:~/.pokerchain/config/"
    
    echo "Copying data files..."
    if [ -d "$node_dir/data" ] && [ "$(ls -A $node_dir/data 2>/dev/null)" ]; then
        scp -r "$node_dir/data/"* "$remote_user@$remote_host:~/.pokerchain/data/"
    else
        echo "No data files to copy"
    fi
    
    echo "Setting permissions..."
    ssh "$remote_user@$remote_host" "
        chmod 700 ~/.pokerchain
        chmod 700 ~/.pokerchain/config
        chmod 700 ~/.pokerchain/data
        chmod 600 ~/.pokerchain/config/priv_validator_key.json 2>/dev/null || true
        chmod 600 ~/.pokerchain/data/priv_validator_state.json 2>/dev/null || true
    "
    
    echo "Verifying configuration..."
    ssh "$remote_user@$remote_host" "ls -la ~/.pokerchain/config/"
    
    echo -e "${GREEN}✅ Configuration deployed successfully${NC}"
}

# Configure bridge settings in app.toml
configure_bridge() {
    local remote_host=$1
    local remote_user=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Configuring Bridge Settings${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local alchemy_url=""
    local contract_addr="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
    local usdc_addr="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    
    # Check for .env file
    if [ -f ".env" ]; then
        echo "Found .env file, reading ALCHEMY_URL..."
        alchemy_url=$(grep "^ALCHEMY_URL=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$alchemy_url" ]; then
            echo -e "${GREEN}✓ Using ALCHEMY_URL from .env: ${alchemy_url:0:50}...${NC}"
        fi
    fi
    
    # Prompt if not found
    if [ -z "$alchemy_url" ]; then
        echo -e "${YELLOW}⚠️  No ALCHEMY_URL found in .env file${NC}"
        echo ""
        echo "Enter Base/Ethereum RPC URL (Alchemy recommended):"
        echo "Example: https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
        echo ""
        read -p "RPC URL (or press Enter to skip bridge configuration): " alchemy_url
        
        if [ -z "$alchemy_url" ]; then
            echo -e "${YELLOW}⚠️  Skipping bridge configuration${NC}"
            echo "You can configure it later by editing ~/.pokerchain/config/app.toml on the remote node"
            return 0
        fi
    fi
    
    echo ""
    echo "Bridge Configuration:"
    echo "  RPC URL: ${alchemy_url:0:60}..."
    echo "  Deposit Contract: $contract_addr"
    echo "  USDC Contract: $usdc_addr"
    echo ""
    
    read -p "Apply this bridge configuration? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipping bridge configuration"
        return 0
    fi
    
    echo "Adding bridge configuration to app.toml..."
    ssh "$remote_user@$remote_host" "cat >> ~/.pokerchain/config/app.toml << 'EOFBRIDGE'

###############################################################################
###                          Bridge Configuration                           ###
###############################################################################

[bridge]
# Enable the bridge deposit verification
enabled = true

# Ethereum/Base RPC URL for verifying deposits
ethereum_rpc_url = \"$alchemy_url\"

# CosmosBridge deposit contract address on Base
deposit_contract_address = \"$contract_addr\"

# USDC contract address (Base mainnet)
usdc_contract_address = \"$usdc_addr\"

# Polling interval in seconds
polling_interval_seconds = 60

# Starting block number (0 = use recent blocks)
starting_block = 0
EOFBRIDGE
"
    
    echo -e "${GREEN}✅ Bridge configuration added to app.toml${NC}"
}

# Setup firewall
setup_firewall() {
    local remote_host=$1
    local remote_user=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 6: Setting Up Firewall (via setup-firewall.sh)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ ! -f "setup-firewall.sh" ]; then
        echo -e "${RED}❌ setup-firewall.sh not found in current directory${NC}"
        exit 1
    fi
    
    chmod +x ./setup-firewall.sh
    ./setup-firewall.sh "$remote_host" "$remote_user"
}

# Setup systemd service
setup_systemd() {
    local remote_host=$1
    local remote_user=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 7: Setting Up Systemd Service (via setup-systemd.sh)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ ! -f "setup-systemd.sh" ]; then
        echo -e "${RED}❌ setup-systemd.sh not found in current directory${NC}"
        exit 1
    fi

    chmod +x ./setup-systemd.sh
    ./setup-systemd.sh "$remote_host" "$remote_user"
}

# Setup NGINX and SSL
setup_nginx() {
    local remote_host=$1
    local remote_user=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 8: Setting Up NGINX & SSL (Optional)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ ! -f "setup-nginx.sh" ]; then
        echo -e "${YELLOW}⚠️  setup-nginx.sh not found - skipping NGINX setup${NC}"
        echo "You can set up NGINX later using: ./setup-nginx.sh <domain> <remote-host> <remote-user>"
        return 0
    fi

    echo "NGINX provides HTTPS access to your node's REST API and gRPC endpoints."
    echo ""
    read -p "Do you want to set up NGINX and SSL now? (y/n): " setup_nginx_choice

    if [[ ! $setup_nginx_choice =~ ^[Yy]$ ]]; then
        echo "Skipping NGINX setup. You can set it up later with:"
        echo "  ./setup-nginx.sh <domain> $remote_host $remote_user"
        return 0
    fi

    echo ""
    read -p "Enter your domain name (e.g., api.yourproject.com): " domain_name

    if [ -z "$domain_name" ]; then
        echo -e "${YELLOW}⚠️  No domain provided - skipping NGINX setup${NC}"
        return 0
    fi

    chmod +x ./setup-nginx.sh
    ./setup-nginx.sh "$domain_name" "$remote_host" "$remote_user"
}

# Start node
start_node() {
    local remote_host=$1
    local remote_user=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 9: Starting Node${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Starting pokerchaind service..."
    ssh "$remote_user@$remote_host" "sudo systemctl start pokerchaind"
    
    echo "Waiting for node to start..."
    sleep 5
    
    echo ""
    echo "Service status:"
    ssh "$remote_user@$remote_host" "sudo systemctl status pokerchaind --no-pager -l" || true
    
    echo ""
    echo -e "${GREEN}✅ Node started${NC}"
}

# Verify file hashes
verify_file_hashes() {
    local node_num=$1
    local remote_host=$2
    local remote_user=$3
    local node_dir="$PROD_DIR/node$node_num"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Verifying File Hashes${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local hash_check_failed=false

    # Verify binary hash
    echo "Verifying pokerchaind binary..."
    local local_binary_hash=$(sha256sum build/pokerchaind | awk '{print $1}')
    echo "  Local binary hash:  $local_binary_hash"

    local remote_binary_hash=$(ssh "$remote_user@$remote_host" "sha256sum /usr/local/bin/pokerchaind 2>/dev/null" | awk '{print $1}')
    echo "  Remote binary hash: $remote_binary_hash"

    if [ "$local_binary_hash" = "$remote_binary_hash" ]; then
        echo -e "  ${GREEN}✅ Binary hashes match${NC}"
    else
        echo -e "  ${RED}❌ Binary hashes DO NOT match!${NC}"
        hash_check_failed=true
    fi

    echo ""

    # Verify genesis.json hash
    echo "Verifying genesis.json..."
    if [ -f "$node_dir/config/genesis.json" ]; then
        local local_genesis_hash=$(sha256sum "$node_dir/config/genesis.json" | awk '{print $1}')
        echo "  Local genesis hash:  $local_genesis_hash"

        local remote_genesis_hash=$(ssh "$remote_user@$remote_host" "sha256sum ~/.pokerchain/config/genesis.json 2>/dev/null" | awk '{print $1}')
        echo "  Remote genesis hash: $remote_genesis_hash"

        if [ "$local_genesis_hash" = "$remote_genesis_hash" ]; then
            echo -e "  ${GREEN}✅ Genesis hashes match${NC}"
        else
            echo -e "  ${RED}❌ Genesis hashes DO NOT match!${NC}"
            hash_check_failed=true
        fi
    else
        echo -e "  ${YELLOW}⚠️  Local genesis.json not found - skipping hash verification${NC}"
    fi

    echo ""

    if [ "$hash_check_failed" = true ]; then
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⚠️  HASH VERIFICATION FAILED!                                   ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "One or more files failed hash verification."
        echo "This could indicate:"
        echo "  - File corruption during transfer"
        echo "  - Network issues"
        echo "  - Files were modified after deployment"
        echo ""
        read -p "Continue anyway? (y/n): " continue_choice
        if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
            echo "Deployment aborted due to hash verification failure."
            exit 1
        fi
    else
        echo -e "${GREEN}✅ All file hashes verified successfully${NC}"
    fi
}

# Verify deployment
verify_deployment() {
    local remote_host=$1
    local remote_user=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 10: Verifying Deployment${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Waiting for RPC to become available..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh "$remote_user@$remote_host" "curl -s --max-time 2 http://localhost:26657/status" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ RPC is responding${NC}"
            break
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo ""
        echo -e "${YELLOW}⚠️  RPC not responding yet (this is normal for initial sync)${NC}"
    else
        echo ""
        echo "Node status:"
        ssh "$remote_user@$remote_host" "curl -s http://localhost:26657/status | jq '.result | {moniker: .node_info.moniker, network: .node_info.network, latest_block_height: .sync_info.latest_block_height, catching_up: .sync_info.catching_up}'" 2>/dev/null || \
            ssh "$remote_user@$remote_host" "curl -s http://localhost:26657/status" 2>/dev/null
    fi
}

# Show next steps
show_next_steps() {
    local node_num=$1
    local remote_host=$2
    local remote_user=$3
    local node_dir="$PROD_DIR/node$node_num"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ Deployment Complete!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Node Information:"
    echo "  Remote Host: $remote_host"
    echo "  Remote User: $remote_user"
    echo "  RPC:  http://$remote_host:26657"
    echo "  API:  http://$remote_host:1317"
    echo "  gRPC: $remote_host:9090"
    echo ""
    echo "Useful Commands:"
    echo ""
    echo "Monitor logs:"
    echo "  ssh $remote_user@$remote_host 'journalctl -u pokerchaind -f'"
    echo ""
    echo "Check sync status:"
    echo "  curl http://$remote_host:26657/status | jq .result.sync_info"
    echo ""
    echo "View service status:"
    echo "  ssh $remote_user@$remote_host 'systemctl status pokerchaind'"
    echo ""
    echo "Restart service:"
    echo "  ssh $remote_user@$remote_host 'systemctl restart pokerchaind'"
    echo ""
    
    # Check if this is a validator node
    if [ -f "$node_dir/become-validator.sh" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${YELLOW}📋 Validator Node Detected${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "To make this node a validator:"
        echo "  1. Wait for node to fully sync (catching_up: false)"
        echo "  2. Follow instructions in:"
        echo "     $node_dir/become-validator.sh"
        echo ""
    fi
}

# Main deployment function
main() {
    # Check arguments
    if [ $# -lt 2 ]; then
        print_header
        echo ""
        usage
        exit 1
    fi
    
    local node_num=$1
    local remote_host=$2
    local remote_user=${3:-root}
    
    print_header
    echo ""
    
    # Validate node number
    if ! [[ "$node_num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid node number: $node_num${NC}"
        echo ""
        usage
        exit 1
    fi
    
    # Pre-deployment checks
    echo "Deployment Configuration:"
    echo "  Node Number: $node_num"
    echo "  Remote Host: $remote_host"
    echo "  Remote User: $remote_user"
    echo "  Node Config: $PROD_DIR/node$node_num/"
    echo ""
    
    read -p "Continue with deployment? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    # Run deployment steps
    check_node_dir "$node_num"
    test_ssh "$remote_host" "$remote_user"
    cleanup_old_installation "$remote_host" "$remote_user"
    build_binary
    deploy_binary "$remote_host" "$remote_user"
    deploy_config "$node_num" "$remote_host" "$remote_user"
    configure_bridge "$remote_host" "$remote_user"
    verify_file_hashes "$node_num" "$remote_host" "$remote_user"
    setup_firewall "$remote_host" "$remote_user"
    setup_systemd "$remote_host" "$remote_user"
    setup_nginx "$remote_host" "$remote_user"
    start_node "$remote_host" "$remote_user"
    verify_deployment "$remote_host" "$remote_user"
    show_next_steps "$node_num" "$remote_host" "$remote_user"
}

# Run main
main "$@"