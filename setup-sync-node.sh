#!/bin/bash

# Pokerchain Sync Node Setup Script
# Sets up a local read-only sync node that connects to node1.block52.xyz
# 
# Features:
# - Builds pokerchaind from source using Makefile
# - Fetches genesis and configs from remote node or GitHub repo
# - Sets up sync-only mode (no validator participation)
# - Configures proper peer connections
# - Optionally creates systemd service
# - Verifies node connectivity

set -e

# Configuration
CHAIN_ID="pokerchain"
MONIKER="sync-node"
HOME_DIR="$HOME/.pokerchain"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_NODE="node1.block52.xyz"
GITHUB_RAW_URL="https://raw.githubusercontent.com/block52/pokerchain/main"

# Ports
P2P_PORT=26656
RPC_PORT=26657
API_PORT=1317

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Stop any running pokerchaind processes
stop_pokerchaind() {
    print_info "Checking for running pokerchaind processes..."
    
    # Stop systemd service if it exists
    if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
        if systemctl is-active --quiet pokerchaind 2>/dev/null; then
            print_warning "Stopping pokerchaind service..."
            sudo systemctl stop pokerchaind
            sleep 2
            print_success "Service stopped"
        fi
    fi
    
    # Kill any running processes
    if pgrep -x pokerchaind > /dev/null; then
        print_warning "Stopping pokerchaind processes..."
        pkill -TERM pokerchaind 2>/dev/null || true
        sleep 3
        
        if pgrep -x pokerchaind > /dev/null; then
            pkill -KILL pokerchaind 2>/dev/null || true
            sleep 1
        fi
        print_success "All pokerchaind processes stopped"
    else
        print_success "No pokerchaind processes running"
    fi
}

# Build pokerchaind from source
build_pokerchaind() {
    print_header "Building pokerchaind from source"
    
    # Check if we're in the project directory
    if [ ! -f "Makefile" ]; then
        print_error "Makefile not found. Please run this script from the pokerchain project directory"
        exit 1
    fi
    
    # Check Go installation
    if ! command_exists go; then
        print_error "Go not found. Please install Go 1.24.7+"
        exit 1
    fi
    
    local go_version=$(go version | awk '{print $3}')
    print_info "Go version: $go_version"
    
    # Build using make
    print_info "Running: make install"
    if make install; then
        print_success "pokerchaind built successfully"
        
        # Verify installation
        local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
        if [ -f "$gobin/pokerchaind" ]; then
            print_success "Binary installed: $gobin/pokerchaind"
            local version=$(pokerchaind version 2>/dev/null || echo "unknown")
            print_info "Version: $version"
        else
            print_error "Build succeeded but binary not found"
            exit 1
        fi
    else
        print_error "Failed to build pokerchaind"
        exit 1
    fi
}

# Fetch genesis from remote node or GitHub
fetch_genesis() {
    print_header "Fetching genesis.json"
    
    local genesis_file="genesis.json"
    
    # Try local file first
    if [ -f "$PROJECT_DIR/$genesis_file" ]; then
        print_info "Using local genesis.json from project directory"
        cp "$PROJECT_DIR/$genesis_file" "/tmp/genesis.json"
        print_success "Local genesis.json found"
        return 0
    fi
    
    # Try to fetch from remote node
    print_info "Attempting to fetch from remote node: $REMOTE_NODE"
    if curl -s --max-time 10 "http://$REMOTE_NODE:$RPC_PORT/genesis" | jq '.result.genesis' > /tmp/genesis.json 2>/dev/null; then
        if [ -s /tmp/genesis.json ]; then
            print_success "Fetched genesis from remote node"
            return 0
        fi
    fi
    
    # Try to fetch from GitHub
    print_info "Attempting to fetch from GitHub repository"
    if curl -s --max-time 10 "$GITHUB_RAW_URL/genesis.json" -o /tmp/genesis.json; then
        if [ -s /tmp/genesis.json ]; then
            print_success "Fetched genesis from GitHub"
            return 0
        fi
    fi
    
    print_error "Failed to fetch genesis.json from all sources"
    echo "Please ensure:"
    echo "  1. genesis.json exists in project directory, OR"
    echo "  2. $REMOTE_NODE is accessible, OR"
    echo "  3. GitHub repository is public and contains genesis.json"
    exit 1
}

# Fetch config files from remote node or local
fetch_configs() {
    print_header "Fetching configuration files"
    
    # Fetch app.toml
    if [ -f "$PROJECT_DIR/app.toml" ]; then
        print_info "Using local app.toml"
        cp "$PROJECT_DIR/app.toml" "/tmp/app.toml"
        print_success "Local app.toml found"
    else
        print_warning "app.toml not found locally - will use default after init"
    fi
    
    # Fetch or create config.toml with peer information
    if [ -f "$PROJECT_DIR/config.toml" ]; then
        print_info "Using local config.toml"
        cp "$PROJECT_DIR/config.toml" "/tmp/config.toml"
        print_success "Local config.toml found"
    else
        print_warning "config.toml not found - will create after init with peer configuration"
    fi
}

# Get remote node info for peering
get_remote_node_info() {
    print_header "Getting remote node information"
    
    print_info "Querying $REMOTE_NODE for node info..."
    
    # Try to get node ID
    if command_exists curl && command_exists jq; then
        local node_info=$(curl -s --max-time 10 "http://$REMOTE_NODE:$RPC_PORT/status")
        
        if [ -n "$node_info" ]; then
            local node_id=$(echo "$node_info" | jq -r '.result.node_info.id' 2>/dev/null)
            local network=$(echo "$node_info" | jq -r '.result.node_info.network' 2>/dev/null)
            
            if [ -n "$node_id" ] && [ "$node_id" != "null" ]; then
                print_success "Remote node ID: $node_id"
                print_success "Network: $network"
                echo "$node_id@$REMOTE_NODE:$P2P_PORT"
                return 0
            fi
        fi
    fi
    
    print_warning "Could not automatically fetch node ID"
    print_info "You may need to manually configure persistent_peers in config.toml"
    return 1
}

# Initialize sync node
initialize_node() {
    print_header "Initializing sync node"
    
    # Check if already initialized
    if [ -d "$HOME_DIR" ]; then
        print_warning "$HOME_DIR already exists"
        read -p "Remove existing data and reinitialize? (y/n): " REINIT
        
        if [[ $REINIT =~ ^[Yy]$ ]]; then
            print_info "Creating backup..."
            local backup_dir="$HOME_DIR.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$HOME_DIR" "$backup_dir"
            print_success "Backup created: $backup_dir"
        else
            print_info "Keeping existing installation"
            return 0
        fi
    fi
    
    # Initialize new node
    print_info "Initializing node with chain-id: $CHAIN_ID"
    pokerchaind init "$MONIKER" --chain-id "$CHAIN_ID"
    print_success "Node initialized"
    
    # Create necessary directories
    mkdir -p "$HOME_DIR/config"
    mkdir -p "$HOME_DIR/data"
}

# Configure sync node
configure_sync_node() {
    print_header "Configuring sync node"
    
    # Copy genesis
    print_info "Installing genesis.json..."
    cp /tmp/genesis.json "$HOME_DIR/config/genesis.json"
    print_success "Genesis installed"
    
    # Copy app.toml if available
    if [ -f "/tmp/app.toml" ]; then
        print_info "Installing app.toml..."
        cp /tmp/app.toml "$HOME_DIR/config/app.toml"
        print_success "app.toml installed"
    else
        print_warning "Using default app.toml - you may need to configure API settings"
    fi
    
    # Configure config.toml for sync node
    print_info "Configuring config.toml for sync node..."
    
    # Get persistent peers
    local peer_info=$(get_remote_node_info)
    
    if [ -f "/tmp/config.toml" ]; then
        cp /tmp/config.toml "$HOME_DIR/config/config.toml"
        print_success "config.toml installed from local copy"
    else
        # Update the default config.toml with peer info
        if [ -n "$peer_info" ]; then
            sed -i.bak "s/^persistent_peers = .*/persistent_peers = \"$peer_info\"/" "$HOME_DIR/config/config.toml"
            print_success "Configured persistent_peers: $peer_info"
        fi
        
        # Enable p2p settings for better syncing
        sed -i.bak 's/^pex = .*/pex = true/' "$HOME_DIR/config/config.toml"
        sed -i.bak 's/^addr_book_strict = .*/addr_book_strict = false/' "$HOME_DIR/config/config.toml"
        print_success "Configured P2P settings"
    fi
    
    # Remove any validator keys to ensure sync-only mode
    print_info "Configuring sync-only mode (no validator participation)..."
    rm -f "$HOME_DIR/config/priv_validator_key.json"
    
    # Create minimal validator state file
    echo '{"height":"0","round":0,"step":0}' > "$HOME_DIR/data/priv_validator_state.json"
    
    print_success "Sync-only mode configured"
}

# Set file permissions
set_permissions() {
    print_header "Setting secure file permissions"
    
    chmod 755 "$HOME_DIR/config"
    chmod 755 "$HOME_DIR/data"
    chmod 644 "$HOME_DIR/config/genesis.json"
    chmod 600 "$HOME_DIR/config/config.toml"
    chmod 600 "$HOME_DIR/config/app.toml" 2>/dev/null || true
    chmod 600 "$HOME_DIR/data/priv_validator_state.json"
    chmod 700 "$HOME_DIR/data"
    
    print_success "File permissions set"
}

# Create systemd service
create_systemd_service() {
    print_header "Creating systemd service"
    
    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    
    sudo tee /etc/systemd/system/pokerchaind.service > /dev/null <<EOF
[Unit]
Description=Pokerchain Sync Node
After=network-online.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$gobin/pokerchaind start --minimum-gas-prices="0.01stake"
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=pokerchaind"
Environment="DAEMON_HOME=$HOME_DIR"
Environment="PATH=$gobin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    print_success "Systemd service created"
}

# Verify setup
verify_setup() {
    print_header "Verifying setup"
    
    # Check pokerchaind
    if command_exists pokerchaind; then
        print_success "pokerchaind: $(which pokerchaind)"
    else
        print_error "pokerchaind not found"
    fi
    
    # Check config files
    if [ -f "$HOME_DIR/config/genesis.json" ]; then
        print_success "genesis.json: present"
    else
        print_error "genesis.json: missing"
    fi
    
    if [ -f "$HOME_DIR/config/config.toml" ]; then
        print_success "config.toml: present"
    else
        print_error "config.toml: missing"
    fi
    
    if [ -f "$HOME_DIR/config/app.toml" ]; then
        print_success "app.toml: present"
    else
        print_warning "app.toml: using defaults"
    fi
    
    # Check permissions
    local genesis_perms=$(stat -c "%a" "$HOME_DIR/config/genesis.json" 2>/dev/null || stat -f "%A" "$HOME_DIR/config/genesis.json" 2>/dev/null)
    if [ "$genesis_perms" = "644" ]; then
        print_success "Permissions: correct"
    else
        print_warning "Permissions: may need adjustment"
    fi
}

# Test connectivity to remote node
test_connectivity() {
    print_header "Testing connectivity to remote node"
    
    print_info "Testing RPC endpoint: http://$REMOTE_NODE:$RPC_PORT"
    if curl -s --max-time 5 "http://$REMOTE_NODE:$RPC_PORT/status" > /dev/null; then
        print_success "RPC endpoint accessible"
        
        # Get current block height
        local height=$(curl -s "http://$REMOTE_NODE:$RPC_PORT/status" | jq -r '.result.sync_info.latest_block_height' 2>/dev/null)
        if [ -n "$height" ] && [ "$height" != "null" ]; then
            print_info "Current block height: $height"
        fi
    else
        print_warning "RPC endpoint not accessible"
        print_info "The node may still sync via P2P"
    fi
}

# Main setup flow
main() {
    print_header "Pokerchain Sync Node Setup"
    echo ""
    echo "This script will set up a local sync-only node that connects to:"
    echo "  Remote node: $REMOTE_NODE"
    echo "  Chain ID: $CHAIN_ID"
    echo ""
    echo "The sync node will:"
    echo "  ✓ Sync blockchain data from the network"
    echo "  ✓ Provide local RPC/API access"
    echo "  ✓ NOT participate in consensus (read-only)"
    echo ""
    read -p "Continue with setup? (y/n): " CONTINUE
    
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Check if we're in the project directory
    cd "$PROJECT_DIR"
    
    # Step 1: Stop any running nodes
    stop_pokerchaind
    
    # Step 2: Build pokerchaind
    read -p "Build pokerchaind from source? (y/n): " BUILD
    if [[ $BUILD =~ ^[Yy]$ ]]; then
        build_pokerchaind
    else
        # Verify pokerchaind exists
        if ! command_exists pokerchaind; then
            print_error "pokerchaind not found. Please build it or install it first."
            exit 1
        fi
        print_success "Using existing pokerchaind: $(which pokerchaind)"
    fi
    
    # Step 3: Fetch genesis and configs
    fetch_genesis
    fetch_configs
    
    # Step 4: Initialize node
    initialize_node
    
    # Step 5: Configure sync node
    configure_sync_node
    
    # Step 6: Set permissions
    set_permissions
    
    # Step 7: Create systemd service (optional)
    read -p "Create systemd service for automatic startup? (y/n): " CREATE_SERVICE
    if [[ $CREATE_SERVICE =~ ^[Yy]$ ]]; then
        create_systemd_service
    fi
    
    # Step 8: Verify setup
    verify_setup
    
    # Step 9: Test connectivity
    test_connectivity
    
    # Final summary
    print_header "Setup Complete!"
    echo ""
    echo "📋 Sync Node Configuration:"
    echo "   Home: $HOME_DIR"
    echo "   Chain ID: $CHAIN_ID"
    echo "   Remote Node: $REMOTE_NODE"
    echo ""
    echo "🚀 Start the sync node:"
    if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
        echo "   sudo systemctl enable pokerchaind"
        echo "   sudo systemctl start pokerchaind"
        echo "   journalctl -u pokerchaind -f"
    else
        echo "   pokerchaind start --minimum-gas-prices=\"0.01stake\""
    fi
    echo ""
    echo "📊 Monitor sync progress:"
    echo "   curl http://localhost:$RPC_PORT/status | jq '.result.sync_info'"
    echo ""
    echo "🔍 Check local endpoints:"
    echo "   RPC:  http://localhost:$RPC_PORT"
    echo "   API:  http://localhost:$API_PORT"
    echo ""
    echo "💡 The node will sync from the network and provide local access"
    echo "   to blockchain data without participating in consensus."
    echo ""
    
    # Ask if user wants to start now
    if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
        read -p "Start the sync node now? (y/n): " START_NOW
        if [[ $START_NOW =~ ^[Yy]$ ]]; then
            print_info "Starting pokerchaind service..."
            sudo systemctl enable pokerchaind
            sudo systemctl start pokerchaind
            sleep 3
            
            if systemctl is-active --quiet pokerchaind; then
                print_success "Sync node is running!"
                echo ""
                echo "View logs: journalctl -u pokerchaind -f"
            else
                print_error "Failed to start service"
                echo "Check logs: journalctl -u pokerchaind -n 50"
            fi
        fi
    fi
}

# Run main function
main