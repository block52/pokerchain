#!/bin/bash

# Deploy Sync Node to Remote Server
# Sets up a read-only sync node on a remote Linux server
# Syncs from the production network (node1.block52.xyz)
#
# Key features:
# - Automatically removes any existing installations for clean deployment
# - Downloads and verifies genesis file from RPC endpoint
# - Configures correct peer ID from live node
# - Uses block sync (state sync disabled as snapshots not available)
# - Verifies binary hash before uploading to avoid unnecessary transfers
# - Option to use local binary or download from GitHub releases

set -e

# Configuration
CHAIN_BINARY="pokerchaind"
CHAIN_ID="pokerchain"
NODE_HOME="$HOME/.pokerchain"
SYNC_NODE="node1.block52.xyz"
SYNC_NODE_RPC="http://node1.block52.xyz:26657"
GITHUB_REPO="block52/pokerchain"
BINARY_SOURCE=""  # Will be set to "local" or "github"

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

# Ask user for binary source
echo ""
echo -e "${CYAN}Binary Source Options:${NC}"
echo "  1) Use local build (from ./build directory)"
echo "  2) Download from GitHub release"
echo ""
read -p "Choose binary source (1 or 2): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[1]$ ]]; then
    BINARY_SOURCE="local"
    echo -e "${GREEN}✓${NC} Will use local binary"
elif [[ $REPLY =~ ^[2]$ ]]; then
    BINARY_SOURCE="github"
    echo -e "${GREEN}✓${NC} Will download from GitHub release"
    
    # Ask for version/tag
    echo ""
    read -p "Enter release tag (e.g., v0.1.4) or press Enter for latest: " RELEASE_TAG
    if [ -z "$RELEASE_TAG" ]; then
        RELEASE_TAG="latest"
        echo "Using latest release"
    else
        echo "Using release: $RELEASE_TAG"
    fi
else
    echo -e "${RED}Invalid choice. Please select 1 or 2.${NC}"
    exit 1
fi

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
            REMOTE_OS="linux"
            REMOTE_ARCH="amd64"
            ;;
        aarch64|arm64)
            TARGET_ARCH="arm64"
            BUILD_TARGET="linux-arm64"
            REMOTE_OS="linux"
            REMOTE_ARCH="arm64"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓${NC} Target: ${REMOTE_OS}/${REMOTE_ARCH} (build: $BUILD_TARGET)"
}

# Download binary from GitHub releases
download_from_github() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Downloading Binary from GitHub${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Determine the binary name based on remote architecture
    local BINARY_NAME="${CHAIN_BINARY}-${REMOTE_OS}-${REMOTE_ARCH}"
    local ARCHIVE_NAME="${BINARY_NAME}-${RELEASE_TAG}.tar.gz"
    
    if [ "$RELEASE_TAG" = "latest" ]; then
        echo "Getting latest release information..."
        
        # Get latest release tag
        RELEASE_TAG=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [ -z "$RELEASE_TAG" ]; then
            echo -e "${RED}❌ Could not determine latest release${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓${NC} Latest release: $RELEASE_TAG"
        ARCHIVE_NAME="${BINARY_NAME}-${RELEASE_TAG}.tar.gz"
    fi
    
    local DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${ARCHIVE_NAME}"
    local CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${ARCHIVE_NAME}.sha256"
    local TEMP_DIR="/tmp/pokerchain-download-$$"
    
    echo "Downloading from: $DOWNLOAD_URL"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download archive
    echo ""
    echo "Downloading binary archive..."
    if ! curl -L -f -o "$ARCHIVE_NAME" "$DOWNLOAD_URL"; then
        echo -e "${RED}❌ Failed to download binary${NC}"
        echo "URL: $DOWNLOAD_URL"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Downloaded $ARCHIVE_NAME"
    
    # Download checksum
    echo ""
    echo "Downloading checksum..."
    if curl -L -f -o "${ARCHIVE_NAME}.sha256" "$CHECKSUM_URL" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Downloaded checksum"
        
        # Verify checksum
        echo ""
        echo "Verifying checksum..."
        EXPECTED_HASH=$(cat "${ARCHIVE_NAME}.sha256")
        ACTUAL_HASH=$(sha256sum "$ARCHIVE_NAME" | awk '{print $1}')
        
        if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
            echo -e "${GREEN}✓${NC} Checksum verified"
        else
            echo -e "${RED}❌ Checksum mismatch!${NC}"
            echo "  Expected: $EXPECTED_HASH"
            echo "  Actual:   $ACTUAL_HASH"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠ Checksum not available, skipping verification${NC}"
    fi
    
    # Extract binary
    echo ""
    echo "Extracting binary..."
    if ! tar -xzf "$ARCHIVE_NAME"; then
        echo -e "${RED}❌ Failed to extract archive${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    if [ ! -f "$BINARY_NAME" ]; then
        echo -e "${RED}❌ Binary not found in archive${NC}"
        ls -la
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Extracted binary: $BINARY_NAME"
    
    # Set the local binary path to the downloaded file
    LOCAL_BINARY="$TEMP_DIR/$BINARY_NAME"
    
    # Make executable
    chmod +x "$LOCAL_BINARY"
    
    echo ""
    echo -e "${GREEN}✓${NC} Binary ready: $LOCAL_BINARY"
}

# Build local binary
build_local_binary() {
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
    echo -e "${CYAN}Checking Binary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # First, check if we have a local binary
    if [ ! -f "$LOCAL_BINARY" ]; then
        echo -e "${RED}❌ Local binary not found: $LOCAL_BINARY${NC}"
        exit 1
    fi
    
    # Get local binary hash
    echo "Calculating local binary hash..."
    LOCAL_HASH=$(sha256sum "$LOCAL_BINARY" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$LOCAL_BINARY" 2>/dev/null | awk '{print $1}')
    
    if [ -z "$LOCAL_HASH" ]; then
        echo -e "${RED}❌ Failed to calculate local binary hash${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Local binary hash: $LOCAL_HASH"
    
    # Check if remote binary exists
    echo ""
    echo "Checking for existing binary on remote server..."
    if ssh "$REMOTE_USER@$REMOTE_HOST" "[ -f /usr/local/bin/pokerchaind ]" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Binary exists on remote server"
        
        # Get remote binary hash
        echo ""
        echo "Calculating remote binary hash..."
        REMOTE_HASH=$(ssh "$REMOTE_USER@$REMOTE_HOST" "sha256sum /usr/local/bin/pokerchaind 2>/dev/null | awk '{print \$1}'")
        
        if [ -z "$REMOTE_HASH" ]; then
            echo -e "${YELLOW}⚠ Failed to calculate remote binary hash${NC}"
            echo -e "${YELLOW}⚠ Will upload binary to be safe${NC}"
        else
            echo -e "${GREEN}✓${NC} Remote binary hash: $REMOTE_HASH"
            
            # Compare hashes
            echo ""
            echo "Comparing hashes..."
            echo "  Local:  $LOCAL_HASH"
            echo "  Remote: $REMOTE_HASH"
            
            if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
                echo ""
                echo -e "${GREEN}✓${NC} Hashes match - binary is already up to date!"
                echo -e "${GREEN}✓${NC} Skipping upload"
                
                # Verify binary works
                echo ""
                echo "Verifying binary version..."
                ssh "$REMOTE_USER@$REMOTE_HOST" "pokerchaind version" || echo "Version: unknown"
                return 0
            else
                echo ""
                echo -e "${YELLOW}⚠ Hashes don't match - binary needs to be updated${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Binary not found on remote server${NC}"
    fi
    
    # Upload the binary
    echo ""
    echo "Uploading $LOCAL_BINARY to remote server..."
    
    scp "$LOCAL_BINARY" "$REMOTE_USER@$REMOTE_HOST:/tmp/pokerchaind"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        sudo mv /tmp/pokerchaind /usr/local/bin/pokerchaind
        sudo chmod +x /usr/local/bin/pokerchaind
        sudo chown root:root /usr/local/bin/pokerchaind
    "
    
    echo -e "${GREEN}✓${NC} Binary installed to /usr/local/bin/pokerchaind"
    
    # Verify the uploaded binary hash matches
    echo ""
    echo "Verifying uploaded binary..."
    NEW_REMOTE_HASH=$(ssh "$REMOTE_USER@$REMOTE_HOST" "sha256sum /usr/local/bin/pokerchaind 2>/dev/null | awk '{print \$1}'")
    
    if [ "$LOCAL_HASH" = "$NEW_REMOTE_HASH" ]; then
        echo -e "${GREEN}✓${NC} Upload verified - hashes match!"
    else
        echo -e "${YELLOW}⚠ Warning: Uploaded binary hash doesn't match local hash${NC}"
        echo "  Expected: $LOCAL_HASH"
        echo "  Got:      $NEW_REMOTE_HASH"
    fi
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "pokerchaind version" || echo "Version: unknown"
}

# Initialize remote node
initialize_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Initializing Remote Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Always reset for clean deployment
    echo "Stopping any existing node services..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        sudo systemctl stop pokerchaind 2>/dev/null || true
        pkill -9 pokerchaind 2>/dev/null || true
        sleep 2
    "
    
    # Check if node already exists
    local exists=$(ssh "$REMOTE_USER@$REMOTE_HOST" "[ -d $NODE_HOME ] && echo 'yes' || echo 'no'")
    
    if [ "$exists" = "yes" ]; then
        echo -e "${YELLOW}⚠ Node directory already exists on remote server${NC}"
        echo "Removing existing node data for clean installation..."
        ssh "$REMOTE_USER@$REMOTE_HOST" "rm -rf $NODE_HOME"
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
    
    local GENESIS_URL="https://raw.githubusercontent.com/block52/pokerchain/main/genesis.json"
    echo "Downloading genesis from GitHub repository..."
    echo "  URL: $GENESIS_URL"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        # Download genesis from GitHub repository
        curl -fsSL '$GENESIS_URL' > $NODE_HOME/config/genesis.json
        
        # Verify the genesis file
        if [ -f $NODE_HOME/config/genesis.json ] && [ -s $NODE_HOME/config/genesis.json ]; then
            # Check that chain_id is present
            CHAIN_ID_CHECK=\$(cat $NODE_HOME/config/genesis.json | jq -r .chain_id 2>/dev/null)
            if [ \"\$CHAIN_ID_CHECK\" = \"$CHAIN_ID\" ]; then
                echo 'Genesis downloaded and verified successfully'
                echo \"Chain ID: \$CHAIN_ID_CHECK\"
                
                # Show genesis file size and hash for verification
                FILE_SIZE=\$(ls -lh $NODE_HOME/config/genesis.json | awk '{print \$5}')
                FILE_HASH=\$(sha256sum $NODE_HOME/config/genesis.json | awk '{print \$1}')
                echo \"File size: \$FILE_SIZE\"
                echo \"SHA256: \$FILE_HASH\"
            else
                echo 'ERROR: Genesis file missing chain_id or invalid'
                echo \"Expected chain_id: $CHAIN_ID\"
                echo \"Got chain_id: \$CHAIN_ID_CHECK\"
                exit 1
            fi
        else
            echo 'ERROR: Failed to download genesis from GitHub'
            echo 'Please check:'
            echo '  1. Internet connectivity'
            echo '  2. GitHub repository is accessible'
            echo '  3. Genesis file exists at: $GENESIS_URL'
            exit 1
        fi
    "
    
    echo -e "${GREEN}✓${NC} Genesis downloaded and verified from GitHub"
}

# Configure node
configure_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Configuring Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Download template app.toml from GitHub
    local APP_TOML_URL="https://raw.githubusercontent.com/block52/pokerchain/main/template-app.toml"
    echo "Downloading template app.toml from GitHub..."
    echo "  URL: $APP_TOML_URL"
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        # Try to download template-app.toml from GitHub
        if curl -fsSL '$APP_TOML_URL' > /tmp/app.toml 2>/dev/null; then
            mv /tmp/app.toml $NODE_HOME/config/app.toml
            echo 'Template app.toml downloaded from GitHub'
        else
            echo 'Note: Could not download template-app.toml from GitHub'
            echo 'Using default app.toml generated by init'
        fi
    "
    
    # Get the ACTUAL sync node ID from the status endpoint
    echo ""
    echo "Getting sync node ID from $SYNC_NODE_RPC..."
    local sync_node_id=$(curl -s "$SYNC_NODE_RPC/status" | jq -r .result.node_info.id 2>/dev/null)
    
    if [ -n "$sync_node_id" ] && [ "$sync_node_id" != "null" ]; then
        echo -e "${GREEN}✓${NC} Sync node ID: $sync_node_id"
        
        # Get the IP address for the persistent peer
        local sync_node_ip=$(dig +short $SYNC_NODE | head -n1)
        if [ -z "$sync_node_ip" ]; then
            sync_node_ip="170.64.205.169"  # Fallback to known IP
        fi
        
        local persistent_peer="${sync_node_id}@${sync_node_ip}:26656"
        
        echo "Configuring node settings..."
        ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
            # Set persistent peer with correct node ID
            sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$persistent_peer\"/g" $NODE_HOME/config/config.toml
            
            # Disable state sync (not available on sync node)
            sed -i.bak "s/^enable = true/enable = false/" $NODE_HOME/config/config.toml
            
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
            
            echo ""
            echo "Configuration applied:"
            echo "  Persistent Peer: $persistent_peer"
            echo "  State Sync: disabled (using block sync)"
EOF
        
        echo -e "${GREEN}✓${NC} Node configured"
        echo ""
        echo "Configuration:"
        echo "  Sync Peer: $persistent_peer"
        echo "  Sync Method: Block sync from genesis"
        echo "  RPC: http://$REMOTE_HOST:26657"
        echo "  API: http://$REMOTE_HOST:1317"
    else
        echo -e "${RED}❌ Could not get sync node ID from $SYNC_NODE_RPC${NC}"
        echo "Please check that the sync node is accessible"
        exit 1
    fi
}

# Configure bridge settings in app.toml
configure_bridge() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Configuring Bridge Settings${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local alchemy_url=""
    local contract_addr="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
    local usdc_addr="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    
    # Check for .env file
    if [ -f ".env" ]; then
        echo "Found .env file, reading ALCHEMY_URL..."
        alchemy_url=$(grep "^ALCHEMY_URL=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$alchemy_url" ]; then
            echo -e "${GREEN}✓${NC} Using ALCHEMY_URL from .env: ${alchemy_url:0:50}..."
        fi
    fi
    
    # Prompt if not found
    if [ -z "$alchemy_url" ]; then
        echo -e "${YELLOW}⚠ No ALCHEMY_URL found in .env file${NC}"
        echo ""
        echo "Enter Base/Ethereum RPC URL (Alchemy recommended):"
        echo "Example: https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
        echo ""
        read -p "RPC URL (or press Enter to skip bridge configuration): " alchemy_url
        
        if [ -z "$alchemy_url" ]; then
            echo -e "${YELLOW}⚠${NC} Skipping bridge configuration"
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
    
    read -p "Apply this bridge configuration? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping bridge configuration"
        return 0
    fi
    
    echo "Updating bridge configuration in app.toml..."
    
    # Escape special characters for sed
    local escaped_url=$(echo "$alchemy_url" | sed 's/[&/\]/\\&/g')
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "
        # Update ethereum_rpc_url in app.toml
        if grep -q 'ethereum_rpc_url' $NODE_HOME/config/app.toml; then
            sed -i.bak 's|ethereum_rpc_url = .*|ethereum_rpc_url = \"$escaped_url\"|' $NODE_HOME/config/app.toml
            echo 'Updated ethereum_rpc_url in app.toml'
        else
            echo 'Warning: ethereum_rpc_url not found in app.toml'
        fi
        
        # Ensure bridge is enabled
        if grep -q 'enabled = false' $NODE_HOME/config/app.toml; then
            sed -i 's/enabled = false/enabled = true/' $NODE_HOME/config/app.toml
        fi
        
        # Clean up backup
        rm -f $NODE_HOME/config/app.toml.bak
    "
    
    echo -e "${GREEN}✓${NC} Bridge configuration updated"
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
    
    echo "Using setup-firewall.sh to configure firewall..."
    
    if [ ! -f "./setup-firewall.sh" ]; then
        echo -e "${RED}❌ setup-firewall.sh not found${NC}"
        return 1
    fi
    
    ./setup-firewall.sh "$REMOTE_HOST" "$REMOTE_USER"
    
    echo -e "${GREEN}✓${NC} Firewall configured"
}

# Start node
start_node() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Starting Node${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "Starting pokerchaind service..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "systemctl start pokerchaind"
    
    echo ""
    echo "Waiting for node to start..."
    sleep 10
    
    # Check status
    echo ""
    echo "Service status:"
    ssh "$REMOTE_USER@$REMOTE_HOST" "systemctl status pokerchaind --no-pager -l" || true
    
    echo ""
    echo "Checking sync status..."
    sleep 5
    
    # Check if node is syncing
    local sync_status=$(ssh "$REMOTE_USER@$REMOTE_HOST" "curl -s localhost:26657/status 2>/dev/null | jq -r '.result.sync_info | {catching_up, latest_block_height, latest_block_time}' 2>/dev/null")
    
    if [ -n "$sync_status" ]; then
        echo ""
        echo "Node sync status:"
        echo "$sync_status" | jq .
        echo ""
        echo -e "${GREEN}✓${NC} Node started and syncing!"
    else
        echo -e "${YELLOW}⚠ Could not get sync status. Check logs for details.${NC}"
        echo ""
        echo "Recent logs:"
        ssh "$REMOTE_USER@$REMOTE_HOST" "journalctl -u pokerchaind -n 20 --no-pager"
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
    echo "  Sync Method: Block sync from genesis"
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
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'curl -s localhost:26657/status | jq .result.sync_info'"
    echo ""
    echo "  # Stop node"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl stop pokerchaind'"
    echo ""
    echo "  # Restart node"
    echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl restart pokerchaind'"
    echo ""
    echo -e "${YELLOW}Important Notes:${NC}"
    echo -e "${YELLOW}• Initial sync will take time - syncing from block 1${NC}"
    echo -e "${YELLOW}• Watch for 'catching_up: false' in the sync status${NC}"
    echo -e "${YELLOW}• Monitor with: journalctl -u pokerchaind -f${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    # Clean up temp directory if it was created for GitHub download
    if [ "$BINARY_SOURCE" = "github" ] && [ -n "$LOCAL_BINARY" ] && [[ "$LOCAL_BINARY" == /tmp/pokerchain-download-* ]]; then
        local TEMP_DIR=$(dirname "$LOCAL_BINARY")
        if [ -d "$TEMP_DIR" ]; then
            echo ""
            echo "Cleaning up temporary files..."
            rm -rf "$TEMP_DIR"
            echo -e "${GREEN}✓${NC} Cleaned up $TEMP_DIR"
        fi
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main function
main() {
    print_header
    
    # Preflight checks
    check_ssh
    detect_remote_arch
    
    # Get binary (either build locally or download from GitHub)
    if [ "$BINARY_SOURCE" = "local" ]; then
        build_local_binary
    else
        download_from_github
    fi
    
    # Deploy binary
    upload_binary
    
    # Initialize and configure
    initialize_node
    download_genesis
    configure_node
    configure_bridge
    
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