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
    echo -e "${GREEN}3)${NC} Remote Sync Node (deploy to remote server)"
    echo "   Deploy a read-only sync node to a remote Linux server"
    echo "   - Builds and uploads binary"
    echo "   - Configures systemd service"
    echo "   - Connects to node1.block52.xyz as peer"
    echo "   - Syncs blockchain data from the network"
    echo ""
    echo -e "${GREEN}4)${NC} Validator Node (additional validator)"
    echo "   Sets up a new validator node to join the network"
    echo "   - Participates in consensus"
    echo "   - Creates and signs blocks"
    echo "   - Requires validator keys"
    echo ""
    echo -e "${GREEN}5)${NC} Start Local Node"
    echo "   Start your local pokerchaind node"
    echo "   - Start via systemd (if configured)"
    echo "   - Start manually if no service"
    echo "   - View sync status and logs"
    echo ""
    echo -e "${GREEN}6)${NC} Verify Network Connectivity"
    echo "   Test connectivity to node1.block52.xyz"
    echo "   - Check RPC/API endpoints"
    echo "   - View network status"
    echo "   - Get node information"
    echo ""
    echo -e "${GREEN}7)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-7]: "
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
    
    if check_script "./deploy-master-node.sh"; then
        chmod +x ./deploy-master-node.sh
        ./deploy-master-node.sh
    else
        echo "Please ensure deploy-master-node.sh is in the current directory"
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

# Setup remote sync node
setup_remote_sync() {
    print_header
    echo ""
    echo "Deploying Remote Sync Node"
    echo ""
    
    if check_script "./deploy-sync-node.sh"; then
        # Get remote host from user
        echo -e "${BLUE}Enter the remote server details:${NC}"
        echo ""
        read -p "Remote host (e.g., node2.example.com or 192.168.1.100): " remote_host
        
        if [ -z "$remote_host" ]; then
            echo -e "${RED}❌ Remote host cannot be empty${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        read -p "Remote user (default: root): " remote_user
        remote_user=${remote_user:-root}
        
        echo ""
        echo "📋 Deployment Configuration:"
        echo "   Remote Host: $remote_host"
        echo "   Remote User: $remote_user"
        echo "   Seed Node: node1.block52.xyz"
        echo ""
        read -p "Continue with deployment? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            chmod +x ./deploy-sync-node.sh
            ./deploy-sync-node.sh "$remote_host" "$remote_user"
        else
            echo "Deployment cancelled."
        fi
    else
        echo "Please ensure deploy-sync-node.sh is in the current directory"
    fi
    
    read -p "Press Enter to continue..."
}

# Start local node
start_local_node() {
    print_header
    echo ""
    echo "Starting Local Pokerchaind Node"
    echo ""
    
    local home_dir="$HOME/.pokerchain"
    local rpc_port=26657
    
    # Check if node is initialized
    if [ ! -d "$home_dir" ]; then
        echo -e "${YELLOW}⚠️  Node not initialized${NC}"
        echo ""
        echo "Please set up a node first:"
        echo "  ./setup-network.sh → Option 2 (Sync Node)"
        echo "  OR"
        echo "  ./setup-sync-node.sh"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check if pokerchaind is installed
    if ! command -v pokerchaind &> /dev/null; then
        echo -e "${YELLOW}⚠️  pokerchaind not found in PATH${NC}"
        echo ""
        echo "Please ensure pokerchaind is installed:"
        echo "  make install"
        echo "  OR add to PATH: export PATH=\"\$HOME/go/bin:\$PATH\""
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check if already running
    if pgrep -x pokerchaind > /dev/null; then
        echo -e "${GREEN}✅ pokerchaind is already running${NC}"
        echo ""
        
        # Show status
        if systemctl is-active --quiet pokerchaind 2>/dev/null; then
            echo "Service status:"
            sudo systemctl status pokerchaind --no-pager -l
        fi
        
        echo ""
        echo "Node information:"
        if curl -s --max-time 5 http://localhost:$rpc_port/status > /dev/null 2>&1; then
            curl -s http://localhost:$rpc_port/status | jq -r '
                "  Node ID: " + .result.node_info.id,
                "  Chain ID: " + .result.node_info.network,
                "  Latest Block: " + .result.sync_info.latest_block_height,
                "  Catching Up: " + (.result.sync_info.catching_up | tostring)
            ' 2>/dev/null || echo "  RPC responding (jq not installed)"
        else
            echo "  (Node starting up, RPC not ready yet)"
        fi
        
        echo ""
        echo "Monitor with:"
        if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
            echo "  journalctl -u pokerchaind -f"
        fi
        echo "  curl http://localhost:$rpc_port/status"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    # Try to start via systemd first
    if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
        echo "Starting pokerchaind via systemd..."
        echo ""
        
        sudo systemctl start pokerchaind
        sleep 3
        
        if systemctl is-active --quiet pokerchaind; then
            echo -e "${GREEN}✅ Service started successfully!${NC}"
            echo ""
            sudo systemctl status pokerchaind --no-pager -l
            echo ""
            echo "Monitor logs:"
            echo "  journalctl -u pokerchaind -f"
            echo ""
            
            # Wait a bit and check sync status
            echo "Checking sync status (waiting 5 seconds)..."
            sleep 5
            
            if curl -s --max-time 5 http://localhost:$rpc_port/status > /dev/null 2>&1; then
                echo ""
                curl -s http://localhost:$rpc_port/status | jq -r '
                    "Node Status:",
                    "  Latest Block: " + .result.sync_info.latest_block_height,
                    "  Catching Up: " + (.result.sync_info.catching_up | tostring),
                    "  Network: " + .result.node_info.network
                ' 2>/dev/null || echo "RPC is responding"
            fi
        else
            echo -e "${YELLOW}⚠️  Service failed to start${NC}"
            echo ""
            echo "Check logs for errors:"
            echo "  journalctl -u pokerchaind -n 50"
        fi
    else
        # No systemd service, start manually
        echo "No systemd service found. Start manually?"
        echo ""
        echo "This will start pokerchaind in the foreground."
        echo "Press Ctrl+C to stop when done."
        echo ""
        read -p "Start now? (y/n): " start_manual
        
        if [[ $start_manual =~ ^[Yy]$ ]]; then
            echo ""
            echo "Starting pokerchaind..."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            pokerchaind start --minimum-gas-prices="0.01stake"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Setup validator node
setup_validator() {
    print_header
    echo ""
    echo "Setting up Validator Node"
    echo ""
    
    if check_script "./setup-validator-node.sh"; then
        chmod +x ./setup-validator-node.sh
        ./setup-validator-node.sh
    else
        echo "Please ensure setup-validator-node.sh is in the current directory"
        read -p "Press Enter to continue..."
    fi
}

# Verify network connectivity
verify_network() {
    print_header
    echo ""
    echo "Verifying Network Connectivity & Block Production"
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
        local status_output=$(curl -s "http://$remote_node:$rpc_port/status")
        echo "$status_output" | jq -r '
            "  Chain ID: " + .result.node_info.network,
            "  Node ID: " + .result.node_info.id,
            "  Latest Block: " + .result.sync_info.latest_block_height,
            "  Catching Up: " + (.result.sync_info.catching_up | tostring)
        ' 2>/dev/null || echo "  (jq not installed - raw data available via curl)"
        
        # Test block production
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${BLUE}Testing Block Production...${NC}"
        echo ""
        
        # Get initial block height
        local block1=$(echo "$status_output" | jq -r '.result.sync_info.latest_block_height' 2>/dev/null)
        local time1=$(echo "$status_output" | jq -r '.result.sync_info.latest_block_time' 2>/dev/null)
        
        if [ -n "$block1" ] && [ "$block1" != "null" ]; then
            echo "Initial block height: $block1"
            echo "Block time: $time1"
            echo ""
            echo "Waiting 10 seconds to check if new blocks are produced..."
            
            # Wait 10 seconds
            for i in {10..1}; do
                echo -ne "\rWaiting: $i seconds remaining...  "
                sleep 1
            done
            echo ""
            
            # Get new block height
            local status_output2=$(curl -s "http://$remote_node:$rpc_port/status")
            local block2=$(echo "$status_output2" | jq -r '.result.sync_info.latest_block_height' 2>/dev/null)
            local time2=$(echo "$status_output2" | jq -r '.result.sync_info.latest_block_time' 2>/dev/null)
            
            if [ -n "$block2" ] && [ "$block2" != "null" ]; then
                echo ""
                echo "New block height: $block2"
                echo "Block time: $time2"
                echo ""
                
                local blocks_produced=$((block2 - block1))
                
                if [ $blocks_produced -gt 0 ]; then
                    echo -e "${GREEN}✅ BLOCK PRODUCTION ACTIVE!${NC}"
                    echo -e "${GREEN}   Produced $blocks_produced block(s) in 10 seconds${NC}"
                    local blocks_per_min=$(echo "scale=1; $blocks_produced * 6" | bc 2>/dev/null || echo "~$((blocks_produced * 6))")
                    echo -e "${GREEN}   Rate: ~$blocks_per_min blocks/minute${NC}"
                elif [ $blocks_produced -eq 0 ]; then
                    echo -e "${YELLOW}⚠️  NO NEW BLOCKS PRODUCED${NC}"
                    echo -e "${YELLOW}   Node may be stalled or block time is very slow${NC}"
                    echo ""
                    echo "   Troubleshooting steps:"
                    echo "   1. Check if node is running: ssh node1.block52.xyz 'systemctl status pokerchaind'"
                    echo "   2. Check for errors: ssh node1.block52.xyz 'journalctl -u pokerchaind -n 50'"
                    echo "   3. Verify validators: curl http://$remote_node:$rpc_port/validators"
                else
                    echo -e "${YELLOW}⚠️  Block height decreased (chain may have restarted)${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Could not get updated block height${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Could not parse block height (jq may not be installed)${NC}"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
                setup_remote_sync
                ;;
            4)
                setup_validator
                ;;
            5)
                start_local_node
                ;;
            6)
                verify_network
                ;;
            7)
                print_header
                echo ""
                echo "Thank you for using Pokerchain Network Setup!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-7.${NC}"
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