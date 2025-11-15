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
    # COMMENTED OUT - Genesis node already created
    # echo -e "${GREEN}X)${NC} Genesis Node (node1.block52.xyz)"
    # echo "   Sets up the primary network node with genesis configuration"
    echo ""
    echo -e "${GREEN}1)${NC} Run Local Developer Node (local readonly sync)"
    echo "   Runs a local developer node that syncs from the network (read-only)"
    echo "   - Uses run-dev-node.sh for robust, repeatable setup"
    echo "   - Provides local RPC/API access"
    echo "   - Does NOT participate in consensus"
    echo "   - Perfect for development and testing"
    echo ""
    echo -e "${GREEN}2)${NC} Remote Sync Node (deploy light client to remote server)"
    echo "   Deploy a read-only sync node to a remote Linux server"
    echo "   - Builds and uploads binary"
    echo "   - Configures systemd service"
    echo "   - Connects to node1.block52.xyz as peer"
    echo "   - Syncs blockchain data from the network"
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
    echo -e "${GREEN}5)${NC} Setup Firewall"
    echo "   Configure UFW firewall on remote server"
    echo "   - Allow SSH, P2P, RPC, API, gRPC ports"
    echo "   - Block all other incoming connections"
    echo "   - Secure your validator node"
    echo ""
    echo -e "${GREEN}6)${NC} Setup NGINX & SSL"
    echo "   Configure NGINX reverse proxy with SSL certificates"
    echo "   - Install NGINX and Certbot"
    echo "   - Configure HTTPS for REST API and gRPC"
    echo "   - Automatic SSL certificate from Let's Encrypt"
    echo "   - Auto-renewal configured"
    echo ""
    echo -e "${GREEN}7)${NC} Local Multi-Node Testnet"
    echo "   Run 3 nodes on your local machine"
    echo "   - Different ports for each node"
    echo "   - Easy terminal switching"
    echo "   - Perfect for development"
    echo ""
    echo -e "${GREEN}8)${NC} Setup Production Nodes"
    echo "   Generate production node configurations"
    echo "   - Creates configs in ./production/nodeX/"
    echo "   - Ready for SSH deployment"
    echo "   - Connects to existing network"
    echo ""
    echo -e "${GREEN}9)${NC} Push New Binary Version"
    echo "   Check remote version/hash, push new binary from ./build via SSH"
    echo "   - Compare local and remote binary versions"
    echo "   - Safely replace binary on remote server"
    echo "   - Option to restart service if needed"
    echo ""
    echo -e "${GREEN}10)${NC} Deploy Remote PVM (Execution Layer)"
    echo "   Deploy Poker VM to a remote Linux server"
    echo "   - Checks and installs Docker if needed"
    echo "   - Clones poker-vm repository"
    echo "   - Builds Docker image from pvm/ts"
    echo "   - Sets up systemd service"
    echo ""
    echo -e "${GREEN}11)${NC} Reset Chain (DANGER!)"
    echo "   Reset blockchain to genesis state"
    echo "   - Preserves validator keys and genesis.json (or optionally replace genesis)"
    echo "   - Deletes all blocks and application state"
    echo "   - Restarts chain from block 0"
    echo "   - ⚠️  Use when bug requires full chain restart"
    echo ""
    echo -e "${GREEN}12)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-12]: "
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

# Setup genesis node (COMMENTED OUT - already deployed)
# setup_genesis() {
#     print_header
#     echo ""
#     echo "Setting up Genesis Node (node1.block52.xyz)"
#     echo ""
#     
#     if check_script "./deploy-master-node.sh"; then
#         chmod +x ./deploy-master-node.sh
#         ./deploy-master-node.sh
#     else
#         echo "Please ensure deploy-master-node.sh is in the current directory"
#         read -p "Press Enter to continue..."
#     fi
# }

# Run local developer node (option 1)
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

# Setup remote sync node (option 2)
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

# Setup validator node (option 3)
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

# Verify network connectivity (option 4)
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

# Setup firewall (option 5)
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

# Setup NGINX & SSL (option 6)
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

# Run local multi-node testnet (option 7)
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

# Setup production nodes (option 8)
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

# Push new binary version to remote (option 9)
push_new_binary_version() {
    print_header
    echo ""
    echo "📦 Push New Binary Version to Remote Node"
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Checking Remote Binary...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    remote_bin_path="/usr/local/bin/pokerchaind"
    remote_version=$(ssh "$remote_user@$remote_host" "$remote_bin_path version 2>/dev/null" || echo "(not found)")
    remote_hash=$(ssh "$remote_user@$remote_host" "sha256sum $remote_bin_path 2>/dev/null | awk '{print \$1}'" || echo "(not found)")
    
    echo "Remote binary version: $remote_version"
    echo "Remote binary sha256:  $remote_hash"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Checking Local Binary...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local_bin_path="./build/pokerchaind"
    if [ ! -f "$local_bin_path" ]; then
        echo -e "${YELLOW}❌ Local binary not found in ./build${NC}"
        echo ""
        echo "Please build the binary first:"
        echo "  make build"
        read -p "Press Enter to continue..."
        return
    fi
    
    local_version=$("$local_bin_path" version 2>/dev/null)
    local_hash=$(sha256sum "$local_bin_path" | awk '{print $1}')
    
    echo "Local binary version: $local_version"
    echo "Local binary sha256:  $local_hash"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$local_hash" = "$remote_hash" ]; then
        echo -e "${GREEN}✅ Remote binary is up to date (hashes match)${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}⚠️  Remote binary differs from local version${NC}"
    echo ""
    echo "Would you like to:"
    echo "  1) Push local binary to remote and replace"
    echo "  2) Push and restart pokerchaind service"
    echo "  3) Cancel"
    echo ""
    read -p "Enter choice [1-3]: " push_choice
    
    case $push_choice in
        1)
            echo ""
            echo "Pushing binary to remote..."
            scp "$local_bin_path" "$remote_user@$remote_host:/tmp/pokerchaind.new" || {
                echo -e "${YELLOW}❌ Failed to copy binary${NC}"
                read -p "Press Enter to continue..."
                return
            }
            
            ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind.new $remote_bin_path && sudo chmod +x $remote_bin_path" || {
                echo -e "${YELLOW}❌ Failed to replace binary${NC}"
                read -p "Press Enter to continue..."
                return
            }
            
            echo -e "${GREEN}✅ Binary updated on remote${NC}"
            echo ""
            echo "⚠️  Remember to restart pokerchaind service manually:"
            echo "  ssh $remote_user@$remote_host 'sudo systemctl restart pokerchaind'"
            ;;
        2)
            echo ""
            echo "Pushing binary to remote..."
            scp "$local_bin_path" "$remote_user@$remote_host:/tmp/pokerchaind.new" || {
                echo -e "${YELLOW}❌ Failed to copy binary${NC}"
                read -p "Press Enter to continue..."
                return
            }
            
            ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind.new $remote_bin_path && sudo chmod +x $remote_bin_path" || {
                echo -e "${YELLOW}❌ Failed to replace binary${NC}"
                read -p "Press Enter to continue..."
                return
            }
            
            echo -e "${GREEN}✅ Binary updated on remote${NC}"
            echo ""
            echo "Restarting pokerchaind service..."
            
            ssh "$remote_user@$remote_host" "sudo systemctl restart pokerchaind" || {
                echo -e "${YELLOW}❌ Failed to restart service${NC}"
                read -p "Press Enter to continue..."
                return
            }
            
            echo -e "${GREEN}✅ Service restarted${NC}"
            echo ""
            echo "Checking service status..."
            sleep 2
            ssh "$remote_user@$remote_host" "sudo systemctl status pokerchaind --no-pager | head -20"
            ;;
        *)
            echo "Push cancelled."
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Reset chain to genesis (option 10)
reset_chain() {
    print_header
    echo ""
    echo -e "${YELLOW}⚠️  CHAIN RESET - DESTRUCTIVE OPERATION ⚠️${NC}"
    echo ""
    echo "This will:"
    echo "  ✓ Preserve validator keys (priv_validator_key.json)"
    echo "  ✓ Preserve node keys (node_key.json)"
    echo "  ✓ Preserve genesis.json"
    echo "  ✓ Preserve config files"
    echo ""
    echo "  ✗ DELETE all blocks"
    echo "  ✗ DELETE all application state"
    echo "  ✗ DELETE all transaction history"
    echo ""
    echo "The chain will restart from block 0 with the same genesis state."
    echo ""
    
    read -p "Remote host (e.g., node1.block52.xyz): " remote_host
    if [ -z "$remote_host" ]; then
        echo -e "${YELLOW}❌ Remote host cannot be empty${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Remote user (default: root): " remote_user
    remote_user=${remote_user:-root}
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}FINAL WARNING${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You are about to reset the chain on: $remote_host"
    echo ""
    echo "This will DELETE:"
    echo "  - All blocks in ~/.pokerchain/data/"
    echo "  - Application state database"
    echo "  - WAL (Write-Ahead Log)"
    echo "  - Address book (will rebuild from seeds)"
    echo ""
    echo "Type 'RESET' (in capitals) to confirm:"
    read confirmation
    
    if [ "$confirmation" != "RESET" ]; then
        echo ""
        echo "Reset cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: Stopping pokerchaind service...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    ssh "$remote_user@$remote_host" "sudo systemctl stop pokerchaind" || {
        echo -e "${YELLOW}⚠️  Failed to stop service (may not be running)${NC}"
    }
    
    echo "Waiting for service to stop completely..."
    sleep 3
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Reset Genesis File?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Would you like to replace the genesis file?"
    echo "  1) No - Keep existing genesis.json"
    echo "  2) Yes - Copy from local repo"
    echo ""
    read -p "Enter choice [1-2] (default: 1): " genesis_choice
    genesis_choice=${genesis_choice:-1}
    
    local genesis_updated=false
    
    if [ "$genesis_choice" = "2" ]; then
        echo ""
        echo "Where is your genesis file?"
        echo "  1) ./genesis.json (local file)"
        echo "  2) ./config/genesis.json"
        echo "  3) Custom path"
        echo ""
        read -p "Enter choice [1-3] (default: 1): " genesis_location
        genesis_location=${genesis_location:-1}
        
        local local_genesis_path=""
        
        case $genesis_location in
            1)
                local_genesis_path="./genesis.json"
                ;;
            2)
                local_genesis_path="./config/genesis.json"
                ;;
            3)
                read -p "Enter path to genesis.json: " local_genesis_path
                ;;
        esac
        
        if [ ! -f "$local_genesis_path" ]; then
            echo -e "${YELLOW}❌ Genesis file not found: $local_genesis_path${NC}"
            echo "Continuing without replacing genesis..."
        else
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}Validating New Genesis File...${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # Check if jq is available
            if ! command -v jq &> /dev/null; then
                echo -e "${YELLOW}⚠️  Warning: jq not installed - skipping validation${NC}"
                echo "Install jq for genesis validation: sudo apt-get install jq"
                echo ""
                read -p "Continue without validation? (y/n): " continue_without_validation
                if [[ ! "$continue_without_validation" =~ ^[Yy]$ ]]; then
                    echo "Genesis replacement cancelled."
                    return
                fi
            else
                # Validate local genesis file
                local new_chain_id=$(cat "$local_genesis_path" | jq -r '.chain_id' 2>/dev/null)
                local new_app_hash=$(cat "$local_genesis_path" | jq -r '.app_hash' 2>/dev/null)
                
                if [ -z "$new_chain_id" ] || [ "$new_chain_id" = "null" ]; then
                    echo -e "${YELLOW}❌ CRITICAL ERROR: New genesis file is missing chain_id!${NC}"
                    echo "The genesis file at $local_genesis_path is invalid."
                    echo "Genesis file must have a 'chain_id' field."
                    echo ""
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo "New genesis file:"
                echo "  Chain ID:  $new_chain_id"
                echo "  App Hash:  ${new_app_hash:-"(empty)"}"
                echo ""
                
                # Get existing genesis info
                local old_chain_id=$(ssh "$remote_user@$remote_host" "cat ~/.pokerchain/config/genesis.json | jq -r '.chain_id' 2>/dev/null" || echo "unknown")
                local old_app_hash=$(ssh "$remote_user@$remote_host" "cat ~/.pokerchain/config/genesis.json | jq -r '.app_hash' 2>/dev/null" || echo "unknown")
                
                echo "Current genesis file:"
                echo "  Chain ID:  $old_chain_id"
                echo "  App Hash:  ${old_app_hash:-"(empty)"}"
                echo ""
                
                # Compare chain IDs
                if [ "$new_chain_id" != "$old_chain_id" ]; then
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${YELLOW}⚠️  WARNING: CHAIN ID MISMATCH!${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    echo "You are changing the chain ID from '$old_chain_id' to '$new_chain_id'"
                    echo ""
                    echo "This means you are starting a COMPLETELY NEW CHAIN."
                    echo "This is NOT compatible with the existing network!"
                    echo ""
                    echo "Consequences:"
                    echo "  • This node will NOT sync with other nodes on '$old_chain_id'"
                    echo "  • All previous blocks and state will be lost"
                    echo "  • You are essentially creating a new blockchain"
                    echo ""
                    read -p "Are you ABSOLUTELY SURE you want to change the chain ID? (type 'YES' to confirm): " chain_id_confirm
                    
                    if [ "$chain_id_confirm" != "YES" ]; then
                        echo ""
                        echo "Genesis replacement cancelled."
                        return
                    fi
                fi
                
                # Compare app hashes
                if [ "$new_app_hash" != "$old_app_hash" ] && [ "$new_app_hash" != "null" ] && [ "$old_app_hash" != "null" ]; then
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${YELLOW}⚠️  WARNING: APP HASH MISMATCH!${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    echo "The app_hash differs from the current genesis."
                    echo ""
                    echo "This means the initial state of the blockchain has changed."
                    echo "Different app_hash = different genesis accounts, balances, or parameters"
                    echo ""
                    if [ "$new_chain_id" = "$old_chain_id" ]; then
                        echo "⚠️  You have the SAME chain ID but DIFFERENT initial state!"
                        echo "This will cause consensus failures if other validators have different genesis."
                        echo ""
                    fi
                    read -p "Continue with different app_hash? (y/n): " app_hash_confirm
                    
                    if [[ ! "$app_hash_confirm" =~ ^[Yy]$ ]]; then
                        echo ""
                        echo "Genesis replacement cancelled."
                        return
                    fi
                fi
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}Copying Genesis File...${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # Backup existing genesis
            ssh "$remote_user@$remote_host" "cp ~/.pokerchain/config/genesis.json ~/.pokerchain/config/genesis.json.backup" || {
                echo -e "${YELLOW}⚠️  Could not backup existing genesis${NC}"
            }
            
            echo "Backup created: ~/.pokerchain/config/genesis.json.backup"
            echo ""
            
            # Copy new genesis
            scp "$local_genesis_path" "$remote_user@$remote_host:~/.pokerchain/config/genesis.json" || {
                echo -e "${YELLOW}❌ Failed to copy genesis file${NC}"
                echo "Restoring backup..."
                ssh "$remote_user@$remote_host" "mv ~/.pokerchain/config/genesis.json.backup ~/.pokerchain/config/genesis.json"
                read -p "Press Enter to continue..."
                return
            }
            
            echo -e "${GREEN}✅ Genesis file updated${NC}"
            echo "   Chain ID: $new_chain_id"
            echo "   App Hash: ${new_app_hash:-"(empty)"}"
            genesis_updated=true
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Resetting blockchain state...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run tendermint unsafe-reset-all
    ssh "$remote_user@$remote_host" "pokerchaind tendermint unsafe-reset-all" || {
        echo -e "${YELLOW}❌ Failed to reset chain${NC}"
        read -p "Press Enter to continue..."
        return
    }
    
    echo -e "${GREEN}✅ Chain state reset successfully${NC}"
    
    if [ "$genesis_updated" = true ]; then
        echo -e "${GREEN}✅ Genesis file was replaced - chain will start with new genesis${NC}"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Verifying preserved files...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check that keys and genesis still exist
    echo ""
    echo "Checking preserved files:"
    ssh "$remote_user@$remote_host" "ls -lh ~/.pokerchain/config/{priv_validator_key.json,node_key.json,genesis.json} 2>/dev/null" && {
        echo -e "${GREEN}✅ All critical files preserved${NC}"
    } || {
        echo -e "${YELLOW}⚠️  Could not verify all files${NC}"
    }
    
    echo ""
    echo "Would you like to restart the chain now?"
    echo "  1) Yes - restart pokerchaind service"
    echo "  2) No - I'll restart manually later"
    echo ""
    read -p "Enter choice [1-2]: " restart_choice
    
    case $restart_choice in
        1)
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}Step 5: Starting pokerchaind service...${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            ssh "$remote_user@$remote_host" "sudo systemctl start pokerchaind" || {
                echo -e "${YELLOW}❌ Failed to start service${NC}"
                echo "Try manually: ssh $remote_user@$remote_host 'sudo systemctl start pokerchaind'"
                read -p "Press Enter to continue..."
                return
            }
            
            echo -e "${GREEN}✅ Service started${NC}"
            echo ""
            echo "Waiting for initialization..."
            sleep 5
            
            echo ""
            echo "Service status:"
            ssh "$remote_user@$remote_host" "sudo systemctl status pokerchaind --no-pager | head -20"
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}Step 6: Create Validator? (Optional)${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Would you like to create a validator now?"
            echo "  1) Yes - Import key and create validator"
            echo "  2) No - I'll do it manually later"
            echo ""
            read -p "Enter choice [1-2]: " validator_choice
            
            if [ "$validator_choice" = "1" ]; then
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${BLUE}Validator Setup${NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                
                # Wait for chain to produce a few blocks
                echo "Waiting for chain to produce blocks..."
                sleep 10
                
                # Get validator pubkey
                local validator_pubkey=$(ssh "$remote_user@$remote_host" "pokerchaind comet show-validator" 2>/dev/null)
                if [ -z "$validator_pubkey" ]; then
                    echo -e "${YELLOW}❌ Could not get validator pubkey${NC}"
                    echo "Chain may not be running yet. Try manually later."
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo "Validator Public Key: $validator_pubkey"
                echo ""
                
                # Ask which key to import
                echo "Which account key would you like to import?"
                echo "  1) alice (default genesis account)"
                echo "  2) Other account (provide mnemonic)"
                echo ""
                read -p "Enter choice [1-2] (default: 1): " key_choice
                key_choice=${key_choice:-1}
                
                local account_name=""
                
                if [ "$key_choice" = "1" ]; then
                    account_name="alice"
                    echo ""
                    echo "Enter the mnemonic for alice:"
                    read -p "> " alice_mnemonic
                    
                    if [ -z "$alice_mnemonic" ]; then
                        echo -e "${YELLOW}❌ Mnemonic cannot be empty${NC}"
                        read -p "Press Enter to continue..."
                        return
                    fi
                    
                    # Import alice key
                    echo ""
                    echo "Importing alice key..."
                    echo "$alice_mnemonic" | ssh "$remote_user@$remote_host" "pokerchaind keys add alice --recover" || {
                        echo -e "${YELLOW}❌ Failed to import key${NC}"
                        read -p "Press Enter to continue..."
                        return
                    }
                else
                    echo ""
                    read -p "Enter account name: " account_name
                    if [ -z "$account_name" ]; then
                        echo -e "${YELLOW}❌ Account name cannot be empty${NC}"
                        read -p "Press Enter to continue..."
                        return
                    fi
                    
                    echo "Enter the mnemonic for $account_name:"
                    read -p "> " account_mnemonic
                    
                    if [ -z "$account_mnemonic" ]; then
                        echo -e "${YELLOW}❌ Mnemonic cannot be empty${NC}"
                        read -p "Press Enter to continue..."
                        return
                    fi
                    
                    # Import key
                    echo ""
                    echo "Importing $account_name key..."
                    echo "$account_mnemonic" | ssh "$remote_user@$remote_host" "pokerchaind keys add $account_name --recover" || {
                        echo -e "${YELLOW}❌ Failed to import key${NC}"
                        read -p "Press Enter to continue..."
                        return
                    }
                fi
                
                echo -e "${GREEN}✅ Key imported${NC}"
                echo ""
                
                # Get account address
                local account_address=$(ssh "$remote_user@$remote_host" "pokerchaind keys show $account_name -a" 2>/dev/null)
                echo "Account address: $account_address"
                
                # Check balance
                echo ""
                echo "Checking account balance..."
                sleep 2
                local balance=$(ssh "$remote_user@$remote_host" "pokerchaind query bank balances $account_address --output json" 2>/dev/null | jq -r '.balances[0].amount' 2>/dev/null)
                
                if [ -z "$balance" ] || [ "$balance" = "null" ]; then
                    echo -e "${YELLOW}⚠️  Could not verify balance. Account may have no tokens.${NC}"
                    echo "Make sure this account has tokens in genesis.json"
                    echo ""
                    read -p "Continue anyway? (y/n): " continue_anyway
                    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                        echo "Validator creation cancelled."
                        read -p "Press Enter to continue..."
                        return
                    fi
                else
                    echo "Balance: $balance b52usdc"
                fi
                
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${BLUE}Validator Configuration${NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                
                read -p "Validator moniker (default: validator): " moniker
                moniker=${moniker:-validator}
                
                read -p "Amount to stake (default: 100000000000b52usdc): " stake_amount
                stake_amount=${stake_amount:-100000000000b52usdc}
                
                read -p "Commission rate (default: 0.10): " commission_rate
                commission_rate=${commission_rate:-0.10}
                
                read -p "Commission max rate (default: 0.20): " commission_max_rate
                commission_max_rate=${commission_max_rate:-0.20}
                
                read -p "Commission max change rate (default: 0.01): " commission_max_change
                commission_max_change=${commission_max_change:-0.01}
                
                read -p "Min self delegation (default: 1): " min_self_delegation
                min_self_delegation=${min_self_delegation:-1}
                
                echo ""
                echo "Creating validator with:"
                echo "  Moniker: $moniker"
                echo "  Account: $account_name ($account_address)"
                echo "  Stake: $stake_amount"
                echo "  Commission: $commission_rate (max: $commission_max_rate, max change: $commission_max_change)"
                echo "  Min self delegation: $min_self_delegation"
                echo ""
                read -p "Proceed? (y/n): " confirm_create
                
                if [[ ! "$confirm_create" =~ ^[Yy]$ ]]; then
                    echo "Validator creation cancelled."
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo ""
                echo "Creating validator..."
                
                # Create validator transaction
                ssh "$remote_user@$remote_host" "pokerchaind tx staking create-validator \
                    --amount=$stake_amount \
                    --pubkey='$validator_pubkey' \
                    --moniker=\"$moniker\" \
                    --commission-rate=\"$commission_rate\" \
                    --commission-max-rate=\"$commission_max_rate\" \
                    --commission-max-change-rate=\"$commission_max_change\" \
                    --min-self-delegation=\"$min_self_delegation\" \
                    --from=$account_name \
                    --chain-id=pokerchain \
                    --gas=auto \
                    --gas-adjustment=1.5 \
                    --yes" || {
                    echo -e "${YELLOW}❌ Failed to create validator${NC}"
                    echo ""
                    echo "Common issues:"
                    echo "  • Account has insufficient balance"
                    echo "  • Chain ID doesn't match"
                    echo "  • Node not fully synced"
                    echo ""
                    read -p "Press Enter to continue..."
                    return
                }
                
                echo ""
                echo -e "${GREEN}✅ Validator creation transaction submitted!${NC}"
                echo ""
                echo "Waiting for transaction to be included in a block..."
                sleep 6
                
                # Query validator
                local validator_address=$(ssh "$remote_user@$remote_host" "pokerchaind keys show $account_name --bech val -a" 2>/dev/null)
                echo ""
                echo "Checking validator status..."
                ssh "$remote_user@$remote_host" "pokerchaind query staking validator $validator_address --output json" 2>/dev/null | jq '{moniker: .description.moniker, status: .status, tokens: .tokens}' || {
                    echo "Could not query validator yet. It may take a moment to appear."
                }
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${GREEN}✅ Chain reset complete! Starting from block 0.${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Monitor logs with:"
            echo "  ssh $remote_user@$remote_host 'journalctl -u pokerchaind -f'"
            ;;
        *)
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${GREEN}✅ Chain reset complete!${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Start the chain manually when ready:"
            echo "  ssh $remote_user@$remote_host 'sudo systemctl start pokerchaind'"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Deploy Remote PVM (option 11)
deploy_remote_pvm() {
    print_header
    echo ""
    echo "Deploying Remote Poker VM"
    echo ""
    
    if check_script "./deploy-pvm.sh"; then
        chmod +x ./deploy-pvm.sh
        ./deploy-pvm.sh
    else
        echo "Please ensure deploy-pvm.sh is in the current directory"
    fi
    
    read -p "Press Enter to continue..."
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

# Main loop
main() {
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                run_local_dev_node
                ;;
            2)
                setup_remote_sync
                ;;
            3)
                setup_validator
                ;;
            4)
                verify_network
                ;;
            5)
                setup_firewall
                ;;
            6)
                setup_nginx
                ;;
            7)
                run_local_testnet
                ;;
            8)
                setup_production_nodes
                ;;
            9)
                push_new_binary_version
                ;;
            10)
                deploy_remote_pvm
                ;;
            11)
                reset_chain
                ;;
            12)
                print_header
                echo ""
                echo "Thank you for using Pokerchain Network Setup!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-12.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run pre-checks and start main loop
check_dependencies
main