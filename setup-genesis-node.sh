#!/bin/bash

# Pokerchain Genesis Node Setup Script
# This script sets up the master genesis node on node1.block52.xyz
#
# Features:
# - Builds pokerchaind from source using Makefile
# - Deploys binary to remote server's GOBIN directory
# - Stops any running pokerchaind processes before setup
# - Disables systemd service during setup to prevent conflicts
# - Sets least privilege file permissions (600 for sensitive files, 644 for public)
# - Creates backups before destructive operations
# - Verifies permissions after setting them
# - Configures UFW firewall with only necessary ports
# - Creates systemd service with restart policies
# - Automatically restarts service after deployment
# - Verifies public endpoint accessibility
#
# File Permissions:
# - genesis.json: 644 (public readable)
# - config.toml: 600 (owner only - contains node configuration)
# - app.toml: 600 (owner only - contains app settings)
# - priv_validator_key.json: 600 (CRITICAL - validator private key)
# - priv_validator_state.json: 600 (CRITICAL - validator state)
# - node_key.json: 600 (owner only - node identity)
# - data/: 700 (owner only - blockchain data)
#
# Public Endpoints Verified:
# - RPC (26657): Node status and blockchain queries
# - API (1317): REST API for cosmos modules
# - P2P (26656): Peer-to-peer communication
# - gRPC (9090): gRPC queries

set -e

echo "🔗 Pokerchain Genesis Node Setup"
echo "=================================="
echo ""

# Configuration
CHAIN_ID="pokerchain"
MONIKER="node1.block52.xyz"
HOME_DIR="$HOME/.pokerchain"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Detect the correct genesis validation command
detect_genesis_validation_cmd() {
    # Try different command variations based on Cosmos SDK version
    if pokerchaind genesis validate --help &>/dev/null; then
        echo "genesis validate"
    elif pokerchaind validate-genesis --help &>/dev/null; then
        echo "validate-genesis"
    elif pokerchaind genesis validate-genesis --help &>/dev/null; then
        echo "genesis validate-genesis"
    else
        # Command doesn't exist, we'll skip validation
        echo ""
    fi
}

# Validate genesis file
validate_genesis() {
    print_info "Validating genesis file..."
    
    local validate_cmd=$(detect_genesis_validation_cmd)
    
    if [ -z "$validate_cmd" ]; then
        print_warning "Genesis validation command not available in this version"
        print_info "Skipping validation (will verify manually during startup)"
        return 0
    fi
    
    # Change to home directory to ensure correct context
    cd "$HOME_DIR/config" 2>/dev/null || cd "$HOME_DIR"
    
    if pokerchaind $validate_cmd 2>&1; then
        print_success "Genesis file is valid"
        cd "$PROJECT_DIR"
        return 0
    else
        print_error "Genesis file validation failed"
        cd "$PROJECT_DIR"
        return 1
    fi
}

# Ensure we're in the project directory
ensure_project_directory() {
    print_info "Project directory: $PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # List what we found
    echo ""
    echo "📁 Files found in project directory:"
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "   ✅ $file"
        else
            echo "   ❌ $file (MISSING)"
        fi
    done
    echo ""
    
    # Verify we have the required files in this directory
    local missing_files=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "Missing required files in $PROJECT_DIR:"
        for file in "${missing_files[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "Please ensure you're running this script from the pokerchain project directory"
        echo "where these configuration files are located."
        exit 1
    fi
    
    print_success "All required files found in project directory"
}

# Check Go environment
check_go_environment() {
    print_info "Checking Go environment..."
    
    if ! command -v go &> /dev/null; then
        print_warning "Go not found in PATH"
        echo "Please ensure Go is installed and in your PATH"
        return 1
    fi
    
    local go_version=$(go version | awk '{print $3}')
    print_success "Go version: $go_version"
    
    # Check GOPATH
    if [ -n "$GOPATH" ]; then
        print_info "GOPATH: $GOPATH"
    else
        print_info "GOPATH: Not set (using default ~/go)"
    fi
    
    # Check if pokerchaind is in GOPATH/bin or GOBIN
    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    if [ -f "$gobin/pokerchaind" ]; then
        print_success "pokerchaind found in: $gobin"
    fi
    
    return 0
}

# Build pokerchaind using make
build_pokerchaind() {
    print_info "Building pokerchaind from source..."
    
    # Check if Makefile exists
    if [ ! -f "Makefile" ]; then
        print_error "Makefile not found in $PROJECT_DIR"
        echo "Please ensure you're in the pokerchain project root directory"
        exit 1
    fi
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go not found. Please install Go first."
        exit 1
    fi
    
    # Build using make
    print_info "Running: make install"
    if make install; then
        print_success "pokerchaind built and installed successfully"
        
        # Verify installation
        local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
        if [ -f "$gobin/pokerchaind" ]; then
            print_success "Binary location: $gobin/pokerchaind"
            pokerchaind version 2>/dev/null || true
        else
            print_error "Build succeeded but binary not found in $gobin"
            exit 1
        fi
    else
        print_error "Failed to build pokerchaind"
        exit 1
    fi
}

# Verify public endpoints are accessible
verify_public_endpoints() {
    local host=$1
    
    echo ""
    print_info "Verifying public endpoint accessibility on $host..."
    echo ""
    
    local all_success=true
    
    # Test RPC endpoint
    print_info "Testing RPC endpoint (port $RPC_PORT)..."
    if curl -s --max-time 5 "http://$host:$RPC_PORT/status" > /dev/null 2>&1; then
        print_success "RPC (${RPC_PORT}): ✅ Responding"
        echo "     $(curl -s http://$host:$RPC_PORT/status | grep -o '"network":"[^"]*"' || echo 'Status OK')"
    else
        print_error "RPC (${RPC_PORT}): ❌ Not accessible"
        echo "     Check firewall rules and ensure pokerchaind is running"
        all_success=false
    fi
    
    # Test API endpoint
    print_info "Testing API endpoint (port $API_PORT)..."
    if curl -s --max-time 5 "http://$host:$API_PORT/cosmos/base/tendermint/v1beta1/node_info" > /dev/null 2>&1; then
        print_success "API (${API_PORT}): ✅ Responding"
    else
        print_warning "API (${API_PORT}): ⚠️  Not accessible or not enabled"
        echo "     This may be normal if API is disabled in app.toml"
    fi
    
    # Test P2P port (just check if port is open)
    print_info "Testing P2P endpoint (port $P2P_PORT)..."
    if timeout 3 bash -c "echo > /dev/tcp/$host/$P2P_PORT" 2>/dev/null; then
        print_success "P2P (${P2P_PORT}): ✅ Port is open"
    else
        print_warning "P2P (${P2P_PORT}): ⚠️  Cannot verify (may require peer connection)"
    fi
    
    # Test gRPC port
    print_info "Testing gRPC endpoint (port $GRPC_PORT)..."
    if timeout 3 bash -c "echo > /dev/tcp/$host/$GRPC_PORT" 2>/dev/null; then
        print_success "gRPC (${GRPC_PORT}): ✅ Port is open"
    else
        print_warning "gRPC (${GRPC_PORT}): ⚠️  Not accessible or not enabled"
    fi
    
    echo ""
    if [ "$all_success" = true ]; then
        print_success "All critical endpoints are publicly accessible!"
    else
        print_warning "Some endpoints are not accessible. Review the results above."
    fi
    
    echo ""
    echo "🌐 Public Endpoints:"
    echo "   RPC:      http://$host:$RPC_PORT"
    echo "   API:      http://$host:$API_PORT"
    echo "   gRPC:     $host:$GRPC_PORT"
    echo "   P2P:      $host:$P2P_PORT"
    echo ""
    
    return 0
}

# Stop pokerchaind if running
stop_pokerchaind() {
    print_info "Checking if pokerchaind is running..."
    
    # Check if systemd service exists and is running
    if systemctl list-units --full -all | grep -q "pokerchaind.service"; then
        if systemctl is-active --quiet pokerchaind; then
            print_warning "pokerchaind service is running. Stopping..."
            sudo systemctl stop pokerchaind
            sleep 2
            print_success "pokerchaind service stopped"
        else
            print_info "pokerchaind service exists but is not running"
        fi
        
        # Disable the service to prevent auto-start during setup
        if systemctl is-enabled --quiet pokerchaind 2>/dev/null; then
            print_info "Disabling pokerchaind service temporarily..."
            sudo systemctl disable pokerchaind
        fi
    fi
    
    # Check for any pokerchaind processes
    if pgrep -x pokerchaind > /dev/null; then
        print_warning "Found running pokerchaind processes. Stopping..."
        pkill -TERM pokerchaind
        sleep 3
        
        # Force kill if still running
        if pgrep -x pokerchaind > /dev/null; then
            print_warning "Processes still running. Force stopping..."
            pkill -KILL pokerchaind
            sleep 1
        fi
        
        print_success "All pokerchaind processes stopped"
    else
        print_success "No pokerchaind processes running"
    fi
}

# Set secure file permissions
set_file_permissions() {
    print_info "Setting secure file permissions..."
    
    # Config directory - readable by owner and group
    chmod 755 "$HOME_DIR/config"
    chmod 755 "$HOME_DIR/data"
    
    # Genesis file - readable by all (public data)
    if [ -f "$HOME_DIR/config/genesis.json" ]; then
        chmod 644 "$HOME_DIR/config/genesis.json"
        print_success "genesis.json: 644 (rw-r--r--)"
    fi
    
    # Config files - readable by owner only (may contain sensitive settings)
    if [ -f "$HOME_DIR/config/config.toml" ]; then
        chmod 600 "$HOME_DIR/config/config.toml"
        print_success "config.toml: 600 (rw-------)"
    fi
    
    if [ -f "$HOME_DIR/config/app.toml" ]; then
        chmod 600 "$HOME_DIR/config/app.toml"
        print_success "app.toml: 600 (rw-------)"
    fi
    
    # Validator keys - MUST be owner-only (highly sensitive)
    if [ -f "$HOME_DIR/config/priv_validator_key.json" ]; then
        chmod 600 "$HOME_DIR/config/priv_validator_key.json"
        print_success "priv_validator_key.json: 600 (rw-------)"
    fi
    
    if [ -f "$HOME_DIR/data/priv_validator_state.json" ]; then
        chmod 600 "$HOME_DIR/data/priv_validator_state.json"
        print_success "priv_validator_state.json: 600 (rw-------)"
    fi
    
    # Node key - owner-only
    if [ -f "$HOME_DIR/config/node_key.json" ]; then
        chmod 600 "$HOME_DIR/config/node_key.json"
        print_success "node_key.json: 600 (rw-------)"
    fi
    
    # Client config - readable by owner only
    if [ -f "$HOME_DIR/config/client.toml" ]; then
        chmod 600 "$HOME_DIR/config/client.toml"
        print_success "client.toml: 600 (rw-------)"
    fi
    
    # Data directory files
    if [ -d "$HOME_DIR/data" ]; then
        chmod 700 "$HOME_DIR/data"
        print_success "data directory: 700 (rwx------)"
    fi
    
    # WAL directory if it exists
    if [ -d "$HOME_DIR/data/cs.wal" ]; then
        chmod 700 "$HOME_DIR/data/cs.wal"
    fi
    
    print_success "All file permissions set securely"
}

# Verify file permissions
verify_file_permissions() {
    print_info "Verifying file permissions..."
    local issues=0
    
    # Check critical files
    if [ -f "$HOME_DIR/config/priv_validator_key.json" ]; then
        local perms=$(stat -c "%a" "$HOME_DIR/config/priv_validator_key.json" 2>/dev/null || stat -f "%A" "$HOME_DIR/config/priv_validator_key.json" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            print_error "priv_validator_key.json has incorrect permissions: $perms (should be 600)"
            issues=$((issues + 1))
        fi
    fi
    
    if [ -f "$HOME_DIR/data/priv_validator_state.json" ]; then
        local perms=$(stat -c "%a" "$HOME_DIR/data/priv_validator_state.json" 2>/dev/null || stat -f "%A" "$HOME_DIR/data/priv_validator_state.json" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            print_error "priv_validator_state.json has incorrect permissions: $perms (should be 600)"
            issues=$((issues + 1))
        fi
    fi
    
    if [ $issues -eq 0 ]; then
        print_success "All permissions verified correctly"
    else
        print_warning "Found $issues permission issues"
    fi
    
    return $issues
}

# Backup existing configuration
backup_config() {
    if [ -d "$HOME_DIR" ]; then
        local backup_dir="$HOME_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Creating backup at $backup_dir..."
        cp -r "$HOME_DIR" "$backup_dir"
        print_success "Backup created: $backup_dir"
        echo "     Restore with: rm -rf $HOME_DIR && mv $backup_dir $HOME_DIR"
    fi
}

# Display current system status
check_system_status() {
    echo ""
    echo "🔍 System Status Check"
    echo "====================="
    echo ""
    
    # Check if pokerchaind binary exists
    if command -v pokerchaind &> /dev/null; then
        print_success "pokerchaind binary: $(which pokerchaind)"
        echo "     Version: $(pokerchaind version 2>/dev/null || echo 'unknown')"
    else
        print_warning "pokerchaind binary: NOT FOUND"
    fi
    
    # Check if systemd service exists
    if systemctl list-units --full -all | grep -q "pokerchaind.service"; then
        if systemctl is-active --quiet pokerchaind; then
            print_warning "pokerchaind service: RUNNING (will be stopped)"
        else
            print_info "pokerchaind service: EXISTS but not running"
        fi
        if systemctl is-enabled --quiet pokerchaind 2>/dev/null; then
            print_info "pokerchaind service: ENABLED (auto-start on boot)"
        fi
    else
        print_info "pokerchaind service: NOT INSTALLED"
    fi
    
    # Check for running processes
    if pgrep -x pokerchaind > /dev/null; then
        local count=$(pgrep -x pokerchaind | wc -l)
        print_warning "pokerchaind processes: $count running (will be stopped)"
    else
        print_success "pokerchaind processes: NONE running"
    fi
    
    # Check if home directory exists
    if [ -d "$HOME_DIR" ]; then
        print_info "Chain home: $HOME_DIR (EXISTS)"
        if [ -f "$HOME_DIR/config/genesis.json" ]; then
            print_info "  └─ genesis.json: FOUND"
        fi
        if [ -f "$HOME_DIR/config/priv_validator_key.json" ]; then
            print_info "  └─ validator key: FOUND"
        fi
    else
        print_info "Chain home: $HOME_DIR (NOT FOUND - will be created)"
    fi
    
    echo ""
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
    
    # Get GOBIN path
    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    
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
Environment="PATH=$gobin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin"

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
    
    # Ensure we're in the correct directory
    ensure_project_directory
    
    # Check Go environment
    check_go_environment
    
    # Ask if user wants to build first
    read -p "Build pokerchaind from source before setup? (y/n): " BUILD_FIRST
    if [[ $BUILD_FIRST == "y" ]]; then
        build_pokerchaind
    fi
    
    # Check current system status
    check_system_status
    
    # Check if pokerchaind is installed
    if ! command -v pokerchaind &> /dev/null; then
        print_error "pokerchaind not found. Please install it first."
        echo ""
        echo "Options:"
        echo "  1. Run: make install (from project directory)"
        echo "  2. Run: ./install-from-source.sh"
        echo "  3. Ensure \$GOPATH/bin or \$GOBIN is in your PATH"
        exit 1
    fi
    
    print_success "pokerchaind found: $(which pokerchaind)"
    
    # Check if pokerchaind is already running
    stop_pokerchaind
    
    # Check required files
    check_required_files
    
    # Initialize node if not already done
    if [ -d "$HOME_DIR" ]; then
        read -p "⚠️  $HOME_DIR already exists. Remove and reinitialize? (y/n): " REINIT
        if [[ $REINIT == "y" ]]; then
            # Offer to backup first
            read -p "Create backup before removing? (recommended) (y/n): " DO_BACKUP
            if [[ $DO_BACKUP == "y" ]]; then
                backup_config
            fi
            
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
    validate_genesis || {
        print_error "Genesis validation failed. Please check your genesis.json file."
        exit 1
    }
    
    # Copy app.toml
    print_info "Copying app.toml..."
    cp app.toml "$HOME_DIR/config/app.toml"
    print_success "app.toml copied"
    
    # Copy config.toml
    print_info "Copying config.toml..."
    cp config.toml "$HOME_DIR/config/config.toml"
    print_success "config.toml copied"
    
    # Set secure file permissions
    set_file_permissions
    
    # Verify permissions were set correctly
    echo ""
    verify_file_permissions
    
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
        
        # Ask if user wants to start now
        echo ""
        read -p "Start pokerchaind service now? (y/n): " START_NOW
        if [[ $START_NOW == "y" ]]; then
            print_info "Enabling and starting pokerchaind service..."
            sudo systemctl enable pokerchaind
            sudo systemctl start pokerchaind
            sleep 3
            
            # Check status
            if sudo systemctl is-active --quiet pokerchaind; then
                print_success "pokerchaind service is running!"
                echo ""
                sudo systemctl status pokerchaind --no-pager -l
            else
                print_error "pokerchaind service failed to start"
                echo "Check logs with: journalctl -u pokerchaind -n 50"
            fi
        fi
    fi
    
    echo ""
    print_success "Local genesis node setup complete!"
    
    # Verify local node if service was started
    if systemctl list-units --full -all | grep -q "pokerchaind.service"; then
        if systemctl is-active --quiet pokerchaind; then
            echo ""
            verify_local_node
        fi
    fi
    echo ""
    echo "📋 Security Summary:"
    echo "  ✅ pokerchaind processes stopped"
    echo "  ✅ File permissions set to least privilege:"
    echo "     - genesis.json: 644 (public readable)"
    echo "     - config.toml: 600 (owner only)"
    echo "     - app.toml: 600 (owner only)"
    echo "     - validator keys: 600 (owner only)"
    echo "     - data directory: 700 (owner only)"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Start the node: pokerchaind start --minimum-gas-prices=\"0.01stake\""
    echo "     OR use systemd: sudo systemctl enable pokerchaind"
    echo "                     sudo systemctl start pokerchaind"
    echo ""
    echo "  2. Get node info: ./get-node-info.sh"
    echo ""
    echo "  3. Check status: curl http://localhost:${RPC_PORT}/status"
    echo ""
    echo "  4. View logs: journalctl -u pokerchaind -f"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  If pokerchaind command not found:"
    echo "    - Ensure \$GOPATH/bin is in your PATH"
    echo "    - Run: export PATH=\"\$HOME/go/bin:\$PATH\""
    echo "    - Add to ~/.bashrc for persistence"
    echo ""
    echo "  If genesis validation fails:"
    echo "    - Check genesis.json format"
    echo "    - Ensure chain-id matches: $CHAIN_ID"
    echo "    - Validation will also occur at startup"
}

# Deploy to remote server
deploy_to_remote() {
    local remote_user=$1
    local remote_host=$2
    
    print_info "Deploying to remote server: $remote_user@$remote_host"
    
    # Ensure we're in the project directory
    ensure_project_directory
    
    # Check required files
    check_required_files
    
    # Ask if user wants to build first
    read -p "Build pokerchaind from source before deployment? (y/n): " BUILD_FIRST
    if [[ $BUILD_FIRST == "y" ]]; then
        build_pokerchaind
    fi
    
    # Verify pokerchaind binary exists locally
    local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    if [ ! -f "$gobin/pokerchaind" ]; then
        print_error "pokerchaind binary not found at $gobin/pokerchaind"
        echo "Please build it first with: make install"
        exit 1
    fi
    
    print_success "Found local pokerchaind binary: $gobin/pokerchaind"
    
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
    
    # Stop remote pokerchaind if running
    print_info "Stopping remote pokerchaind service..."
    ssh "$remote_user@$remote_host" "
        if systemctl list-units --full -all | grep -q 'pokerchaind.service'; then
            sudo systemctl stop pokerchaind 2>/dev/null || true
            echo 'Service stopped'
        fi
        pkill pokerchaind 2>/dev/null || true
    "
    print_success "Remote pokerchaind stopped"
    
    # Create remote directory
    print_info "Creating remote directories..."
    ssh "$remote_user@$remote_host" "mkdir -p ~/.pokerchain/config ~/.pokerchain/data"
    
    # Get remote GOBIN path
    print_info "Determining remote Go bin directory..."
    REMOTE_GOBIN=$(ssh "$remote_user@$remote_host" "echo \${GOBIN:-\${GOPATH:-\$HOME/go}/bin}")
    print_success "Remote Go bin: $REMOTE_GOBIN"
    
    # Create remote GOBIN directory if it doesn't exist
    ssh "$remote_user@$remote_host" "mkdir -p $REMOTE_GOBIN"
    
    # Copy pokerchaind binary to remote server
    print_info "Copying pokerchaind binary to remote server..."
    scp "$gobin/pokerchaind" "$remote_user@$remote_host:$REMOTE_GOBIN/"
    ssh "$remote_user@$remote_host" "chmod +x $REMOTE_GOBIN/pokerchaind"
    print_success "Binary copied to $REMOTE_GOBIN/pokerchaind"
    
    # Verify remote binary
    print_info "Verifying remote binary..."
    REMOTE_VERSION=$(ssh "$remote_user@$remote_host" "$REMOTE_GOBIN/pokerchaind version 2>/dev/null || echo 'unknown'")
    print_success "Remote pokerchaind version: $REMOTE_VERSION"
    
    # Copy required files
    print_info "Copying configuration files to remote server..."
    scp genesis.json "$remote_user@$remote_host:~/.pokerchain/config/"
    scp app.toml "$remote_user@$remote_host:~/.pokerchain/config/"
    scp config.toml "$remote_user@$remote_host:~/.pokerchain/config/"
    
    # Copy setup scripts
    if [ -f "get-node-info.sh" ]; then
        scp get-node-info.sh "$remote_user@$remote_host:~/"
        ssh "$remote_user@$remote_host" "chmod +x ~/get-node-info.sh"
    fi
    
    print_success "Files copied to remote server"
    
    # Create remote setup script
    print_info "Creating remote setup script..."
    
    cat > /tmp/remote-setup.sh <<REMOTE_SCRIPT
#!/bin/bash
set -e

echo "🔧 Setting up genesis node on remote server..."

# Configuration
REMOTE_GOBIN="$REMOTE_GOBIN"
CHAIN_ID="$CHAIN_ID"
MONIKER="$MONIKER"

# Verify pokerchaind binary
if [ ! -f "\$REMOTE_GOBIN/pokerchaind" ]; then
    echo "❌ pokerchaind binary not found at \$REMOTE_GOBIN/pokerchaind"
    exit 1
fi

echo "✅ pokerchaind binary found: \$REMOTE_GOBIN/pokerchaind"
echo "   Version: \$(\$REMOTE_GOBIN/pokerchaind version)"

# Add GOBIN to PATH
export PATH="\$REMOTE_GOBIN:\$PATH"

# Initialize node if needed
if [ ! -d ~/.pokerchain/config ]; then
    echo "🔧 Initializing node..."
    pokerchaind init "\$MONIKER" --chain-id "\$CHAIN_ID"
    echo "✅ Node initialized"
fi

# Detect genesis validation command
detect_genesis_cmd() {
    if pokerchaind genesis validate --help &>/dev/null; then
        echo "genesis validate"
    elif pokerchaind validate-genesis --help &>/dev/null; then
        echo "validate-genesis"
    else
        echo ""
    fi
}

# Validate genesis
echo "✅ Validating genesis..."
VALIDATE_CMD=\$(detect_genesis_cmd)

if [ -n "\$VALIDATE_CMD" ]; then
    cd ~/.pokerchain/config
    if pokerchaind \$VALIDATE_CMD; then
        echo "✅ Genesis file is valid"
    else
        echo "❌ Genesis validation failed"
        exit 1
    fi
    cd ~
else
    echo "⚠️  Genesis validation command not available"
    echo "    Skipping validation (will verify during startup)"
fi

# Set secure file permissions
echo "🔒 Setting secure file permissions..."
chmod 755 ~/.pokerchain/config
chmod 755 ~/.pokerchain/data

# Genesis - public readable
if [ -f ~/.pokerchain/config/genesis.json ]; then
    chmod 644 ~/.pokerchain/config/genesis.json
fi

# Config files - owner only
if [ -f ~/.pokerchain/config/config.toml ]; then
    chmod 600 ~/.pokerchain/config/config.toml
fi

if [ -f ~/.pokerchain/config/app.toml ]; then
    chmod 600 ~/.pokerchain/config/app.toml
fi

# Validator keys - owner only (CRITICAL)
if [ -f ~/.pokerchain/config/priv_validator_key.json ]; then
    chmod 600 ~/.pokerchain/config/priv_validator_key.json
fi

if [ -f ~/.pokerchain/data/priv_validator_state.json ]; then
    chmod 600 ~/.pokerchain/data/priv_validator_state.json
fi

if [ -f ~/.pokerchain/config/node_key.json ]; then
    chmod 600 ~/.pokerchain/config/node_key.json
fi

if [ -d ~/.pokerchain/data ]; then
    chmod 700 ~/.pokerchain/data
fi

echo "✅ File permissions set"

# Setup UFW firewall
echo "🔒 Setting up firewall..."
if ! command -v ufw &> /dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y ufw
fi

# Configure firewall rules
echo "🔧 Configuring firewall rules..."
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 26656/tcp comment 'Cosmos P2P'
sudo ufw allow 26657/tcp comment 'Cosmos RPC'
sudo ufw allow 1317/tcp comment 'Cosmos API'
sudo ufw allow 9090/tcp comment 'Cosmos gRPC'
sudo ufw allow 9091/tcp comment 'Cosmos gRPC-Web'
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
User=\$(whoami)
ExecStart=\$REMOTE_GOBIN/pokerchaind start --minimum-gas-prices="0.01stake"
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=pokerchaind"
Environment="DAEMON_HOME=\$HOME/.pokerchain"
Environment="PATH=\$REMOTE_GOBIN:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo "✅ Systemd service created"

# Enable and start the service
echo "🚀 Enabling and starting pokerchaind service..."
sudo systemctl enable pokerchaind
sudo systemctl restart pokerchaind

# Wait for service to start
sleep 5

# Check service status
if sudo systemctl is-active --quiet pokerchaind; then
    echo "✅ pokerchaind service is running!"
    sudo systemctl status pokerchaind --no-pager -l
else
    echo "❌ pokerchaind service failed to start"
    echo "Check logs with: journalctl -u pokerchaind -n 50"
    exit 1
fi

echo ""
echo "✅ Remote setup complete!"
echo ""
echo "📋 Service Management:"
echo "  sudo systemctl status pokerchaind    # Check status"
echo "  sudo systemctl restart pokerchaind   # Restart service"
echo "  journalctl -u pokerchaind -f         # View logs"
echo ""
echo "🔍 Verify installation:"
echo "  pokerchaind version"
echo "  curl http://localhost:26657/status"
REMOTE_SCRIPT
    
    # Copy and execute remote setup script
    print_info "Executing remote setup script..."
    scp /tmp/remote-setup.sh "$remote_user@$remote_host:~/remote-setup.sh"
    ssh "$remote_user@$remote_host" "chmod +x ~/remote-setup.sh && ~/remote-setup.sh"
    
    # Clean up
    rm /tmp/remote-setup.sh
    
    print_success "Remote deployment complete!"
    
    # Verify public endpoints
    echo ""
    read -p "Verify public endpoint accessibility? (y/n): " VERIFY_ENDPOINTS
    if [[ $VERIFY_ENDPOINTS == "y" ]]; then
        print_info "Waiting 10 seconds for node to fully start..."
        sleep 10
        verify_public_endpoints "$remote_host"
    fi
    
    echo ""
    echo "📋 Remote node is ready!"
    echo ""
    echo "🌐 Access your node:"
    echo "  ssh $remote_user@$remote_host"
    echo ""
    echo "🔧 Manage the service:"
    echo "  sudo systemctl status pokerchaind     # Check status"
    echo "  sudo systemctl restart pokerchaind    # Restart"
    echo "  sudo systemctl stop pokerchaind       # Stop"
    echo "  journalctl -u pokerchaind -f          # View logs"
    echo ""
    echo "🌐 Public Endpoints:"
    echo "  RPC:  http://$remote_host:$RPC_PORT/status"
    echo "  API:  http://$remote_host:$API_PORT/cosmos/base/tendermint/v1beta1/node_info"
    echo ""
    echo "📊 Quick checks:"
    echo "  curl http://$remote_host:$RPC_PORT/status"
    echo "  curl http://$remote_host:$API_PORT/cosmos/base/tendermint/v1beta1/node_info"
}

# Verify local node
verify_local_node() {
    print_info "Verifying local node..."
    
    # Check if service is running
    if systemctl is-active --quiet pokerchaind; then
        print_success "pokerchaind service is running"
        
        # Wait a moment for RPC to be ready
        sleep 3
        
        # Check localhost endpoints
        echo ""
        print_info "Testing localhost endpoints..."
        
        if curl -s --max-time 5 http://localhost:$RPC_PORT/status > /dev/null 2>&1; then
            print_success "RPC endpoint responding on localhost:$RPC_PORT"
            echo ""
            echo "Node status:"
            curl -s http://localhost:$RPC_PORT/status | grep -o '"network":"[^"]*"\|"latest_block_height":"[^"]*"' || true
        else
            print_warning "RPC endpoint not yet responding (node may still be starting)"
        fi
    elif pgrep -x pokerchaind > /dev/null; then
        print_success "pokerchaind is running (not as service)"
    else
        print_warning "pokerchaind is not running"
        echo "Start it with: sudo systemctl start pokerchaind"
        echo "Or manually: pokerchaind start --minimum-gas-prices=\"0.01stake\""
    fi
}

# Main menu
show_menu() {
    # Show environment info at startup
    echo ""
    echo "🔍 Environment Information:"
    echo "=========================="
    echo "Current directory: $(pwd)"
    echo "Script directory:  $PROJECT_DIR"
    echo "Home directory:    $HOME"
    echo "Chain home:        $HOME_DIR"
    if command -v go &> /dev/null; then
        echo "Go version:        $(go version | awk '{print $3}')"
        echo "GOPATH:            ${GOPATH:-$HOME/go}"
        echo "GOBIN:             ${GOBIN:-${GOPATH:-$HOME/go}/bin}"
    else
        echo "Go:                ⚠️  NOT FOUND"
    fi
    if command -v pokerchaind &> /dev/null; then
        echo "pokerchaind:       ✅ $(which pokerchaind)"
    else
        echo "pokerchaind:       ⚠️  NOT FOUND"
    fi
    echo ""
    
    echo "What would you like to do?"
    echo ""
    echo "1) Setup genesis node locally"
    echo "2) Deploy genesis node to node1.block52.xyz"
    echo "3) Verify remote node endpoints"
    echo "4) Show network information"
    echo "5) Exit"
    echo ""
    read -p "Choose option (1-5): " CHOICE
    
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
            read -p "Enter hostname to verify (default: node1.block52.xyz): " VERIFY_HOST
            VERIFY_HOST=${VERIFY_HOST:-node1.block52.xyz}
            verify_public_endpoints "$VERIFY_HOST"
            ;;
        4)
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
        5)
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