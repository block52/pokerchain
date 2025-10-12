#!/bin/bash

# Pokerchain Validator Node Setup Script
# Sets up a validator node that participates in consensus
#
# Features:
# - Builds pokerchaind from source
# - Fetches genesis and configs from network
# - Generates or imports validator keys
# - Configures consensus participation
# - Creates validator registration transaction
# - Sets up systemd service
# - Verifies connectivity

set -e

# Configuration
CHAIN_ID="pokerchain"
HOME_DIR="$HOME/.pokerchain"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_NODE="node1.block52.xyz"
GITHUB_RAW_URL="https://raw.githubusercontent.com/block52/pokerchain/main"

# Deployment mode
DEPLOYMENT_MODE=""  # "local" or "remote"
REMOTE_USER=""
REMOTE_HOST=""
REMOTE_HOME_DIR=""

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

# Execute command locally or remotely based on mode
exec_cmd() {
    local cmd="$1"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        ssh "$REMOTE_USER@$REMOTE_HOST" "$cmd"
    else
        eval "$cmd"
    fi
}

# Copy file to remote or local based on mode
copy_file() {
    local src="$1"
    local dest="$2"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        scp "$src" "$REMOTE_USER@$REMOTE_HOST:$dest"
    else
        cp "$src" "$dest"
    fi
}

# Test SSH connection
test_ssh_connection() {
    print_info "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST..."
    
    if ! ssh -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_HOST" "echo 'Connection successful'" &> /dev/null; then
        print_error "Cannot connect to $REMOTE_USER@$REMOTE_HOST"
        echo "Please ensure:"
        echo "  1. SSH is accessible"
        echo "  2. You have the correct credentials"
        echo "  3. The hostname is correct"
        exit 1
    fi
    
    print_success "SSH connection successful"
}

# Select deployment mode
select_deployment_mode() {
    print_header "Deployment Mode Selection"
    
    echo ""
    echo "Where do you want to deploy the validator?"
    echo ""
    echo "1) Local machine (this computer)"
    echo "2) Remote Linux server (via SSH)"
    echo ""
    read -p "Enter choice [1-2]: " DEPLOY_CHOICE
    
    case $DEPLOY_CHOICE in
        1)
            DEPLOYMENT_MODE="local"
            HOME_DIR="$HOME/.pokerchain"
            print_success "Selected local deployment"
            ;;
        2)
            DEPLOYMENT_MODE="remote"
            echo ""
            read -p "Enter remote username: " REMOTE_USER
            read -p "Enter remote hostname or IP: " REMOTE_HOST
            
            if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
                print_error "Username and hostname are required"
                exit 1
            fi
            
            # Test connection
            test_ssh_connection
            
            # Get remote home directory
            REMOTE_HOME_DIR=$(ssh "$REMOTE_USER@$REMOTE_HOST" "echo \$HOME")
            HOME_DIR="$REMOTE_HOME_DIR/.pokerchain"
            
            print_success "Selected remote deployment: $REMOTE_USER@$REMOTE_HOST"
            print_info "Remote home directory: $REMOTE_HOME_DIR"
            
            echo ""
            print_info "For remote deployment:"
            echo "  ✓ Binary will be built locally"
            echo "  ✓ Binary will be copied to remote server"
            echo "  ✓ Configuration will be done remotely"
            echo "  ✓ Service will be created on remote server"
            ;;
        *)
            print_error "Invalid choice. Defaulting to local."
            DEPLOYMENT_MODE="local"
            HOME_DIR="$HOME/.pokerchain"
            ;;
    esac
    
    export DEPLOYMENT_MODE
    export REMOTE_USER
    export REMOTE_HOST
    export HOME_DIR
    export REMOTE_HOME_DIR
}

# Stop any running pokerchaind processes
stop_pokerchaind() {
    print_info "Checking for running pokerchaind processes..."
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        # Remote stop
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            if systemctl list-units --full -all 2>/dev/null | grep -q 'pokerchaind.service'; then
                if systemctl is-active --quiet pokerchaind 2>/dev/null; then
                    echo 'Stopping pokerchaind service...'
                    sudo systemctl stop pokerchaind
                    sleep 2
                    echo 'Service stopped'
                fi
            fi
            
            if pgrep -x pokerchaind > /dev/null; then
                echo 'Stopping pokerchaind processes...'
                pkill -TERM pokerchaind 2>/dev/null || true
                sleep 3
                
                if pgrep -x pokerchaind > /dev/null; then
                    pkill -KILL pokerchaind 2>/dev/null || true
                    sleep 1
                fi
                echo 'All pokerchaind processes stopped'
            else
                echo 'No pokerchaind processes running'
            fi
        "
    else
        # Local stop
        if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
            if systemctl is-active --quiet pokerchaind 2>/dev/null; then
                print_warning "Stopping pokerchaind service..."
                sudo systemctl stop pokerchaind
                sleep 2
                print_success "Service stopped"
            fi
        fi
        
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
    fi
}

# Build or verify pokerchaind binary
prepare_binary() {
    print_header "Preparing pokerchaind binary"
    
    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        # For remote deployment, ensure we have a local binary to deploy
        print_info "Remote deployment - checking for local binary..."
        
        if [ -f "$gobin/pokerchaind" ]; then
            print_success "Found existing binary: $gobin/pokerchaind"
            local version=$(pokerchaind version 2>/dev/null || echo "unknown")
            print_info "Local version: $version"
        else
            print_warning "Binary not found - building from source..."
            build_local_binary
        fi
        
        # Now deploy to remote
        deploy_binary_to_remote
    else
        # For local deployment, ask user
        if [ -f "$gobin/pokerchaind" ]; then
            print_success "Found existing pokerchaind: $gobin/pokerchaind"
            local version=$(pokerchaind version 2>/dev/null || echo "unknown")
            print_info "Version: $version"
            
            read -p "Rebuild pokerchaind from source? (y/n): " REBUILD
            if [[ $REBUILD =~ ^[Yy]$ ]]; then
                build_local_binary
            fi
        else
            print_warning "Binary not found - building from source..."
            build_local_binary
        fi
    fi
}

# Build binary locally
build_local_binary() {
    print_info "Building pokerchaind locally..."
    
    if [ ! -f "Makefile" ]; then
        print_error "Makefile not found. Please run from the pokerchain project directory"
        exit 1
    fi
    
    if ! command_exists go; then
        print_error "Go not found. Please install Go 1.24.7+"
        exit 1
    fi
    
    local go_version=$(go version | awk '{print $3}')
    print_info "Go version: $go_version"
    
    print_info "Running: make install"
    if make install; then
        print_success "pokerchaind built successfully"
        
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

# Deploy binary to remote server
deploy_binary_to_remote() {
    print_info "Deploying binary to remote server..."
    
    local local_gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    local local_binary="$local_gobin/pokerchaind"
    
    if [ ! -f "$local_binary" ]; then
        print_error "Local binary not found at $local_binary"
        exit 1
    fi
    
    # Get remote GOBIN path
    local remote_gobin=$(ssh "$REMOTE_USER@$REMOTE_HOST" "echo \${GOBIN:-\${GOPATH:-\$HOME/go}/bin}")
    print_info "Remote Go bin: $remote_gobin"
    
    # Create remote directory
    ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $remote_gobin"
    
    # Copy binary
    print_info "Copying binary to remote..."
    scp "$local_binary" "$REMOTE_USER@$REMOTE_HOST:$remote_gobin/"
    ssh "$REMOTE_USER@$REMOTE_HOST" "chmod +x $remote_gobin/pokerchaind"
    
    # Verify remote binary
    local remote_version=$(ssh "$REMOTE_USER@$REMOTE_HOST" "$remote_gobin/pokerchaind version 2>/dev/null || echo 'unknown'")
    print_success "Binary deployed to remote: $remote_gobin/pokerchaind"
    print_info "Remote version: $remote_version"
}

# Fetch genesis from remote node or GitHub
fetch_genesis() {
    print_header "Fetching genesis.json"
    
    local genesis_file="genesis.json"
    
    if [ -f "$PROJECT_DIR/$genesis_file" ]; then
        print_info "Using local genesis.json from project directory"
        cp "$PROJECT_DIR/$genesis_file" "/tmp/genesis.json"
        print_success "Local genesis.json found"
        return 0
    fi
    
    print_info "Attempting to fetch from remote node: $REMOTE_NODE"
    if curl -s --max-time 10 "http://$REMOTE_NODE:$RPC_PORT/genesis" | jq '.result.genesis' > /tmp/genesis.json 2>/dev/null; then
        if [ -s /tmp/genesis.json ]; then
            print_success "Fetched genesis from remote node"
            return 0
        fi
    fi
    
    print_info "Attempting to fetch from GitHub repository"
    if curl -s --max-time 10 "$GITHUB_RAW_URL/genesis.json" -o /tmp/genesis.json; then
        if [ -s /tmp/genesis.json ]; then
            print_success "Fetched genesis from GitHub"
            return 0
        fi
    fi
    
    print_error "Failed to fetch genesis.json from all sources"
    exit 1
}

# Fetch config files
fetch_configs() {
    print_header "Fetching configuration files"
    
    if [ -f "$PROJECT_DIR/app.toml" ]; then
        print_info "Using local app.toml"
        cp "$PROJECT_DIR/app.toml" "/tmp/app.toml"
        print_success "Local app.toml found"
    else
        print_warning "app.toml not found locally - will use default after init"
    fi
    
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
    print_info "Querying $REMOTE_NODE for node info..."
    
    if command_exists curl && command_exists jq; then
        local node_info=$(curl -s --max-time 10 "http://$REMOTE_NODE:$RPC_PORT/status")
        
        if [ -n "$node_info" ]; then
            local node_id=$(echo "$node_info" | jq -r '.result.node_info.id' 2>/dev/null)
            
            if [ -n "$node_id" ] && [ "$node_id" != "null" ]; then
                print_success "Remote node ID: $node_id"
                echo "$node_id@$REMOTE_NODE:$P2P_PORT"
                return 0
            fi
        fi
    fi
    
    print_warning "Could not automatically fetch node ID"
    return 1
}

# Select validator profile
select_validator_profile() {
    print_header "Validator Profile Selection"
    
    echo ""
    echo "Choose a validator profile:"
    echo ""
    echo "1) Bob - Aggressive validator (recommended for testing)"
    echo "2) Charlie - Strategic validator"
    echo "3) Diana - Unpredictable validator"
    echo "4) Eve - Balanced validator"
    echo "5) Custom - Create your own validator"
    echo ""
    read -p "Enter choice [1-5]: " PROFILE_CHOICE
    
    case $PROFILE_CHOICE in
        1)
            VALIDATOR_NAME="bob"
            VALIDATOR_MONIKER="bob-validator"
            print_success "Selected Bob profile"
            ;;
        2)
            VALIDATOR_NAME="charlie"
            VALIDATOR_MONIKER="charlie-validator"
            print_success "Selected Charlie profile"
            ;;
        3)
            VALIDATOR_NAME="diana"
            VALIDATOR_MONIKER="diana-validator"
            print_success "Selected Diana profile"
            ;;
        4)
            VALIDATOR_NAME="eve"
            VALIDATOR_MONIKER="eve-validator"
            print_success "Selected Eve profile"
            ;;
        5)
            read -p "Enter validator name: " VALIDATOR_NAME
            VALIDATOR_MONIKER="${VALIDATOR_NAME}-validator"
            print_success "Created custom validator: $VALIDATOR_NAME"
            ;;
        *)
            print_error "Invalid choice. Defaulting to Bob"
            VALIDATOR_NAME="bob"
            VALIDATOR_MONIKER="bob-validator"
            ;;
    esac
    
    export VALIDATOR_NAME
    export VALIDATOR_MONIKER
}

# Initialize validator node
initialize_validator_node() {
    print_header "Initializing validator node"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        # Remote initialization
        local node_exists=$(ssh "$REMOTE_USER@$REMOTE_HOST" "[ -d $HOME_DIR ] && echo 'yes' || echo 'no'")
        
        if [ "$node_exists" = "yes" ]; then
            print_warning "$HOME_DIR already exists on remote server"
            read -p "Remove existing data and reinitialize? (y/n): " REINIT
            
            if [[ $REINIT =~ ^[Yy]$ ]]; then
                print_info "Creating backup on remote server..."
                ssh "$REMOTE_USER@$REMOTE_HOST" "
                    backup_dir=\"${HOME_DIR}.backup.\$(date +%Y%m%d_%H%M%S)\"
                    mv $HOME_DIR \$backup_dir
                    echo \"Backup created: \$backup_dir\"
                "
                print_success "Remote backup created"
            else
                print_info "Keeping existing installation"
                return 0
            fi
        fi
        
        print_info "Initializing node on remote server..."
        print_info "Moniker: $VALIDATOR_MONIKER"
        
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            export PATH=\"\${GOBIN:-\${GOPATH:-\$HOME/go}/bin}:/usr/local/go/bin:\$PATH\"
            pokerchaind init '$VALIDATOR_MONIKER' --chain-id '$CHAIN_ID'
            mkdir -p $HOME_DIR/config
            mkdir -p $HOME_DIR/data
        "
        print_success "Node initialized on remote server"
    else
        # Local initialization
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
        
        print_info "Initializing node with chain-id: $CHAIN_ID"
        print_info "Moniker: $VALIDATOR_MONIKER"
        pokerchaind init "$VALIDATOR_MONIKER" --chain-id "$CHAIN_ID"
        print_success "Node initialized"
        
        mkdir -p "$HOME_DIR/config"
        mkdir -p "$HOME_DIR/data"
    fi
}

# Handle validator keys
setup_validator_keys() {
    print_header "Validator Keys Setup"
    
    echo ""
    echo "Validator key options:"
    echo ""
    echo "1) Generate new validator keys (recommended for new validator)"
    echo "2) Import existing validator keys from backup"
    echo "3) Use pre-configured test keys (from .testnets directory)"
    echo ""
    read -p "Enter choice [1-3]: " KEY_CHOICE
    
    case $KEY_CHOICE in
        1)
            print_info "Generating new validator keys..."
            # Keys are automatically generated during init
            
            if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                # Verify keys exist on remote
                local key_exists=$(ssh "$REMOTE_USER@$REMOTE_HOST" "[ -f $HOME_DIR/config/priv_validator_key.json ] && echo 'yes' || echo 'no'")
                
                if [ "$key_exists" = "yes" ]; then
                    print_success "Validator keys generated on remote"
                    
                    # Show validator address from remote
                    print_info "Getting validator info from remote..."
                    ssh "$REMOTE_USER@$REMOTE_HOST" "
                        export PATH=\"\${GOBIN:-\${GOPATH:-\$HOME/go}/bin}:/usr/local/go/bin:\$PATH\"
                        echo \"Validator consensus pubkey: \$(pokerchaind tendermint show-validator 2>/dev/null)\"
                        echo \"Node ID: \$(pokerchaind tendermint show-node-id 2>/dev/null)\"
                    "
                else
                    print_error "Failed to generate validator keys on remote"
                    exit 1
                fi
            else
                if [ -f "$HOME_DIR/config/priv_validator_key.json" ]; then
                    print_success "Validator keys generated"
                    
                    local val_address=$(pokerchaind tendermint show-validator 2>/dev/null)
                    print_info "Validator consensus address: $val_address"
                    
                    local node_id=$(pokerchaind tendermint show-node-id 2>/dev/null)
                    print_info "Node ID: $node_id"
                else
                    print_error "Failed to generate validator keys"
                    exit 1
                fi
            fi
            ;;
        2)
            print_info "Import validator keys from backup..."
            echo ""
            read -p "Enter path to priv_validator_key.json: " KEY_PATH
            
            if [ -f "$KEY_PATH" ]; then
                if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                    scp "$KEY_PATH" "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/config/priv_validator_key.json"
                    ssh "$REMOTE_USER@$REMOTE_HOST" "chmod 600 $HOME_DIR/config/priv_validator_key.json"
                else
                    cp "$KEY_PATH" "$HOME_DIR/config/priv_validator_key.json"
                    chmod 600 "$HOME_DIR/config/priv_validator_key.json"
                fi
                print_success "Validator key imported"
            else
                print_error "Key file not found: $KEY_PATH"
                exit 1
            fi
            
            # Import state if available
            read -p "Enter path to priv_validator_state.json (or press Enter to skip): " STATE_PATH
            if [ -n "$STATE_PATH" ] && [ -f "$STATE_PATH" ]; then
                if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                    scp "$STATE_PATH" "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/data/priv_validator_state.json"
                    ssh "$REMOTE_USER@$REMOTE_HOST" "chmod 600 $HOME_DIR/data/priv_validator_state.json"
                else
                    cp "$STATE_PATH" "$HOME_DIR/data/priv_validator_state.json"
                    chmod 600 "$HOME_DIR/data/priv_validator_state.json"
                fi
                print_success "Validator state imported"
            else
                # Create default state
                if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                    ssh "$REMOTE_USER@$REMOTE_HOST" "echo '{\"height\":\"0\",\"round\":0,\"step\":0}' > $HOME_DIR/data/priv_validator_state.json && chmod 600 $HOME_DIR/data/priv_validator_state.json"
                else
                    echo '{"height":"0","round":0,"step":0}' > "$HOME_DIR/data/priv_validator_state.json"
                    chmod 600 "$HOME_DIR/data/priv_validator_state.json"
                fi
            fi
            ;;
        3)
            print_info "Using pre-configured test keys..."
            
            # Map validator name to test validator ID
            local validator_id=""
            case $VALIDATOR_NAME in
                bob) validator_id="validator1" ;;
                charlie) validator_id="validator2" ;;
                diana) validator_id="validator3" ;;
                eve) validator_id="validator4" ;;
                *)
                    print_error "No test keys available for $VALIDATOR_NAME"
                    print_info "Generating new keys instead..."
                    return 0
                    ;;
            esac
            
            local test_key_path="$PROJECT_DIR/.testnets/$validator_id/config/priv_validator_key.json"
            local test_state_path="$PROJECT_DIR/.testnets/$validator_id/data/priv_validator_state.json"
            
            if [ -f "$test_key_path" ]; then
                if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                    scp "$test_key_path" "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/config/priv_validator_key.json"
                    ssh "$REMOTE_USER@$REMOTE_HOST" "chmod 600 $HOME_DIR/config/priv_validator_key.json"
                else
                    cp "$test_key_path" "$HOME_DIR/config/priv_validator_key.json"
                    chmod 600 "$HOME_DIR/config/priv_validator_key.json"
                fi
                print_success "Test validator key copied for $VALIDATOR_NAME"
                
                if [ -f "$test_state_path" ]; then
                    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
                        scp "$test_state_path" "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/data/priv_validator_state.json"
                        ssh "$REMOTE_USER@$REMOTE_HOST" "chmod 600 $HOME_DIR/data/priv_validator_state.json"
                    else
                        cp "$test_state_path" "$HOME_DIR/data/priv_validator_state.json"
                        chmod 600 "$HOME_DIR/data/priv_validator_state.json"
                    fi
                    print_success "Test validator state copied"
                fi
            else
                print_warning "Test keys not found at $test_key_path"
                print_info "Generating new keys instead..."
            fi
            ;;
        *)
            print_error "Invalid choice. Using generated keys."
            ;;
    esac
    
    # Ensure state file exists
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            [ ! -f $HOME_DIR/data/priv_validator_state.json ] && echo '{\"height\":\"0\",\"round\":0,\"step\":0}' > $HOME_DIR/data/priv_validator_state.json
            chmod 600 $HOME_DIR/data/priv_validator_state.json
        "
    else
        if [ ! -f "$HOME_DIR/data/priv_validator_state.json" ]; then
            echo '{"height":"0","round":0,"step":0}' > "$HOME_DIR/data/priv_validator_state.json"
            chmod 600 "$HOME_DIR/data/priv_validator_state.json"
        fi
    fi
}

# Configure validator node
configure_validator_node() {
    print_header "Configuring validator node"
    
    # Copy genesis
    print_info "Installing genesis.json..."
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        scp /tmp/genesis.json "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/config/genesis.json"
    else
        cp /tmp/genesis.json "$HOME_DIR/config/genesis.json"
    fi
    print_success "Genesis installed"
    
    # Copy app.toml if available
    if [ -f "/tmp/app.toml" ]; then
        print_info "Installing app.toml..."
        if [ "$DEPLOYMENT_MODE" = "remote" ]; then
            scp /tmp/app.toml "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/config/app.toml"
        else
            cp /tmp/app.toml "$HOME_DIR/config/app.toml"
        fi
        print_success "app.toml installed"
    fi
    
    # Configure config.toml for validator node
    print_info "Configuring config.toml for validator..."
    
    # Get persistent peers
    local peer_info=$(get_remote_node_info)
    
    if [ -f "/tmp/config.toml" ]; then
        if [ "$DEPLOYMENT_MODE" = "remote" ]; then
            scp /tmp/config.toml "$REMOTE_USER@$REMOTE_HOST:$HOME_DIR/config/config.toml"
        else
            cp /tmp/config.toml "$HOME_DIR/config/config.toml"
        fi
        print_success "config.toml installed from local copy"
    else
        if [ "$DEPLOYMENT_MODE" = "remote" ]; then
            if [ -n "$peer_info" ]; then
                ssh "$REMOTE_USER@$REMOTE_HOST" "
                    sed -i.bak 's/^persistent_peers = .*/persistent_peers = \"$peer_info\"/' $HOME_DIR/config/config.toml
                    sed -i.bak 's/^pex = .*/pex = true/' $HOME_DIR/config/config.toml
                    sed -i.bak 's/^addr_book_strict = .*/addr_book_strict = false/' $HOME_DIR/config/config.toml
                "
                print_success "Configured persistent_peers on remote: $peer_info"
            fi
        else
            if [ -n "$peer_info" ]; then
                sed -i.bak "s/^persistent_peers = .*/persistent_peers = \"$peer_info\"/" "$HOME_DIR/config/config.toml"
                print_success "Configured persistent_peers: $peer_info"
            fi
            
            sed -i.bak 's/^pex = .*/pex = true/' "$HOME_DIR/config/config.toml"
            sed -i.bak 's/^addr_book_strict = .*/addr_book_strict = false/' "$HOME_DIR/config/config.toml"
        fi
        print_success "Configured P2P settings"
    fi
}

# Create validator account
create_validator_account() {
    print_header "Validator Account Setup"
    
    echo ""
    echo "Validator account options:"
    echo ""
    echo "1) Create new account with new mnemonic"
    echo "2) Import existing account from mnemonic"
    echo "3) Use test account (from TEST_ACTORS.md)"
    echo ""
    read -p "Enter choice [1-3]: " ACCOUNT_CHOICE
    
    local keyring_backend="test"
    
    case $ACCOUNT_CHOICE in
        1)
            print_info "Creating new account for $VALIDATOR_NAME..."
            pokerchaind keys add "$VALIDATOR_NAME" --keyring-backend "$keyring_backend"
            print_success "Account created"
            
            print_warning "IMPORTANT: Save your mnemonic phrase securely!"
            ;;
        2)
            print_info "Importing account from mnemonic..."
            pokerchaind keys add "$VALIDATOR_NAME" --recover --keyring-backend "$keyring_backend"
            print_success "Account imported"
            ;;
        3)
            print_info "Using test account..."
            echo ""
            echo "See TEST_ACTORS.md for mnemonic phrases"
            echo "Importing $VALIDATOR_NAME account..."
            pokerchaind keys add "$VALIDATOR_NAME" --recover --keyring-backend "$keyring_backend"
            print_success "Test account imported"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Show account info
    local account_address=$(pokerchaind keys show "$VALIDATOR_NAME" -a --keyring-backend "$keyring_backend" 2>/dev/null)
    print_success "Validator account address: $account_address"
    
    export VALIDATOR_ACCOUNT=$VALIDATOR_NAME
    export VALIDATOR_ADDRESS=$account_address
}

# Prepare create-validator transaction
prepare_create_validator() {
    print_header "Validator Registration"
    
    echo ""
    print_warning "To register as a validator, you need:"
    echo "  1. Tokens in your account for staking"
    echo "  2. The network to be already running"
    echo "  3. Your node to be fully synced"
    echo ""
    
    read -p "Create validator registration transaction now? (y/n): " CREATE_VAL
    
    if [[ ! $CREATE_VAL =~ ^[Yy]$ ]]; then
        print_info "Skipping validator creation for now"
        echo ""
        echo "To create validator later, run:"
        echo "  pokerchaind tx staking create-validator \\"
        echo "    --amount=1000000stake \\"
        echo "    --pubkey=\$(pokerchaind tendermint show-validator) \\"
        echo "    --moniker=\"$VALIDATOR_MONIKER\" \\"
        echo "    --chain-id=$CHAIN_ID \\"
        echo "    --commission-rate=\"0.10\" \\"
        echo "    --commission-max-rate=\"0.20\" \\"
        echo "    --commission-max-change-rate=\"0.01\" \\"
        echo "    --min-self-delegation=\"1\" \\"
        echo "    --from=$VALIDATOR_ACCOUNT \\"
        echo "    --keyring-backend=test \\"
        echo "    --fees=1000stake"
        return 0
    fi
    
    # Get validator parameters
    echo ""
    read -p "Enter stake amount (default: 100000000000): " STAKE_AMOUNT
    STAKE_AMOUNT=${STAKE_AMOUNT:-100000000000}
    
    read -p "Enter commission rate (0.00-1.00, default: 0.10): " COMMISSION_RATE
    COMMISSION_RATE=${COMMISSION_RATE:-0.10}
    
    # Create the transaction file
    local tx_file="create-validator-$VALIDATOR_NAME.json"
    
    print_info "Creating validator transaction..."
    
    pokerchaind tx staking create-validator \
        --amount="${STAKE_AMOUNT}stake" \
        --pubkey=$(pokerchaind tendermint show-validator) \
        --moniker="$VALIDATOR_MONIKER" \
        --chain-id="$CHAIN_ID" \
        --commission-rate="$COMMISSION_RATE" \
        --commission-max-rate="0.20" \
        --commission-max-change-rate="0.01" \
        --min-self-delegation="1" \
        --from="$VALIDATOR_ACCOUNT" \
        --keyring-backend=test \
        --fees=1000stake \
        --generate-only > "$tx_file"
    
    if [ -f "$tx_file" ]; then
        print_success "Validator transaction created: $tx_file"
        echo ""
        print_info "To broadcast after node is synced:"
        echo "  pokerchaind tx sign $tx_file --from=$VALIDATOR_ACCOUNT --keyring-backend=test --chain-id=$CHAIN_ID > signed-tx.json"
        echo "  pokerchaind tx broadcast signed-tx.json"
    else
        print_warning "Failed to create validator transaction"
    fi
}

# Set file permissions
set_permissions() {
    print_header "Setting secure file permissions"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            chmod 755 $HOME_DIR/config
            chmod 755 $HOME_DIR/data
            chmod 644 $HOME_DIR/config/genesis.json
            chmod 600 $HOME_DIR/config/config.toml
            [ -f $HOME_DIR/config/app.toml ] && chmod 600 $HOME_DIR/config/app.toml
            chmod 600 $HOME_DIR/config/priv_validator_key.json
            chmod 600 $HOME_DIR/data/priv_validator_state.json
            chmod 700 $HOME_DIR/data
        "
        print_success "File permissions set on remote"
    else
        chmod 755 "$HOME_DIR/config"
        chmod 755 "$HOME_DIR/data"
        chmod 644 "$HOME_DIR/config/genesis.json"
        chmod 600 "$HOME_DIR/config/config.toml"
        chmod 600 "$HOME_DIR/config/app.toml" 2>/dev/null || true
        chmod 600 "$HOME_DIR/config/priv_validator_key.json"
        chmod 600 "$HOME_DIR/data/priv_validator_state.json"
        chmod 700 "$HOME_DIR/data"
        
        print_success "File permissions set"
    fi
}

# Create systemd service
create_systemd_service() {
    print_header "Creating systemd service"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        local remote_gobin=$(ssh "$REMOTE_USER@$REMOTE_HOST" "echo \${GOBIN:-\${GOPATH:-\$HOME/go}/bin}")
        
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            sudo tee /etc/systemd/system/pokerchaind.service > /dev/null <<EOF
[Unit]
Description=Pokerchain Validator Node
After=network-online.target

[Service]
Type=simple
User=\$(whoami)
ExecStart=$remote_gobin/pokerchaind start --minimum-gas-prices=\"0.01stake\"
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment=\"DAEMON_NAME=pokerchaind\"
Environment=\"DAEMON_HOME=$HOME_DIR\"
Environment=\"PATH=$remote_gobin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin\"

[Install]
WantedBy=multi-user.target
EOF
            sudo systemctl daemon-reload
        "
        print_success "Systemd service created on remote"
    else
        local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
        
        sudo tee /etc/systemd/system/pokerchaind.service > /dev/null <<EOF
[Unit]
Description=Pokerchain Validator Node
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
    fi
}

# Verify setup
verify_setup() {
    print_header "Verifying setup"
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        # Verify remote setup
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            export PATH=\"\${GOBIN:-\${GOPATH:-\$HOME/go}/bin}:/usr/local/go/bin:\$PATH\"
            
            echo 'Checking pokerchaind...'
            if command -v pokerchaind &> /dev/null; then
                echo '✅ pokerchaind: '\$(which pokerchaind)
            else
                echo '❌ pokerchaind: not found'
            fi
            
            echo 'Checking configuration files...'
            [ -f $HOME_DIR/config/genesis.json ] && echo '✅ genesis.json: present' || echo '❌ genesis.json: missing'
            [ -f $HOME_DIR/config/priv_validator_key.json ] && echo '✅ validator key: present' || echo '❌ validator key: missing'
            
            if [ -f $HOME_DIR/config/priv_validator_key.json ]; then
                echo 'Validator info:'
                echo '  Pubkey: '\$(pokerchaind tendermint show-validator 2>/dev/null)
                echo '  Node ID: '\$(pokerchaind tendermint show-node-id 2>/dev/null)
            fi
        "
    else
        # Verify local setup
        if command_exists pokerchaind; then
            print_success "pokerchaind: $(which pokerchaind)"
        else
            print_error "pokerchaind not found"
        fi
        
        if [ -f "$HOME_DIR/config/genesis.json" ]; then
            print_success "genesis.json: present"
        else
            print_error "genesis.json: missing"
        fi
        
        if [ -f "$HOME_DIR/config/priv_validator_key.json" ]; then
            print_success "validator key: present"
            
            # Show validator info
            local val_pubkey=$(pokerchaind tendermint show-validator 2>/dev/null)
            print_info "Validator pubkey: $val_pubkey"
        else
            print_error "validator key: missing"
        fi
        
        if [ -n "${VALIDATOR_ADDRESS:-}" ]; then
            print_success "Validator address: $VALIDATOR_ADDRESS"
        fi
    fi
}

# Main setup flow
main() {
    print_header "Pokerchain Validator Node Setup"
    
    echo ""
    echo "This script will set up a validator node that participates in consensus."
    echo ""
    print_warning "IMPORTANT: Validator nodes require:"
    echo "  - Sufficient stake/tokens for self-delegation"
    echo "  - Secure key management"
    echo "  - High uptime (slashing penalties for downtime)"
    echo "  - Proper infrastructure (stable network, good hardware)"
    echo ""
    read -p "Continue with validator setup? (y/n): " CONTINUE
    
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    cd "$PROJECT_DIR"
    
    # Select deployment mode (local or remote)
    select_deployment_mode
    
    # Select validator profile
    select_validator_profile
    
    # Stop any running nodes
    stop_pokerchaind
    
    # Prepare binary (build locally and deploy if remote)
    prepare_binary
    
    # Fetch genesis and configs
    fetch_genesis
    fetch_configs
    
    # Initialize node
    initialize_validator_node
    
    # Setup validator keys
    setup_validator_keys
    
    # Configure node
    configure_validator_node
    
    # Create validator account (only for local, remote needs manual key management)
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        create_validator_account
    else
        print_warning "Validator account creation skipped for remote deployment"
        print_info "You'll need to import/create the validator account on the remote server"
    fi
    
    # Set permissions
    set_permissions
    
    # Create systemd service
    read -p "Create systemd service for automatic startup? (y/n): " CREATE_SERVICE
    if [[ $CREATE_SERVICE =~ ^[Yy]$ ]]; then
        create_systemd_service
    fi
    
    # Verify setup
    verify_setup
    
    # Prepare create-validator tx (only for local)
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        prepare_create_validator
    fi
    
    # Final summary
    print_header "Setup Complete!"
    
    echo ""
    echo "📋 Validator Node Configuration:"
    echo "   Deployment: $DEPLOYMENT_MODE"
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        echo "   Remote Host: $REMOTE_USER@$REMOTE_HOST"
    fi
    echo "   Name: $VALIDATOR_NAME"
    echo "   Moniker: $VALIDATOR_MONIKER"
    echo "   Home: $HOME_DIR"
    echo "   Chain ID: $CHAIN_ID"
    if [ -n "${VALIDATOR_ADDRESS:-}" ]; then
        echo "   Address: $VALIDATOR_ADDRESS"
    fi
    echo ""
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        echo "🚀 Start the remote validator node:"
        echo "   ssh $REMOTE_USER@$REMOTE_HOST"
        echo "   sudo systemctl enable pokerchaind"
        echo "   sudo systemctl start pokerchaind"
        echo "   journalctl -u pokerchaind -f"
        echo ""
        echo "📊 Monitor remote sync progress:"
        echo "   ssh $REMOTE_USER@$REMOTE_HOST 'curl http://localhost:$RPC_PORT/status | jq .result.sync_info'"
    else
        echo "🚀 Start the validator node:"
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
    fi
    
    echo ""
    echo "⚠️  IMPORTANT NEXT STEPS:"
    echo "   1. Wait for node to fully sync with the network"
    echo "   2. Ensure your account has sufficient tokens"
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        echo "   3. Create validator account on remote server"
        echo "   4. Broadcast the create-validator transaction from remote"
    else
        echo "   3. Broadcast the create-validator transaction"
    fi
    echo "   4. Monitor validator status and uptime"
    echo ""
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        echo "💡 Remote validator management:"
        echo "   Connect: ssh $REMOTE_USER@$REMOTE_HOST"
        echo "   Logs: ssh $REMOTE_USER@$REMOTE_HOST 'journalctl -u pokerchaind -f'"
        echo "   Status: ssh $REMOTE_USER@$REMOTE_HOST 'curl -s localhost:$RPC_PORT/status | jq'"
    else
        echo "💡 After syncing, check validator status:"
        echo "   pokerchaind query staking validator \$(pokerchaind keys show $VALIDATOR_NAME --bech val -a --keyring-backend=test)"
    fi
    echo ""
    
    # Ask if user wants to start now (only for remote or if systemd service exists locally)
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        read -p "Start the remote validator node now? (y/n): " START_NOW
        if [[ $START_NOW =~ ^[Yy]$ ]]; then
            print_info "Starting remote pokerchaind service..."
            ssh "$REMOTE_USER@$REMOTE_HOST" "
                sudo systemctl enable pokerchaind
                sudo systemctl start pokerchaind
                sleep 3
                systemctl is-active --quiet pokerchaind && echo 'Service started successfully!' || echo 'Service failed to start'
            "
            echo ""
            echo "View remote logs: ssh $REMOTE_USER@$REMOTE_HOST 'journalctl -u pokerchaind -f'"
        fi
    elif systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
        read -p "Start the validator node now? (y/n): " START_NOW
        if [[ $START_NOW =~ ^[Yy]$ ]]; then
            print_info "Starting pokerchaind service..."
            sudo systemctl enable pokerchaind
            sudo systemctl start pokerchaind
            sleep 3
            
            if systemctl is-active --quiet pokerchaind; then
                print_success "Validator node is running!"
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