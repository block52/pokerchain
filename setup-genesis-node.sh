#!/bin/bash

# Pokerchain Genesis Node Setup Script
# This script sets up the master genesis node on node1.block52.xyz

set -e

echo "🔗 Pokerchain Genesis Node Setup"
echo "=================================="
echo ""

# Configuration
CHAIN_ID="pokerchain"
MONIKER="node1.block52.xyz"
HOME_DIR="$HOME/.pokerchain"
REMOTE_USER=""
REMOTE_HOST="node1.block52.xyz"
DEPLOY_TYPE=""

# Required files
REQUIRED_FILES=("genesis.json" "app.toml" "config.toml")

# Cosmos ports
P2P_PORT=26656
RPC_PORT=26657
API_PORT=1317
GRPC_PORT=9090
GRPC_WEB_PORT=9091

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo "ℹ️  $1"
}

# Check if required files exist
check_required_files() {
    print_info "Checking required files..."
    local missing_files=()
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing required files: ${missing_files[*]}"
        echo ""
        echo "Please ensure these files exist in the current directory:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    print_success "All required files found"
}

# Setup UFW firewall rules
setup_firewall() {
    print_info "Setting up UFW firewall rules..."
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        print_warning "UFW not installed. Installing..."
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    # Configure UFW
    print_info "Configuring firewall rules..."
    
    # Allow SSH (important - don't lock yourself out!)
    sudo ufw allow 22/tcp comment 'SSH'
    
    # Allow Cosmos P2P port
    sudo ufw allow ${P2P_PORT}/tcp comment 'Cosmos P2P'
    
    # Allow Cosmos RPC port
    sudo ufw allow ${RPC_PORT}/tcp comment 'Cosmos RPC'
    
    # Allow Cosmos API port
    sudo ufw allow ${API_PORT}/tcp comment 'Cosmos API'
    
    # Allow Cosmos gRPC port
    sudo ufw allow ${GRPC_PORT}/tcp comment 'Cosmos gRPC'
    
    # Allow Cosmos gRPC-Web port
    sudo ufw allow ${GRPC_WEB_PORT}/tcp comment 'Cosmos gRPC-Web'
    
    # Enable UFW if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        print_info "Enabling UFW..."
        sudo ufw --force enable
    fi
    
    print_success "Firewall rules configured"
    echo ""
    sudo ufw status numbered
}

# Create systemd service file
create_systemd_service() {
    local user=$1
    
    print_info "Creating systemd service..."
    
    sudo tee /etc/systemd/system/pokerchaind.service > /dev/null <<EOF
[Unit]
Description=Pokerchain Daemon
After=network-online.target

[Service]
User=$user
ExecStart=$(which pokerchaind) start --minimum-gas-prices="0.01stake"
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=pokerchaind"
Environment="DAEMON_HOME=$HOME_DIR"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    print_success "Systemd service created"
}

# Setup local genesis node
setup_local_genesis_node() {
    print_info "Setting up local genesis node..."
    
    # Check if pokerchaind is installed
    if ! command -v pokerchaind &> /dev/null; then
        print_error "pokerchaind not found. Please install it first."
        echo ""
        echo "Run: make install"
        exit 1
    fi
    
    print_success "pokerchaind found"
    
    # Check required files
    check_required_files
    
    # Initialize node if not already done
    if [ -d "$HOME_DIR" ]; then
        read -p "⚠️  $HOME_DIR already exists. Remove and reinitialize? (y/n): " REINIT
        if [[ $REINIT == "y" ]]; then
            print_info "Removing existing chain data..."
            rm -rf "$HOME_DIR"
            print_success "Existing data removed"
        fi
    fi
    
    if [ ! -d "$HOME_DIR" ]; then
        print_info "Initializing genesis node..."
        pokerchaind init "$MONIKER" --chain-id "$CHAIN_ID"
        print_success "Node initialized"
    else
        print_success "Node already initialized"
    fi
    
    # Create necessary directories
    print_info "Ensuring directory structure..."
    mkdir -p "$HOME_DIR/config"
    mkdir -p "$HOME_DIR/data"
    
    # Copy genesis file
    print_info "Copying genesis.json..."
    cp genesis.json "$HOME_DIR/config/genesis.json"
    print_success "Genesis file copied"
    
    # Validate genesis
    print_info "Validating genesis file..."
    if pokerchaind validate-genesis; then
        print_success "Genesis file is valid"
    else
        print_error "Genesis file validation failed"
        exit 1
    fi
    
    # Copy app.toml
    print_info "Copying app.toml..."
    cp app.toml "$HOME_DIR/config/app.toml"
    print_success "app.toml copied"
    
    # Copy config.toml
    print_info "Copying config.toml..."
    cp config.toml "$HOME_DIR/config/config.toml"
    print_success "config.toml copied"
    
    # Setup firewall
    read -p "Setup UFW firewall rules? (y/n): " SETUP_FW
    if [[ $SETUP_FW == "y" ]]; then
        setup_firewall
    fi
    
    # Create systemd service
    read -p "Create systemd service? (y/n): " SETUP_SERVICE
    if [[ $SETUP_SERVICE == "y" ]]; then
        create_systemd_service "$(whoami)"
        
        echo ""
        print_info "Systemd service created. You can now:"
        echo "  sudo systemctl enable pokerchaind  # Enable on boot"
        echo "  sudo systemctl start pokerchaind   # Start the service"
        echo "  sudo systemctl status pokerchaind  # Check status"
        echo "  journalctl -u pokerchaind -f       # View logs"
    fi
    
    echo ""
    print_success "Local genesis node setup complete!"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Start the node: pokerchaind start --minimum-gas-prices=\"0.01stake\""
    echo "     OR use systemd: sudo systemctl start pokerchaind"
    echo ""
    echo "  2. Get node info: ./get-node-info.sh"
    echo ""
    echo "  3. Check status: curl http://localhost:${RPC_PORT}/status"
}

# Deploy to remote server
deploy_to_remote() {
    local remote_user=$1
    local remote_host=$2
    
    print_info "Deploying to remote server: $remote_user@$remote_host"
    
    # Check required files
    check_required_files
    
    # Test SSH connection
    print_info "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=5 "$remote_user@$remote_host" "echo 'Connection successful'" &> /dev/null; then
        print_error "Cannot connect to $remote_user@$remote_host"
        echo "Please ensure:"
        echo "  1. SSH is accessible"
        echo "  2. You have the correct credentials"
        echo "  3. The hostname is correct"
        exit 1
    fi
    print_success "SSH connection successful"
    
    # Create remote directory
    print_info "Creating remote directories..."
    ssh "$remote_user@$remote_host" "mkdir -p ~/.pokerchain/config ~/.pokerchain/data"
    
    # Copy required files
    print_info "Copying files to remote server..."
    scp genesis.json "$remote_user@$remote_host:~/.pokerchain/config/"
    scp app.toml "$remote_user@$remote_host:~/.pokerchain/config/"
    scp config.toml "$remote_user@$remote_host:~/.pokerchain/config/"
    
    # Copy setup scripts
    if [ -f "install-from-source.sh" ]; then
        scp install-from-source.sh "$remote_user@$remote_host:~/"
    fi
    if [ -f "get-node-info.sh" ]; then
        scp get-node-info.sh "$remote_user@$remote_host:~/"
    fi
    
    print_success "Files copied to remote server"
    
    # Create remote setup script
    print_info "Creating remote setup script..."
    
    cat > /tmp/remote-setup.sh <<'REMOTE_SCRIPT'
#!/bin/bash
set -e

echo "🔧 Setting up genesis node on remote server..."

# Check if pokerchaind is installed
if ! command -v pokerchaind &> /dev/null; then
    echo "❌ pokerchaind not found. Please install it first."
    if [ -f ~/install-from-source.sh ]; then
        echo "Running install-from-source.sh..."
        chmod +x ~/install-from-source.sh
        ~/install-from-source.sh
    else
        echo "Please install pokerchaind manually"
        exit 1
    fi
fi

# Initialize node if needed
if [ ! -d ~/.pokerchain/config/genesis.json ]; then
    echo "🔧 Initializing node..."
    pokerchaind init "node1.block52.xyz" --chain-id pokerchain
fi

# Validate genesis
echo "✅ Validating genesis..."
pokerchaind validate-genesis

# Setup UFW firewall
echo "🔒 Setting up firewall..."
sudo apt-get update
sudo apt-get install -y ufw

# Configure firewall rules
sudo ufw allow 22/tcp
sudo ufw allow 26656/tcp
sudo ufw allow 26657/tcp
sudo ufw allow 1317/tcp
sudo ufw allow 9090/tcp
sudo ufw allow 9091/tcp
sudo ufw --force enable

echo "✅ Firewall configured"
sudo ufw status numbered

# Create systemd service
echo "📋 Creating systemd service..."
sudo tee /etc/systemd/system/pokerchaind.service > /dev/null <<EOF
[Unit]
Description=Pokerchain Daemon
After=network-online.target

[Service]
User=$(whoami)
ExecStart=$(which pokerchaind) start --minimum-gas-prices="0.01stake"
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=pokerchaind"
Environment="DAEMON_HOME=$HOME/.pokerchain"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

echo ""
echo "✅ Remote setup complete!"
echo ""
echo "To start the node:"
echo "  sudo systemctl enable pokerchaind"
echo "  sudo systemctl start pokerchaind"
echo "  journalctl -u pokerchaind -f"
REMOTE_SCRIPT
    
    # Copy and execute remote setup script
    scp /tmp/remote-setup.sh "$remote_user@$remote_host:~/remote-setup.sh"
    ssh "$remote_user@$remote_host" "chmod +x ~/remote-setup.sh && ~/remote-setup.sh"
    
    # Clean up
    rm /tmp/remote-setup.sh
    
    print_success "Remote deployment complete!"
    echo ""
    echo "📋 Remote node is ready!"
    echo ""
    echo "To manage the remote node:"
    echo "  ssh $remote_user@$remote_host"
    echo "  sudo systemctl status pokerchaind"
    echo "  journalctl -u pokerchaind -f"
}

# Main menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1) Setup genesis node locally"
    echo "2) Deploy genesis node to node1.block52.xyz"
    echo "3) Show network information"
    echo "4) Exit"
    echo ""
    read -p "Choose option (1-4): " CHOICE
    
    case $CHOICE in
        1)
            setup_local_genesis_node
            ;;
        2)
            echo ""
            read -p "Enter username for node1.block52.xyz: " REMOTE_USER
            if [ -z "$REMOTE_USER" ]; then
                print_error "Username cannot be empty"
                exit 1
            fi
            deploy_to_remote "$REMOTE_USER" "$REMOTE_HOST"
            ;;
        3)
            echo ""
            echo "🌐 Network Configuration:"
            echo "========================"
            echo "Chain ID: $CHAIN_ID"
            echo "Genesis Node: $MONIKER"
            echo ""
            echo "Ports:"
            echo "  P2P:       $P2P_PORT"
            echo "  RPC:       $RPC_PORT"
            echo "  API:       $API_PORT"
            echo "  gRPC:      $GRPC_PORT"
            echo "  gRPC-Web:  $GRPC_WEB_PORT"
            echo ""
            echo "Endpoints:"
            echo "  RPC:  http://$REMOTE_HOST:$RPC_PORT"
            echo "  API:  http://$REMOTE_HOST:$API_PORT"
            echo "  gRPC: $REMOTE_HOST:$GRPC_PORT"
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# Run main menu
show_menu

echo ""
echo "🎉 Setup complete!"
echo ""