#!/bin/bash

# Configure Bridge on Remote Node
# Updates bridge configuration in app.toml on a remote validator node
# Uses ALCHEMY_URL from local .env file by default or prompts for input

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default values
DEFAULT_CONTRACT_ADDR="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
DEFAULT_USDC_ADDR="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           Configure Bridge on Remote Node"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Show usage
usage() {
    echo "Usage: $0 <remote-host> [remote-user]"
    echo ""
    echo "Arguments:"
    echo "  remote-host   - Hostname or IP of the remote server"
    echo "  remote-user   - SSH user (default: root)"
    echo ""
    echo "Examples:"
    echo "  $0 node1.block52.xyz"
    echo "  $0 192.168.1.100 ubuntu"
    echo ""
    echo "This script will:"
    echo "  1. Read ALCHEMY_URL from local .env file (or prompt if not found)"
    echo "  2. Add/update bridge configuration in remote app.toml"
    echo "  3. Optionally restart the node to apply changes"
    echo ""
}

# Load environment variables from .env
load_env() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        if [ -n "$ALCHEMY_URL" ]; then
            echo -e "${GREEN}✓ Found ALCHEMY_URL in .env${NC}"
            return 0
        fi
    fi
    return 1
}

# Get RPC URL from user or .env
get_rpc_url() {
    local rpc_url=""
    
    if load_env; then
        rpc_url="$ALCHEMY_URL"
        echo "  Using: ${rpc_url:0:60}..."
        echo ""
        read -p "Use this URL? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$rpc_url"
            return 0
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Enter Base/Ethereum RPC URL:${NC}"
    echo "Example: https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
    echo ""
    read -p "RPC URL: " rpc_url
    
    if [ -z "$rpc_url" ]; then
        echo -e "${RED}❌ RPC URL is required${NC}"
        exit 1
    fi
    
    echo "$rpc_url"
}

# Check if bridge config exists in app.toml
check_bridge_config() {
    local remote_host=$1
    local remote_user=$2
    
    if ssh "$remote_user@$remote_host" "grep -q '\[bridge\]' ~/.pokerchain/config/app.toml 2>/dev/null"; then
        return 0
    else
        return 1
    fi
}

# Add bridge configuration to app.toml
add_bridge_config() {
    local remote_host=$1
    local remote_user=$2
    local rpc_url=$3
    local contract_addr=$4
    local usdc_addr=$5
    
    echo ""
    echo "Adding bridge configuration to app.toml..."
    
    ssh "$remote_user@$remote_host" "cat >> ~/.pokerchain/config/app.toml << 'EOFBRIDGE'

###############################################################################
###                          Bridge Configuration                           ###
###############################################################################

[bridge]
# Enable the bridge deposit verification
enabled = true

# Ethereum/Base RPC URL for verifying deposits
ethereum_rpc_url = \"$rpc_url\"

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
    
    echo -e "${GREEN}✅ Bridge configuration added${NC}"
}

# Update existing bridge configuration
update_bridge_config() {
    local remote_host=$1
    local remote_user=$2
    local rpc_url=$3
    
    echo ""
    echo "Updating bridge configuration in app.toml..."
    
    # Escape special characters for sed
    local escaped_url=$(echo "$rpc_url" | sed 's/[&/\]/\\&/g')
    
    ssh "$remote_user@$remote_host" "
        # Backup app.toml
        cp ~/.pokerchain/config/app.toml ~/.pokerchain/config/app.toml.backup.\$(date +%Y%m%d_%H%M%S)
        
        # Update ethereum_rpc_url
        sed -i 's|ethereum_rpc_url = .*|ethereum_rpc_url = \"$escaped_url\"|' ~/.pokerchain/config/app.toml
        
        # Update enabled flag if it exists
        sed -i 's|^enabled = false|enabled = true|' ~/.pokerchain/config/app.toml
    "
    
    echo -e "${GREEN}✅ Bridge configuration updated${NC}"
}

# Verify configuration
verify_config() {
    local remote_host=$1
    local remote_user=$2
    
    echo ""
    echo "Verifying bridge configuration..."
    echo ""
    
    ssh "$remote_user@$remote_host" "grep -A10 '\[bridge\]' ~/.pokerchain/config/app.toml"
    
    echo ""
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        print_header
        echo ""
        usage
        exit 1
    fi
    
    local remote_host=$1
    local remote_user=${2:-root}
    
    print_header
    echo ""
    
    # Test SSH connection
    echo "Testing SSH connection to $remote_user@$remote_host..."
    if ! ssh -o ConnectTimeout=10 "$remote_user@$remote_host" "echo 'Connection successful'" > /dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to $remote_user@$remote_host${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ SSH connection successful${NC}"
    echo ""
    
    # Get RPC URL
    echo "Bridge Configuration:"
    echo ""
    local rpc_url=$(get_rpc_url)
    local contract_addr="$DEFAULT_CONTRACT_ADDR"
    local usdc_addr="$DEFAULT_USDC_ADDR"
    
    echo ""
    echo "Configuration to apply:"
    echo "  RPC URL: ${rpc_url:0:60}..."
    echo "  Deposit Contract: $contract_addr"
    echo "  USDC Contract: $usdc_addr"
    echo ""
    
    read -p "Continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    # Check if bridge config already exists
    if check_bridge_config "$remote_host" "$remote_user"; then
        echo ""
        echo -e "${YELLOW}⚠️  Bridge configuration already exists${NC}"
        read -p "Update existing configuration? (y/n): " update_confirm
        if [[ "$update_confirm" =~ ^[Yy]$ ]]; then
            update_bridge_config "$remote_host" "$remote_user" "$rpc_url"
        else
            echo "Skipping update."
            exit 0
        fi
    else
        add_bridge_config "$remote_host" "$remote_user" "$rpc_url" "$contract_addr" "$usdc_addr"
    fi
    
    # Verify
    verify_config "$remote_host" "$remote_user"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Bridge configuration complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  NOTE: You need to restart pokerchaind for changes to take effect${NC}"
    echo ""
    read -p "Restart node now? (y/n): " restart_confirm
    if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Restarting pokerchaind..."
        ssh "$remote_user@$remote_host" "systemctl restart pokerchaind"
        echo -e "${GREEN}✅ Node restarted${NC}"
        echo ""
        echo "Checking status..."
        sleep 3
        ssh "$remote_user@$remote_host" "systemctl status pokerchaind | head -20"
    else
        echo ""
        echo "Remember to restart the node manually:"
        echo "  ssh $remote_user@$remote_host 'systemctl restart pokerchaind'"
    fi
    
    echo ""
    echo -e "${GREEN}Done!${NC}"
    echo ""
}

# Run main
main "$@"
