#!/bin/bash

# Local Developer Node Setup Script
# Sets up and runs a local read-only node for development
# Syncs from production network

set -e

# Configuration
CHAIN_BINARY="pokerchaind"
CHAIN_ID="pokerchain"
NODE_HOME="${HOME}/.pokerchain-dev"
MONIKER="dev-node-$(hostname)"
SYNC_NODE="node1.block52.xyz"
SYNC_NODE_RPC="http://node1.block52.xyz:26657"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║           🎲 Pokerchain Developer Node Setup 🎲                   ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if binary exists
check_binary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Checking Binary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check for binary in build directory
    if [ -f "build/pokerchaind" ]; then
        CHAIN_BINARY="./build/pokerchaind"
        echo -e "${GREEN}✓${NC} Found binary: $CHAIN_BINARY"
        $CHAIN_BINARY version 2>/dev/null || echo "Version: unknown"
        # Compare hash to remote binary
        LOCAL_HASH=$(sha256sum build/pokerchaind | awk '{print $1}')
        REMOTE_HASH=$(ssh root@node1.block52.xyz 'sha256sum /usr/local/bin/pokerchaind' | awk '{print $1}')
        echo "Local binary hash:  $LOCAL_HASH"
        echo "Remote binary hash: $REMOTE_HASH"
        if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            echo -e "${YELLOW}⚠ Binary hash does not match remote node1.block52.xyz!${NC}"
            read -p "Download remote binary and overwrite local build/pokerchaind? (y/n): " DOWNLOAD_REMOTE
            if [[ $DOWNLOAD_REMOTE =~ ^[Yy]$ ]]; then
                scp root@node1.block52.xyz:/usr/local/bin/pokerchaind ./build/pokerchaind
                echo -e "${GREEN}✓${NC} Downloaded remote binary to ./build/pokerchaind"
            else
                echo "Keeping local binary."
            fi
        fi
        return 0
    fi
    
    # Check if in PATH
    if command -v pokerchaind &> /dev/null; then
        CHAIN_BINARY="pokerchaind"
        echo -e "${GREEN}✓${NC} Found binary in PATH: $(which pokerchaind)"
        $CHAIN_BINARY version 2>/dev/null || echo "Version: unknown"
        return 0
    fi
    
    # Binary not found - offer to build
    echo -e "${YELLOW}⚠ Binary not found${NC}"
    echo ""
    echo "The pokerchaind binary was not found."
    echo ""
    read -p "Build now? (y/n): " BUILD_NOW
    
    if [[ $BUILD_NOW =~ ^[Yy]$ ]]; then
        build_binary
    else
        echo ""
        echo "Please build the binary first:"
        echo "  make build"
        echo ""
        exit 1
    fi
}

# Build binary
build_binary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Building Binary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if ! command -v make &> /dev/null; then
        echo -e "${RED}❌ make not found${NC}"
        exit 1
    fi
    
    echo "Building pokerchaind..."
    if make build; then
        CHAIN_BINARY="./build/pokerchaind"
        echo -e "${GREEN}✓${NC} Build successful: $CHAIN_BINARY"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
}

# Get genesis from sync node
get_genesis() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Downloading Genesis${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "Downloading genesis from $SYNC_NODE_RPC..."
    
    if command -v curl &> /dev/null; then
        if curl -s "$SYNC_NODE_RPC/genesis" | jq -r .result.genesis > "$NODE_HOME/config/genesis.json"; then
            echo -e "${GREEN}✓${NC} Genesis downloaded successfully"
        else
            echo -e "${RED}❌ Failed to download genesis${NC}"
            echo ""
            echo "Please ensure $SYNC_NODE is accessible:"
            echo "  curl $SYNC_NODE_RPC/status"
            exit 1
        fi
    else
        echo -e "${RED}❌ curl not found${NC}"
        echo "Please install curl and try again"
        exit 1
    fi
}

# Get node ID from sync node
get_sync_node_id() {
    # If called with an argument, print status messages
    if [ "$1" = "interactive" ]; then
        echo "Getting node ID from $SYNC_NODE..."
    fi
    if command -v curl &> /dev/null; then
        local node_id=$(curl -s "$SYNC_NODE_RPC/status" | jq -r .result.node_info.id 2>/dev/null)
        if [ -n "$node_id" ] && [ "$node_id" != "null" ]; then
            if [ "$1" = "interactive" ]; then
                echo -e "${GREEN}✓${NC} Node ID: $node_id"
            fi
            echo "$node_id"
        else
            if [ "$1" = "interactive" ]; then
                echo -e "${YELLOW}⚠ Could not get node ID automatically${NC}"
                echo ""
                echo "You may need to manually configure persistent_peers in:"
                echo "  $NODE_HOME/config/config.toml"
                echo ""
            fi
            echo "null"
        fi
    else
        echo "null"
    fi
}

# Initialize node
initialize_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Initializing Developer Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -d "$NODE_HOME" ]; then
        echo -e "${YELLOW}⚠ Node directory already exists: $NODE_HOME${NC}"
        echo ""
        echo "Options:"
        echo "  1) Keep existing data and configuration"
        echo "  2) Reset and start fresh (delete all data)"
        echo "  3) Cancel"
        echo ""
        read -p "Choose option [1-3]: " INIT_OPTION
        
        case $INIT_OPTION in
            1)
                echo -e "${GREEN}✓${NC} Using existing node data"
                return 0
                ;;
            2)
                echo -e "${YELLOW}Removing existing node data...${NC}"
                rm -rf "$NODE_HOME"
                ;;
            *)
                echo "Cancelled"
                exit 0
                ;;
        esac
    fi
    
    echo "Initializing new node..."
    echo "  Home: $NODE_HOME"
    echo "  Moniker: $MONIKER"
    echo "  Chain ID: $CHAIN_ID"
    echo ""
    
    $CHAIN_BINARY init "$MONIKER" --chain-id "$CHAIN_ID" --home "$NODE_HOME"
    
    echo -e "${GREEN}✓${NC} Node initialized"
}

# Configure node
configure_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Configuring Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Copy local config.toml and app.toml to dev node config directory
    cp ./config.toml "$NODE_HOME/config/config.toml"
    cp ./app.toml "$NODE_HOME/config/app.toml"
    
    # Now set the required values as before
    # Get sync node ID
    local sync_node_id=$(get_sync_node_id)
    if [ "$sync_node_id" != "null" ]; then
        local persistent_peer="${sync_node_id}@${SYNC_NODE}:26656"
        echo "Setting persistent peer: $persistent_peer"
        persistent_peer_clean=$(echo "$persistent_peer" | tr -d '\n' | tr -cd '\11\12\15\40-\176')
        config_file="$NODE_HOME/config/config.toml"
        if grep -q '^persistent_peers' "$config_file"; then
            awk -v val="persistent_peers = \"$persistent_peer_clean\"" 'BEGIN{done=0} /^persistent_peers[[:space:]]*=/{if(!done){print val; done=1; next}} {print}' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        else
            echo "persistent_peers = \"$persistent_peer_clean\"" >> "$config_file"
        fi
    fi
    
    echo "Configuring developer settings..."
    
    # Enable API for development
    sed -i.bak 's|enable = false|enable = true|g' "$NODE_HOME/config/app.toml"
    sed -i.bak 's|address = "tcp://localhost:1317"|address = "tcp://127.0.0.1:1317"|g' "$NODE_HOME/config/app.toml"
    
    # Enable Swagger for API documentation
    sed -i.bak 's|swagger = false|swagger = true|g' "$NODE_HOME/config/app.toml"
    
    # Set minimum gas prices
    if grep -q 'minimum-gas-prices = ""' "$NODE_HOME/config/app.toml"; then
        sed -i.bak 's|minimum-gas-prices = ""|minimum-gas-prices = "0.001stake"|g' "$NODE_HOME/config/app.toml"
    elif grep -q "minimum-gas-prices = ''" "$NODE_HOME/config/app.toml"; then
        sed -i.bak "s|minimum-gas-prices = ''|minimum-gas-prices = \"0.001stake\"|g" "$NODE_HOME/config/app.toml"
    fi
    
    # Development-friendly settings
    sed -i.bak 's|addr_book_strict = true|addr_book_strict = false|g' "$NODE_HOME/config/config.toml"
    
    # Clean up backup files
    rm -f "$NODE_HOME/config/config.toml.bak" "$NODE_HOME/config/app.toml.bak"
    
    echo -e "${GREEN}✓${NC} Node configured for development"
    echo ""
    echo "Configuration:"
    echo "  Sync Node: $SYNC_NODE"
    echo "  RPC: http://127.0.0.1:26657"
    echo "  API: http://127.0.0.1:1317"
    echo "  gRPC: 127.0.0.1:9090"
}

# Show pre-start info
show_pre_start_info() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Ready to Start${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Your developer node is configured and ready!${NC}"
    echo ""
    echo "Node Information:"
    echo "  Type: Read-only (non-validator)"
    echo "  Home: $NODE_HOME"
    echo "  Moniker: $MONIKER"
    echo "  Syncing from: $SYNC_NODE"
    echo ""
    echo "Endpoints:"
    echo "  RPC:  http://127.0.0.1:26657"
    echo "  API:  http://127.0.0.1:1317"
    echo "  gRPC: 127.0.0.1:9090"
    echo ""
    echo "Useful Commands (in another terminal):"
    echo "  # Check status"
    echo "  $CHAIN_BINARY status --home $NODE_HOME"
    echo ""
    echo "  # Check sync status"
    echo "  curl http://127.0.0.1:26657/status | jq .result.sync_info"
    echo ""
    echo "  # Query account"
    echo "  $CHAIN_BINARY query bank balances <address> --home $NODE_HOME"
    echo ""
    echo "  # View logs"
    echo "  tail -f $NODE_HOME/pokerchaind.log"
    echo ""
    echo -e "${YELLOW}Note: Initial sync may take some time. Watch for 'catching_up: false'${NC}"
    echo ""
}

# Start node
start_node() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Starting pokerchaind...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Start the node
    $CHAIN_BINARY start --home "$NODE_HOME" --minimum-gas-prices="0.001stake"
}

# Cleanup on exit
cleanup() {
    echo ""
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Node Stopped${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Developer node has been stopped."
    echo ""
    echo "To start again, run:"
    echo "  ./run-dev-node.sh"
    echo ""
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --reset             Reset node data and start fresh"
    echo "  --sync-node <url>   Specify sync node (default: node1.block52.xyz)"
    echo "  --home <path>       Specify custom home directory"
    echo "  --moniker <name>    Specify custom moniker"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Start with defaults"
    echo "  $0 --reset                            # Reset and start fresh"
    echo "  $0 --sync-node node2.example.com      # Use different sync node"
    echo "  $0 --home ~/.my-dev-node              # Use custom home directory"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --reset)
                if [ -d "$NODE_HOME" ]; then
                    echo "Removing existing node data: $NODE_HOME"
                    rm -rf "$NODE_HOME"
                fi
                shift
                ;;
            --sync-node)
                SYNC_NODE="$2"
                SYNC_NODE_RPC="http://$2:26657"
                shift 2
                ;;
            --home)
                NODE_HOME="$2"
                shift 2
                ;;
            --moniker)
                MONIKER="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse arguments
    parse_args "$@"
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    # Print header
    print_header
    
    # Check/build binary
    check_binary
    
    # Initialize node
    initialize_node
    
    # Download genesis
    get_genesis
    
    # Configure node
    configure_node
    
    # Show info
    show_pre_start_info
    
    # Wait a moment
    sleep 2
    
    # Start node
    start_node
}

# Run main
main "$@"