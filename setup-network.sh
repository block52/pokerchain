#!/bin/bash

# Pokerchain Network Setup Menu
# Main orchestrator script for setting up different types of nodes

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print header
print_header() {
    clear
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🎲 Pokerchain Network Setup 🎲"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Print menu
show_menu() {
    print_header
    echo ""
    echo "Select the type of node you want to set up:"
    echo ""
    echo -e "${GREEN}1)${NC} Genesis Node (node1.block52.xyz)"
    echo "   Sets up the primary network node with genesis configuration"
    echo "   - Creates the initial blockchain state"
    echo "   - Acts as the primary validator"
    echo "   - Provides public RPC/API endpoints"
    echo ""
    echo -e "${GREEN}2)${NC} Sync Node (local read-only node)"
    echo "   Sets up a local node that syncs from the network"
    echo "   - Downloads blockchain data from peers"
    echo "   - Provides local RPC/API access"
    echo "   - Does NOT participate in consensus"
    echo "   - Perfect for development and testing"
    echo ""
    echo -e "${GREEN}3)${NC} Validator Node (additional validator)"
    echo "   Sets up a new validator node to join the network"
    echo "   - Participates in consensus"
    echo "   - Creates and signs blocks"
    echo "   - Requires validator keys"
    echo ""
    echo -e "${GREEN}4)${NC} Verify Network Connectivity"
    echo "   Test connectivity to node1.block52.xyz"
    echo "   - Check RPC/API endpoints"
    echo "   - View network status"
    echo "   - Get node information"
    echo ""
    echo -e "${GREEN}5)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-5]: "
}

# Check if script exists
check_script() {
    local script=$1
    if [ ! -f "$script" ]; then
        echo -e "${YELLOW}⚠️  Warning: $script not found${NC}"
        echo "This script should be in the same directory as setup-network.sh"
        return 1
    fi
    return 0
}

# Setup genesis node
setup_genesis() {
    print_header
    echo ""
    echo "Setting up Genesis Node (node1.block52.xyz)"
    echo ""
    
    if check_script "./setup-genesis-node.sh"; then
        chmod +x ./setup-genesis-node.sh
        ./setup-genesis-node.sh
    else
        echo "Please ensure setup-genesis-node.sh is in the current directory"
        read -p "Press Enter to continue..."
    fi
}

# Setup sync node
setup_sync() {
    print_header
    echo ""
    echo "Setting up Sync Node (local read-only)"
    echo ""
    
    if check_script "./setup-sync-node.sh"; then
        chmod +x ./setup-sync-node.sh
        ./setup-sync-node.sh
    else
        echo "Please ensure setup-sync-node.sh is in the current directory"
        read -p "Press Enter to continue..."
    fi
}

# Setup validator node
setup_validator() {
    print_header
    echo ""
    echo "Setting up Validator Node"
    echo ""
    echo "⚠️  Validator node setup requires:"
    echo "   - Existing validator keys"
    echo "   - Proper network configuration"
    echo "   - Coordination with existing validators"
    echo ""
    echo "This feature is coming soon!"
    echo ""
    read -p "Press Enter to continue..."
}

# Verify network connectivity
verify_network() {
    print_header
    echo ""
    echo "Verifying Network Connectivity"
    echo ""
    
    local remote_node="node1.block52.xyz"
    local rpc_port=26657
    local api_port=1317
    
    echo "Testing connection to $remote_node..."
    echo ""
    
    # Test RPC
    echo -n "RPC (port $rpc_port): "
    if curl -s --max-time 5 "http://$remote_node:$rpc_port/status" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
        
        # Get network info
        echo ""
        echo "Network Information:"
        curl -s "http://$remote_node:$rpc_port/status" | jq -r '
            "  Chain ID: " + .result.node_info.network,
            "  Node ID: " + .result.node_info.id,
            "  Latest Block: " + .result.sync_info.latest_block_height,
            "  Catching Up: " + (.result.sync_info.catching_up | tostring)
        ' 2>/dev/null || echo "  (jq not installed - raw data available via curl)"
    else
        echo -e "${YELLOW}❌ Not accessible${NC}"
    fi
    
    echo ""
    echo -n "API (port $api_port): "
    if curl -s --max-time 5 "http://$remote_node:$api_port/cosmos/base/tendermint/v1beta1/node_info" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
    else
        echo -e "${YELLOW}⚠️  Not accessible${NC}"
    fi
    
    echo ""
    echo "Public Endpoints:"
    echo "  RPC:  http://$remote_node:$rpc_port"
    echo "  API:  http://$remote_node:$api_port"
    echo ""
    echo "Test commands:"
    echo "  curl http://$remote_node:$rpc_port/status"
    echo "  curl http://$remote_node:$api_port/cosmos/base/tendermint/v1beta1/node_info"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                setup_genesis
                ;;
            2)
                setup_sync
                ;;
            3)
                setup_validator
                ;;
            4)
                verify_network
                ;;
            5)
                print_header
                echo ""
                echo "Thank you for using Pokerchain Network Setup!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-5.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in curl jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Optional dependencies missing: ${missing_deps[*]}${NC}"
        echo "Install them for better functionality:"
        echo "  sudo apt-get install ${missing_deps[*]}"
        echo ""
        sleep 2
    fi
}

# Run pre-checks and start main loop
check_dependencies
main