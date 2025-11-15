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
REBUILD=false
RUN_PVM=false
PVM_TEMP_DIR="/tmp/poker-vm-dev"

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

# Build binary for the current system architecture
# The Makefile automatically detects the OS (darwin/linux/windows) and architecture (arm64/amd64)
# and builds the correct binary via: GOOS=$(uname -s | tr '[:upper:]' '[:lower:]') GOARCH=$(...)
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

    local OS=$(uname -s)
    local ARCH=$(uname -m)
    echo "Building pokerchaind for $OS $ARCH..."
    echo ""

    # The 'make build' command automatically builds for the current system
    # It detects: macOS (darwin) vs Linux, and ARM64 vs x86_64
    if make build; then
        CHAIN_BINARY="./build/pokerchaind"
        echo ""
        echo -e "${GREEN}✓${NC} Build successful: $CHAIN_BINARY"

        # Show binary info
        if command -v file &> /dev/null; then
            echo -e "${GREEN}✓${NC} Binary info: $(file $CHAIN_BINARY)"
        fi
        
        # Show version
        local version=$($CHAIN_BINARY version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} Version: $version"
    else
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
}

# Check if binary exists and matches system architecture
check_binary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Checking Binary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # If --rebuild flag is set, rebuild immediately
    if [ "$REBUILD" = true ]; then
        echo -e "${YELLOW}Rebuild requested...${NC}"
        build_binary
        return 0
    fi

    # Detect system architecture
    # macOS: uname -s returns "Darwin", uname -m returns "arm64" or "x86_64"
    # Linux: uname -s returns "Linux", uname -m returns "aarch64", "x86_64", etc.
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)
    
    # Normalize architecture names
    case $ARCH in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
    esac
    
    echo "Local system: $OS/$ARCH"
    
    # Get remote system info
    echo "Checking remote node architecture..."
    local REMOTE_ARCH=$(ssh root@node1.block52.xyz 'uname -m' 2>/dev/null || echo "unknown")
    local REMOTE_OS=$(ssh root@node1.block52.xyz 'uname -s | tr "[:upper:]" "[:lower:]"' 2>/dev/null || echo "unknown")
    
    # Normalize remote architecture
    case $REMOTE_ARCH in
        x86_64|amd64)
            REMOTE_ARCH="amd64"
            ;;
        aarch64|arm64)
            REMOTE_ARCH="arm64"
            ;;
    esac
    
    if [ "$REMOTE_OS" != "unknown" ]; then
        echo "Remote system: $REMOTE_OS/$REMOTE_ARCH"
    else
        echo -e "${YELLOW}⚠ Could not detect remote system (continuing anyway)${NC}"
    fi
    
    # Check if architectures match
    local ARCH_MATCH=false
    if [ "$OS" = "$REMOTE_OS" ] && [ "$ARCH" = "$REMOTE_ARCH" ]; then
        ARCH_MATCH=true
        echo -e "${GREEN}✓${NC} Local and remote architectures match!"
    elif [ "$REMOTE_OS" != "unknown" ]; then
        echo -e "${YELLOW}⚠ Architecture mismatch detected!${NC}"
        echo "  Local:  $OS/$ARCH"
        echo "  Remote: $REMOTE_OS/$REMOTE_ARCH"
        echo ""
        echo -e "${YELLOW}  Remote binary will NOT work on your system${NC}"
    fi
    echo ""

    # Check for binary in build directory
    if [ -f "build/pokerchaind" ]; then
        CHAIN_BINARY="./build/pokerchaind"
        echo -e "${GREEN}✓${NC} Found binary: $CHAIN_BINARY"
        
        # Show binary info
        local version=$($CHAIN_BINARY version 2>/dev/null || echo "unknown")
        echo "  Version: $version"
        
        if command -v file &> /dev/null; then
            local file_info=$(file $CHAIN_BINARY)
            echo "  Type: $file_info"
        fi
        
        # Compare hash to remote binary if architectures match
        if [ "$ARCH_MATCH" = true ]; then
            echo ""
            echo "Comparing with remote binary..."
            LOCAL_HASH=$(shasum -a 256 build/pokerchaind 2>/dev/null | awk '{print $1}' || sha256sum build/pokerchaind 2>/dev/null | awk '{print $1}')
            REMOTE_HASH=$(ssh root@node1.block52.xyz 'sha256sum /usr/local/bin/pokerchaind' 2>/dev/null | awk '{print $1}')
            
            echo "  Local:  $LOCAL_HASH"
            echo "  Remote: $REMOTE_HASH"
            
            if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
                echo ""
                echo -e "${YELLOW}⚠ Binary hashes don't match!${NC}"
                echo ""
                echo "Options:"
                echo "  1) Download remote binary (recommended - ensures compatibility)"
                echo "  2) Keep local binary (may cause sync issues if different version)"
                echo "  3) Build new binary locally"
                echo "  4) Cancel"
                echo ""
                read -p "Choose option [1-4]: " BINARY_CHOICE
                
                case $BINARY_CHOICE in
                    1)
                        echo ""
                        echo "Downloading remote binary..."
                        mkdir -p build
                        scp root@node1.block52.xyz:/usr/local/bin/pokerchaind ./build/pokerchaind
                        chmod +x ./build/pokerchaind
                        echo -e "${GREEN}✓${NC} Downloaded remote binary to ./build/pokerchaind"
                        ;;
                    2)
                        echo ""
                        echo -e "${YELLOW}Keeping local binary (this may cause AppHash mismatches)${NC}"
                        ;;
                    3)
                        build_binary
                        ;;
                    4)
                        echo "Cancelled"
                        exit 0
                        ;;
                    *)
                        echo "Invalid choice. Keeping local binary."
                        ;;
                esac
            else
                echo -e "${GREEN}✓${NC} Hashes match - binary is up to date!"
                echo ""
                echo "Options:"
                echo "  1) Use existing binary (recommended - already up to date)"
                echo "  2) Rebuild anyway"
                echo "  3) Cancel"
                echo ""
                read -p "Choose option [1-3, default: 1]: " MATCH_BINARY_CHOICE
                MATCH_BINARY_CHOICE=${MATCH_BINARY_CHOICE:-1}
                
                case $MATCH_BINARY_CHOICE in
                    1)
                        echo -e "${GREEN}✓${NC} Using existing binary"
                        ;;
                    2)
                        build_binary
                        ;;
                    3)
                        echo "Cancelled"
                        exit 0
                        ;;
                    *)
                        echo "Invalid choice. Using existing binary."
                        ;;
                esac
            fi
        else
            # Architecture mismatch - only offer to use local or rebuild
            echo ""
            echo -e "${YELLOW}⚠ Cannot compare with remote (architecture mismatch)${NC}"
            echo ""
            echo "Options:"
            echo "  1) Use existing local binary (built for $OS/$ARCH)"
            echo "  2) Rebuild for your system ($OS/$ARCH)"
            echo "  3) Cancel"
            echo ""
            read -p "Choose option [1-3]: " LOCAL_BINARY_CHOICE
            
            case $LOCAL_BINARY_CHOICE in
                1)
                    echo ""
                    echo -e "${GREEN}✓${NC} Using existing binary: $CHAIN_BINARY"
                    ;;
                2)
                    build_binary
                    ;;
                3)
                    echo "Cancelled"
                    exit 0
                    ;;
                *)
                    echo "Invalid choice. Using existing binary."
                    ;;
            esac
        fi
        
        return 0
    fi

    # Check if in PATH
    if command -v pokerchaind &> /dev/null; then
        CHAIN_BINARY="pokerchaind"
        echo -e "${GREEN}✓${NC} Found binary in PATH: $(which pokerchaind)"
        $CHAIN_BINARY version 2>/dev/null || echo "Version: unknown"
        echo ""
        echo -e "${YELLOW}Note: Using system binary. For best results, use ./build/pokerchaind${NC}"
        echo ""
        echo "Options:"
        echo "  1) Use system binary"
        echo "  2) Build local binary for your system ($OS/$ARCH)"
        echo "  3) Cancel"
        echo ""
        read -p "Choose option [1-3]: " PATH_BINARY_CHOICE
        
        case $PATH_BINARY_CHOICE in
            1)
                echo -e "${GREEN}✓${NC} Using system binary"
                return 0
                ;;
            2)
                build_binary
                return 0
                ;;
            3)
                echo "Cancelled"
                exit 0
                ;;
            *)
                echo "Using system binary"
                return 0
                ;;
        esac
    fi

    # Binary not found - offer options
    echo -e "${YELLOW}⚠ No pokerchaind binary found${NC}"
    echo ""
    echo "Options:"
    echo "  1) Download from remote node (only works if architectures match)"
    echo "  2) Build locally for your system ($OS/$ARCH)"
    echo "  3) Cancel"
    echo ""
    read -p "Choose option [1-3]: " BINARY_OPTION

    case $BINARY_OPTION in
        1)
            if [ "$ARCH_MATCH" = false ] && [ "$REMOTE_OS" != "unknown" ]; then
                echo ""
                echo -e "${RED}❌ Cannot download: Architecture mismatch!${NC}"
                echo "  Your system: $OS/$ARCH"
                echo "  Remote:      $REMOTE_OS/$REMOTE_ARCH"
                echo ""
                echo "You must build locally. Try option 2."
                sleep 3
                check_binary  # Recurse to show menu again
                return
            fi
            
            echo ""
            echo "Downloading binary from remote node..."
            mkdir -p build
            scp root@node1.block52.xyz:/usr/local/bin/pokerchaind ./build/pokerchaind || {
                echo -e "${RED}❌ Download failed${NC}"
                exit 1
            }
            chmod +x ./build/pokerchaind
            CHAIN_BINARY="./build/pokerchaind"
            echo -e "${GREEN}✓${NC} Downloaded binary successfully"
            ;;
        2)
            build_binary
            ;;
        3)
            echo "Cancelled"
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
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
    if [ -f "./config.toml" ]; then
        cp ./config.toml "$NODE_HOME/config/config.toml"
        echo -e "${GREEN}✓${NC} Copied config.toml"
    fi
    
    if [ -f "./app.toml" ]; then
        cp ./app.toml "$NODE_HOME/config/app.toml"
        echo -e "${GREEN}✓${NC} Copied app.toml"
    fi
    
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
        sed -i.bak 's|minimum-gas-prices = ""|minimum-gas-prices = "0.001b52usdc"|g' "$NODE_HOME/config/app.toml"
    elif grep -q "minimum-gas-prices = ''" "$NODE_HOME/config/app.toml"; then
        sed -i.bak "s|minimum-gas-prices = ''|minimum-gas-prices = \"0.001b52usdc\"|g" "$NODE_HOME/config/app.toml"
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
    
    if [ "$RUN_PVM" = true ]; then
        echo ""
        echo "PVM Endpoints:"
        echo "  RPC:  http://localhost:8545"
        echo "  Health: http://localhost:8545/health"
    fi
    
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
    
    if [ "$RUN_PVM" = true ]; then
        echo ""
        echo "  # View PVM logs"
        echo "  docker compose -f $PVM_TEMP_DIR/docker-compose.yaml logs -f pvm"
    fi
    
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
    $CHAIN_BINARY start --home "$NODE_HOME" --minimum-gas-prices="0.001b52usdc"
}

# Check if user wants to run PVM
prompt_pvm() {
    echo ""
    echo -e "${YELLOW}Execution Layer (PVM) Setup${NC}"
    echo ""
    echo "Do you want to run the PVM (Poker Virtual Machine) execution layer?"
    echo ""
    echo "  1) Chain only (default)"
    echo "  2) Chain + PVM Execution Layer (requires Docker)"
    echo "  3) Cancel and exit"
    echo ""
    read -p "Choose option [1-3, default: 1]: " PVM_CHOICE
    PVM_CHOICE=${PVM_CHOICE:-1}
    
    if [ "$PVM_CHOICE" = "2" ]; then
        RUN_PVM=true
        echo ""
        echo -e "${GREEN}✓${NC} Will run chain + PVM"
    elif [ "$PVM_CHOICE" = "3" ]; then
        echo ""
        echo "Setup cancelled."
        exit 0
    else
        echo ""
        echo -e "${GREEN}✓${NC} Will run chain only"
    fi
}

# Setup PVM Docker files
setup_pvm() {
    if [ "$RUN_PVM" != true ]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up PVM${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found${NC}"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose not found${NC}"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Docker and Docker Compose are available"
    echo ""
    
    # Create temporary directory
    echo "Creating temporary directory: $PVM_TEMP_DIR"
    mkdir -p "$PVM_TEMP_DIR"
    
    # Download docker-compose.yaml
    echo "Downloading docker-compose.yaml..."
    if curl -fsSL https://raw.githubusercontent.com/block52/poker-vm/main/docker-compose.yaml \
        -o "$PVM_TEMP_DIR/docker-compose.yaml"; then
        echo -e "${GREEN}✓${NC} Downloaded docker-compose.yaml"
    else
        echo -e "${RED}❌ Failed to download docker-compose.yaml${NC}"
        exit 1
    fi
    
    # Create pvm/ts directory structure
    mkdir -p "$PVM_TEMP_DIR/pvm/ts"
    
    # Download Dockerfile
    echo "Downloading Dockerfile..."
    if curl -fsSL https://raw.githubusercontent.com/block52/poker-vm/main/pvm/ts/Dockerfile \
        -o "$PVM_TEMP_DIR/pvm/ts/Dockerfile"; then
        echo -e "${GREEN}✓${NC} Downloaded Dockerfile"
    else
        echo -e "${RED}❌ Failed to download Dockerfile${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Note: To build the PVM images, you'll need the full poker-vm repository.${NC}"
    echo -e "${YELLOW}The Docker files have been downloaded to: $PVM_TEMP_DIR${NC}"
    echo ""
    echo "Do you want to clone the full poker-vm repository now?"
    echo "  1) Yes, clone the repository (recommended for building)"
    echo "  2) No, I'll handle it manually"
    echo ""
    read -p "Choose option [1-2]: " CLONE_CHOICE
    
    if [ "$CLONE_CHOICE" = "1" ]; then
        echo ""
        echo "Cloning poker-vm repository..."
        if git clone https://github.com/block52/poker-vm.git "$PVM_TEMP_DIR/poker-vm" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Repository cloned successfully"
            PVM_TEMP_DIR="$PVM_TEMP_DIR/poker-vm"
        else
            echo -e "${RED}❌ Failed to clone repository${NC}"
            echo "You can manually clone it later with:"
            echo "  git clone https://github.com/block52/poker-vm.git"
            return 1
        fi
    fi
}

# Start PVM services
start_pvm() {
    if [ "$RUN_PVM" != true ]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting PVM${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$PVM_TEMP_DIR/docker-compose.yaml" ]; then
        echo -e "${RED}❌ docker-compose.yaml not found in $PVM_TEMP_DIR${NC}"
        return 1
    fi
    
    echo "Starting PVM services with Docker Compose..."
    echo "Working directory: $PVM_TEMP_DIR"
    echo ""
    
    cd "$PVM_TEMP_DIR"
    
    # Start only the PVM service (not the frontend)
    echo -e "${YELLOW}Note: Starting PVM backend only (not frontend UI)${NC}"
    echo "If you want the frontend, run: docker compose up -d"
    echo ""
    
    if docker compose up -d pvm; then
        echo ""
        echo -e "${GREEN}✓${NC} PVM service started"
        echo ""
        echo "PVM Information:"
        echo "  RPC Endpoint: http://localhost:8545"
        echo "  Health Check: http://localhost:8545/health"
        echo ""
        echo "To view logs:"
        echo "  docker compose logs -f pvm"
        echo ""
        echo "To stop PVM:"
        echo "  cd $PVM_TEMP_DIR && docker compose down"
        echo ""
    else
        echo -e "${RED}❌ Failed to start PVM${NC}"
        return 1
    fi
    
    cd - > /dev/null
}

# Stop PVM services
stop_pvm() {
    if [ "$RUN_PVM" != true ]; then
        return 0
    fi
    
    if [ -f "$PVM_TEMP_DIR/docker-compose.yaml" ]; then
        echo ""
        echo "Stopping PVM services..."
        cd "$PVM_TEMP_DIR"
        docker compose down 2>/dev/null || true
        cd - > /dev/null
        echo -e "${GREEN}✓${NC} PVM services stopped"
    fi
}

# Cleanup on exit
cleanup() {
    echo ""
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Node Stopped${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Stop PVM if it was running
    stop_pvm
    
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
    echo "  --rebuild           Rebuild binary before starting"
    echo "  --pvm               Also run PVM (Poker Virtual Machine) execution layer"
    echo "  --sync-node <url>   Specify sync node (default: node1.block52.xyz)"
    echo "  --home <path>       Specify custom home directory"
    echo "  --moniker <name>    Specify custom moniker"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Start with defaults"
    echo "  $0 --reset                            # Reset and start fresh"
    echo "  $0 --rebuild                          # Rebuild binary then start"
    echo "  $0 --pvm                              # Start chain + PVM"
    echo "  $0 --rebuild --reset                  # Rebuild and reset"
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
            --rebuild)
                REBUILD=true
                shift
                ;;
            --pvm)
                RUN_PVM=true
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
    
    # Prompt for PVM if not specified via flag
    if [ "$RUN_PVM" != true ]; then
        prompt_pvm
    fi
    
    # Setup PVM if requested
    if [ "$RUN_PVM" = true ]; then
        setup_pvm
    fi
    
    # Check/build binary
    check_binary
    
    # Initialize node
    initialize_node
    
    # Download genesis
    get_genesis
    
    # Configure node
    configure_node
    
    # Start PVM if requested
    if [ "$RUN_PVM" = true ]; then
        start_pvm
    fi
    
    # Show info
    show_pre_start_info
    
    # Wait a moment
    sleep 2
    
    # Start node
    start_node
}

# Run main
main "$@"