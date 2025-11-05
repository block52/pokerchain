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
    echo -e "${GREEN}2)${NC} Run Local Developer Node (local readonly sync)"
    echo "   Runs a local developer node that syncs from the network (read-only)"
    echo "   - Uses run-dev-node.sh for robust, repeatable setup"
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
    echo -e "${GREEN}5)${NC} Verify Network Connectivity"
    echo "   Test connectivity to node1.block52.xyz"
    echo "   - Check RPC/API endpoints"
    echo "   - View network status"
    echo "   - Get node information"
    echo ""
    echo -e "${GREEN}6)${NC} Setup Firewall"
    echo "   Configure UFW firewall on remote server"
    echo "   - Allow SSH, P2P, RPC, API, gRPC ports"
    echo "   - Block all other incoming connections"
    echo "   - Secure your validator node"
    echo ""
    echo -e "${GREEN}7)${NC} Setup NGINX & SSL"
    echo "   Configure NGINX reverse proxy with SSL certificates"
    echo "   - Install NGINX and Certbot"
    echo "   - Configure HTTPS for REST API and gRPC"
    echo "   - Automatic SSL certificate from Let's Encrypt"
    echo "   - Auto-renewal configured"
    echo ""
    echo -e "${GREEN}8)${NC} Local Multi-Node Testnet"
    echo "   Run 3 nodes on your local machine"
    echo "   - Different ports for each node"
    echo "   - Easy terminal switching"
    echo "   - Perfect for development"
    echo ""
    echo -e "${GREEN}9)${NC} Setup Production Nodes"
    echo "   Generate production node configurations"
    echo "   - Creates configs in ./production/nodeX/"
    echo "   - Ready for SSH deployment"
    echo "   - Connects to existing network"
    echo ""
    echo -e "${GREEN}10)${NC} Push New Binary Version"
    echo "   Check remote version/hash, push new binary from /build via SSH"
    echo ""
    echo -e "${GREEN}11)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-11]: "
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


# Run local developer node (option 2)
run_local_dev_node() {
    print_header
    echo ""
    echo "Running Local Developer Node (local readonly sync)"
    echo ""
    if check_script "./run-dev-node.sh"; then
        chmod +x ./run-dev-node.sh
        ./run-dev-node.sh
    else
        echo "Please ensure run-dev-node.sh is in the current directory"
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
            echo -e "${YELLOW}❌ Remote host cannot be empty${NC}"
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

    read -p "Enter node to check (default: node1.block52.xyz): " remote_node
    remote_node=${remote_node:-node1.block52.xyz}

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

# Setup firewall
setup_firewall() {
    print_header
    echo ""
    echo "🔥 Setting up Firewall on Remote Server"
    echo ""
    
    if check_script "./setup-firewall.sh"; then
        # Get remote host from user
        echo -e "${BLUE}Enter the remote server details:${NC}"
        echo ""
        read -p "Remote host (e.g., node1.block52.xyz or 192.168.1.100): " remote_host
        
        if [ -z "$remote_host" ]; then
            echo -e "${YELLOW}❌ Remote host cannot be empty${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        read -p "Remote user (default: root): " remote_user
        remote_user=${remote_user:-root}
        
        echo ""
        echo "📋 Firewall Configuration:"
        echo "   Remote Host: $remote_host"
        echo "   Remote User: $remote_user"
        echo ""
        echo "The following ports will be allowed:"
        echo "   • 22    - SSH (management)"
        echo "   • 26656 - Tendermint P2P (peer connections)"
        echo "   • 26657 - Tendermint RPC (queries)"
        echo "   • 1317  - Cosmos REST API (client access)"
        echo "   • 9090  - gRPC (client access)"
        echo "   • 9091  - gRPC-web (client access)"
        echo ""
        echo "⚠️  All other incoming connections will be blocked!"
        echo ""
        read -p "Continue with firewall setup? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            chmod +x ./setup-firewall.sh
            ./setup-firewall.sh "$remote_host" "$remote_user"
        else
            echo "Firewall setup cancelled."
        fi
    else
        echo "Please ensure setup-firewall.sh is in the current directory"
    fi
    
    read -p "Press Enter to continue..."
}

# Setup NGINX & SSL
setup_nginx() {
    print_header
    echo ""
    echo "🌐 Setting up NGINX & SSL on Remote Server"
    echo ""
    
    if check_script "./setup-nginx.sh"; then
        # Get domain and remote host from user
        echo -e "${BLUE}Enter the server details:${NC}"
        echo ""
        read -p "Domain name (e.g., block52.xyz): " domain
        
        if [ -z "$domain" ]; then
            echo -e "${YELLOW}❌ Domain cannot be empty${NC}"
            read -p "Press Enter to continue..."
            return
        fi
        
        read -p "Remote host (default: $domain): " remote_host
        remote_host=${remote_host:-$domain}
        
        read -p "Remote user (default: root): " remote_user
        remote_user=${remote_user:-root}
        
        echo ""
        echo "📋 NGINX & SSL Configuration:"
        echo "   Domain:      $domain"
        echo "   Remote Host: $remote_host"
        echo "   Remote User: $remote_user"
        echo "   Admin Email: admin@$domain"
        echo ""
        echo "Services to be configured:"
        echo "   • NGINX reverse proxy"
        echo "   • HTTPS for REST API (port 1317 → 443)"
        echo "   • HTTPS for gRPC (port 9090 → 9443)"
        echo "   • SSL certificate via Let's Encrypt"
        echo "   • Automatic certificate renewal"
        echo ""
        echo "⚠️  Requirements:"
        echo "   • Domain must point to the server's IP"
        echo "   • Ports 80 and 443 must be accessible"
        echo "   • pokerchaind must be running on the server"
        echo ""
        read -p "Continue with NGINX setup? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            chmod +x ./setup-nginx.sh
            ./setup-nginx.sh "$domain" "$remote_host" "$remote_user"
        else
            echo "NGINX setup cancelled."
        fi
    else
        echo "Please ensure setup-nginx.sh is in the current directory"
    fi
    
    read -p "Press Enter to continue..."
}

# Run local multi-node testnet
run_local_testnet() {
    print_header
    echo ""
    echo "Starting Local Multi-Node Testnet"
    echo ""
    
    if check_script "./run-local-testnet.sh"; then
        chmod +x ./run-local-testnet.sh
        ./run-local-testnet.sh
    else
        echo "Please ensure run-local-testnet.sh is in the current directory"
        read -p "Press Enter to continue..."
    fi
}

# Setup production nodes
setup_production_nodes() {
    print_header
    echo ""
    echo "Production Nodes Setup"
    echo ""
    
    if check_script "./setup-production-nodes.sh"; then
        chmod +x ./setup-production-nodes.sh
        ./setup-production-nodes.sh
    else
        echo "Please ensure setup-production-nodes.sh is in the current directory"
        read -p "Press Enter to continue..."
    fi
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
                run_local_dev_node
                ;;
            3)
                setup_remote_sync
                ;;
            4)
                setup_validator
                ;;
            5)
                verify_network
                ;;
            6)
                setup_firewall
                ;;
            7)
                setup_nginx
                ;;
            8)
                run_local_testnet
                ;;
            9)
                setup_production_nodes
                ;;
            10)
                push_new_binary_version
                ;;
            11)
                print_header
                echo ""
                echo "Thank you for using Pokerchain Network Setup!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-11.${NC}"
                sleep 2
                ;;
        esac
# Push new binary version to remote
push_new_binary_version() {
    print_header
    echo ""
    echo "Push New Binary Version to Remote Node"
    echo ""
    read -p "Remote host (e.g., node1.block52.xyz or 192.168.1.100): " remote_host
    if [ -z "$remote_host" ]; then
        echo -e "${YELLOW}❌ Remote host cannot be empty${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    read -p "Remote user (default: root): " remote_user
    remote_user=${remote_user:-root}
    echo ""
    echo "Checking remote binary version and hash..."
    remote_bin_path="/usr/local/bin/pokerchaind"
    remote_version=$(ssh "$remote_user@$remote_host" "$remote_bin_path version 2>/dev/null" || echo "(not found)")
    remote_hash=$(ssh "$remote_user@$remote_host" "sha256sum $remote_bin_path 2>/dev/null | awk '{print \$1}'" || echo "(not found)")
    echo "Remote binary version: $remote_version"
    echo "Remote binary sha256:  $remote_hash"
    echo ""
    local_bin_path="./build/pokerchaind"
    if [ ! -f "$local_bin_path" ]; then
        echo -e "${YELLOW}❌ Local binary not found in ./build${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    local_version=$("$local_bin_path" version 2>/dev/null)
    local_hash=$(sha256sum "$local_bin_path" | awk '{print $1}')
    echo "Local binary version: $local_version"
    echo "Local binary sha256:  $local_hash"
    echo ""
    if [ "$local_hash" = "$remote_hash" ]; then
        echo -e "${GREEN}✅ Remote binary is up to date${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    echo -e "${YELLOW}⚠️  Remote binary differs from local version${NC}"
    read -p "Push local binary to remote and replace? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Pushing binary to remote..."
        scp "$local_bin_path" "$remote_user@$remote_host:/tmp/pokerchaind.new"
        ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind.new $remote_bin_path && sudo chmod +x $remote_bin_path"
        echo -e "${GREEN}✅ Binary updated on remote${NC}"
    else
        echo "Push cancelled."
    fi
    read -p "Press Enter to continue..."
}
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