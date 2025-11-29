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
    echo -e "${GREEN}9)${NC} Update Node Binary"
    echo "   Update binary on remote server (from local build or GitHub release)"
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
    echo -e "${GREEN}12)${NC} Deploy WebSocket Server"
    echo "   Deploy real-time WebSocket server to remote node"
    echo "   - Builds ws-server binary from cmd/ws-server"
    echo "   - Uploads to remote server"
    echo "   - Creates systemd service (poker-ws.service)"
    echo "   - Required for real-time UI updates"
    echo ""
    echo -e "${GREEN}13)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-13]: "
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
    
    # Configuration
    PROD_DIR="./production"
    CHAIN_BINARY="pokerchaind"
    CHAIN_ID="pokerchain"
    KEYRING_BACKEND="test"
    
    # Step 1: Ask for node number
    echo -e "${BLUE}Step 1: Node Configuration${NC}"
    echo ""
    read -p "Enter node number (e.g., 2 for node2): " NODE_NUM
    
    if [ -z "$NODE_NUM" ] || ! [[ "$NODE_NUM" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid node number${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    NODE_HOME="$PROD_DIR/node$NODE_NUM"
    
    # Check if node directory already exists
    if [ -d "$NODE_HOME" ]; then
        echo -e "${YELLOW}⚠️  Node directory already exists: $NODE_HOME${NC}"
        read -p "Do you want to overwrite it? (y/n): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            read -p "Press Enter to continue..."
            return
        fi
        rm -rf "$NODE_HOME"
    fi
    
    # Step 2: Mnemonic selection
    echo ""
    echo -e "${BLUE}Step 2: Validator Key Mnemonic${NC}"
    echo ""
    
    SEEDS_FILE="./seeds.txt"
    MNEMONIC=""
    
    if [ -f "$SEEDS_FILE" ]; then
        echo "Found seed phrases file: $SEEDS_FILE"
        echo ""
        echo "Available seed phrases (24-word mnemonics):"
        
        # Read clean mnemonics (skip empty lines and comments)
        mapfile -t SEED_ARRAY < <(grep -v "^#" "$SEEDS_FILE" | grep -v "^$")
        
        # Display with index numbers starting from 1
        for i in "${!SEED_ARRAY[@]}"; do
            local display_num=$((i + 1))
            # Show first and last 3 words for identification
            local first_words=$(echo "${SEED_ARRAY[$i]}" | awk '{print $1, $2, $3}')
            local last_words=$(echo "${SEED_ARRAY[$i]}" | awk '{print $(NF-2), $(NF-1), $NF}')
            echo "  $display_num) $first_words ... $last_words"
        done
        echo ""
        read -p "Enter seed phrase number (1-${#SEED_ARRAY[@]}), or press Enter to add a new one: " SEED_NUM
        
        if [ -n "$SEED_NUM" ] && [[ "$SEED_NUM" =~ ^[0-9]+$ ]]; then
            # Convert to 0-indexed array position
            local array_index=$((SEED_NUM - 1))
            
            if [ "$array_index" -ge 0 ] && [ "$array_index" -lt "${#SEED_ARRAY[@]}" ]; then
                MNEMONIC="${SEED_ARRAY[$array_index]}"
                echo -e "${GREEN}✓ Using seed phrase #$SEED_NUM${NC}"
            else
                echo -e "${RED}❌ Invalid seed number${NC}"
                read -p "Press Enter to continue..."
                return
            fi
        fi
    fi
    
    if [ -z "$MNEMONIC" ]; then
        echo "Enter new 24-word mnemonic phrase (or press Enter to generate one):"
        read -p "> " MNEMONIC
        
        if [ -z "$MNEMONIC" ]; then
            echo "Generating new mnemonic..."
            # Generate new mnemonic using pokerchaind
            MNEMONIC=$($CHAIN_BINARY keys add temp --dry-run --keyring-backend test 2>&1 | grep -A 1 "mnemonic:" | tail -1)
            if [ -z "$MNEMONIC" ]; then
                echo -e "${RED}❌ Failed to generate mnemonic${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            echo -e "${GREEN}✓ Generated new mnemonic${NC}"
        fi
    fi
    
    # Step 3: Create production/nodeX folder
    echo ""
    echo -e "${BLUE}Step 3: Creating Node Directory${NC}"
    echo ""
    
    mkdir -p "$NODE_HOME/config"
    mkdir -p "$NODE_HOME/data"
    
    read -p "Enter node moniker (default: validator-$NODE_NUM): " MONIKER
    MONIKER=${MONIKER:-"validator-$NODE_NUM"}
    
    read -p "Enter node hostname/IP (e.g., node2.block52.xyz): " NODE_HOST
    if [ -z "$NODE_HOST" ]; then
        echo -e "${RED}❌ Hostname cannot be empty${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check for binary
    if [ -f "./build/pokerchaind" ]; then
        CHAIN_BINARY="./build/pokerchaind"
    elif ! command -v pokerchaind &> /dev/null; then
        echo -e "${RED}❌ pokerchaind binary not found${NC}"
        echo "Please build the binary first: make build"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Generate validator key from mnemonic
    echo "Generating validator key from mnemonic..."
    
    # Check for genvalidatorkey tool
    if [ -f "./genvalidatorkey" ] && [ -x "./genvalidatorkey" ]; then
        ./genvalidatorkey "$MNEMONIC" "$NODE_HOME/config/priv_validator_key.json"
        echo -e "${GREEN}✓ Validator key generated${NC}"
    else
        echo -e "${YELLOW}⚠️  genvalidatorkey tool not found, will use pokerchaind init${NC}"
    fi
    
    # Create priv_validator_state.json
    cat > "$NODE_HOME/data/priv_validator_state.json" << 'EOF'
{
  "height": "0",
  "round": 0,
  "step": 0
}
EOF
    
    # Initialize the node
    echo "Initializing node..."
    $CHAIN_BINARY init $MONIKER --chain-id $CHAIN_ID --home $NODE_HOME
    
    # Create validator account key
    echo "Creating validator account key..."
    echo "$MNEMONIC" | $CHAIN_BINARY keys add $MONIKER --recover --keyring-backend $KEYRING_BACKEND --home $NODE_HOME > /dev/null 2>&1
    
    # Get node ID and address
    NODE_ID=$($CHAIN_BINARY comet show-node-id --home $NODE_HOME)
    NODE_ADDR=$($CHAIN_BINARY keys show $MONIKER -a --keyring-backend $KEYRING_BACKEND --home $NODE_HOME)
    
    echo -e "${GREEN}✓ Node initialized${NC}"
    echo "  Node ID: $NODE_ID"
    echo "  Address: $NODE_ADDR"
    
    # Copy genesis from node0 if it exists
    if [ -f "$PROD_DIR/node0/config/genesis.json" ]; then
        cp "$PROD_DIR/node0/config/genesis.json" "$NODE_HOME/config/genesis.json"
        echo -e "${GREEN}✓ Copied genesis from node0${NC}"
    else
        echo -e "${YELLOW}⚠️  genesis.json not found in node0, you'll need to copy it manually${NC}"
    fi
    
    # Step 4: Configure bridge settings
    echo ""
    echo -e "${BLUE}Step 4: Bridge Configuration${NC}"
    echo ""
    
    ALCHEMY_URL=""
    
    # Check for .env file
    if [ -f ".env" ]; then
        echo "Found .env file"
        ALCHEMY_URL=$(grep "^ALCHEMY_URL=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -n "$ALCHEMY_URL" ]; then
            echo -e "${GREEN}✓ Loaded Alchemy URL from .env${NC}"
        fi
    fi
    
    if [ -z "$ALCHEMY_URL" ] || [ "$ALCHEMY_URL" = "https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE" ]; then
        echo "Enter Alchemy URL (Base mainnet RPC):"
        echo "Example: https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
        read -p "> " ALCHEMY_URL
        
        if [ -z "$ALCHEMY_URL" ]; then
            echo -e "${YELLOW}⚠️  No Alchemy URL provided, bridge will be disabled${NC}"
            ALCHEMY_URL="https://mainnet.base.org"
        fi
    fi
    
    # Update app.toml with bridge configuration
    if [ -f "$NODE_HOME/config/app.toml" ]; then
        # Enable bridge
        sed -i.bak 's/bridge_enabled = false/bridge_enabled = true/' "$NODE_HOME/config/app.toml"
        
        # Set Alchemy URL
        sed -i.bak "s|ethereum_rpc_url = \".*\"|ethereum_rpc_url = \"$ALCHEMY_URL\"|" "$NODE_HOME/config/app.toml"
        
        # Set deposit contract
        sed -i.bak 's|deposit_contract = ""|deposit_contract = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"|' "$NODE_HOME/config/app.toml"
        
        rm -f "$NODE_HOME/config/app.toml.bak"
        echo -e "${GREEN}✓ Bridge configuration updated${NC}"
    fi
    
    # Update config.toml with persistent peers
    if [ -f "$NODE_HOME/config/config.toml" ]; then
        # Set persistent peer to node0
        if [ -f "$PROD_DIR/node0/config/config.toml" ]; then
            NODE0_ID=$($CHAIN_BINARY comet show-node-id --home "$PROD_DIR/node0")
            sed -i.bak "/^seeds = /a persistent_peers = \"${NODE0_ID}@node1.block52.xyz:26656\"" "$NODE_HOME/config/config.toml"
            rm -f "$NODE_HOME/config/config.toml.bak"
            echo -e "${GREEN}✓ Configured peer connection to node0${NC}"
        fi
    fi
    
    # Save mnemonic to backup file
    mkdir -p "$PROD_DIR"
    MNEMONICS_BACKUP="$PROD_DIR/MNEMONICS_BACKUP.txt"
    
    # Create backup file if it doesn't exist
    if [ ! -f "$MNEMONICS_BACKUP" ]; then
        cat > "$MNEMONICS_BACKUP" << EOF
# VALIDATOR KEY MNEMONICS - KEEP THIS FILE EXTREMELY SECURE!
# Generated: $(date)
# Chain ID: $CHAIN_ID
#
# These mnemonics are backed up from deployed validator nodes.
# Store this file in a secure location (encrypted storage, password manager, etc.)
# DO NOT commit this file to version control!

EOF
        chmod 600 "$MNEMONICS_BACKUP"
    fi
    
    echo "" >> "$MNEMONICS_BACKUP"
    echo "# Node $NODE_NUM: $MONIKER" >> "$MNEMONICS_BACKUP"
    echo "# Hostname: $NODE_HOST" >> "$MNEMONICS_BACKUP"
    echo "# Address: $NODE_ADDR" >> "$MNEMONICS_BACKUP"
    echo "# Generated: $(date)" >> "$MNEMONICS_BACKUP"
    echo "$MNEMONIC" >> "$MNEMONICS_BACKUP"
    echo "" >> "$MNEMONICS_BACKUP"
    echo -e "${GREEN}✓ Mnemonic saved to $MNEMONICS_BACKUP${NC}"
    
    # Step 5: Remote deployment option
    echo ""
    echo -e "${BLUE}Step 5: Remote Deployment (Optional)${NC}"
    echo ""
    echo "Do you want to deploy this node to a remote server now?"
    read -p "(y/n): " DEPLOY_REMOTE
    
    if [[ "$DEPLOY_REMOTE" =~ ^[Yy]$ ]]; then
        echo ""
        read -p "Remote user (default: root): " REMOTE_USER
        REMOTE_USER=${REMOTE_USER:-root}
        
        echo ""
        echo "Testing SSH connection to $REMOTE_USER@$NODE_HOST..."
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$NODE_HOST" "echo 'SSH OK'" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ SSH connection successful${NC}"
            
            # Use deploy-production-node.sh if available
            if [ -f "./deploy-production-node.sh" ]; then
                echo ""
                echo "Deploying node..."
                chmod +x ./deploy-production-node.sh
                ./deploy-production-node.sh "$NODE_NUM" "$NODE_HOST" "$REMOTE_USER"
            else
                echo -e "${YELLOW}⚠️  deploy-production-node.sh not found${NC}"
                echo "Please deploy manually by copying $NODE_HOME to the remote server"
            fi
        else
            echo -e "${RED}❌ Cannot connect to $REMOTE_USER@$NODE_HOST${NC}"
            echo "Please ensure SSH key access is configured"
        fi
    else
        echo ""
        echo "Node configuration created locally at: $NODE_HOME"
        echo ""
        echo "To deploy later, run:"
        echo "  ./deploy-production-node.sh $NODE_NUM $NODE_HOST"
    fi
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Validator Node Setup Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Node Information:"
    echo "  Number: $NODE_NUM"
    echo "  Moniker: $MONIKER"
    echo "  Hostname: $NODE_HOST"
    echo "  Node ID: $NODE_ID"
    echo "  Address: $NODE_ADDR"
    echo "  Home: $NODE_HOME"
    echo ""
    echo "⚠️  IMPORTANT: Keep $MNEMONICS_BACKUP secure!"
    echo ""
    
    read -p "Press Enter to continue..."
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
                    echo "   1. Check if node is running: ssh $remote_node 'systemctl status pokerchaind'"
                    echo "   2. Check for errors: ssh $remote_node 'journalctl -u pokerchaind -n 50'"
                    echo "   3. Verify validators: curl http://$remote_node:$rpc_port/validators"
                    echo ""
                    read -p "   Would you like to restart the pokerchaind service on $remote_node? (y/n): " restart_choice
                    
                    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                        read -p "   SSH user (default: root): " ssh_user
                        ssh_user=${ssh_user:-root}
                        
                        echo ""
                        echo "   Restarting pokerchaind service..."
                        if ssh "$ssh_user@$remote_node" "systemctl restart pokerchaind && sleep 2 && systemctl status pokerchaind --no-pager | head -10"; then
                            echo ""
                            echo -e "${GREEN}   ✅ Service restarted successfully${NC}"
                            echo ""
                            echo "   Wait a few seconds and check block production again."
                        else
                            echo ""
                            echo -e "${RED}   ❌ Failed to restart service${NC}"
                            echo "   You may need to SSH manually: ssh $ssh_user@$remote_node"
                        fi
                    fi
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

    # Test SSL/HTTPS endpoints
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Testing SSL/HTTPS Endpoints...${NC}"
    echo ""

    # Test HTTPS API at root
    echo -n "HTTPS REST API (root): "
    if curl -s --max-time 5 "https://$remote_node/cosmos/base/tendermint/v1beta1/node_info" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"

        # Get node info via HTTPS
        local https_api_output=$(curl -s --max-time 5 "https://$remote_node/cosmos/base/tendermint/v1beta1/node_info" 2>/dev/null)
        if [ -n "$https_api_output" ]; then
            echo "$https_api_output" | jq -r '
                "  Default Node ID: " + .default_node_id,
                "  Network: " + .default_node_info.network
            ' 2>/dev/null || echo "  (API response received)"
        fi
    else
        echo -e "${YELLOW}⚠️  Not accessible${NC}"
    fi

    echo ""
    echo -n "HTTPS RPC (/rpc): "
    if curl -s --max-time 5 "https://$remote_node/rpc/status" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"

        # Get status via HTTPS RPC
        local https_rpc_output=$(curl -s --max-time 5 "https://$remote_node/rpc/status" 2>/dev/null)
        if [ -n "$https_rpc_output" ]; then
            echo "$https_rpc_output" | jq -r '
                "  Chain ID: " + .result.node_info.network,
                "  Latest Block: " + .result.sync_info.latest_block_height
            ' 2>/dev/null || echo "  (RPC response received)"
        fi
    else
        echo -e "${YELLOW}⚠️  Not accessible${NC}"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Test WebSocket server via HTTPS reverse proxy
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Testing WebSocket Server (via HTTPS reverse proxy)...${NC}"
    echo ""

    # Test WSS health via NGINX proxy at /ws-health
    echo -n "WebSocket Health (wss://$remote_node/ws-health): "
    local wss_health=$(curl -s --max-time 5 "https://$remote_node/ws-health" 2>/dev/null)
    if [ -n "$wss_health" ]; then
        echo -e "${GREEN}✅ Accessible${NC}"
        local wss_status=$(echo "$wss_health" | jq -r '.status' 2>/dev/null)
        local wss_clients=$(echo "$wss_health" | jq -r '.clients' 2>/dev/null)
        local wss_games=$(echo "$wss_health" | jq -r '.active_games' 2>/dev/null)
        if [ "$wss_status" = "ok" ]; then
            echo "  Status: $wss_status"
            echo "  Connected clients: $wss_clients"
            echo "  Active game subscriptions: $wss_games"
        else
            echo "  Response: $wss_health"
        fi
    else
        echo -e "${YELLOW}⚠️  Not accessible (NGINX may not be configured for /ws-health)${NC}"
        echo "  Ensure NGINX has location /ws-health proxying to localhost:8585/health"
    fi

    # Test WebSocket endpoint accessibility (will return "Bad Request" which is expected for non-WS request)
    echo ""
    echo -n "WebSocket Endpoint (wss://$remote_node/ws): "
    local ws_response=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "https://$remote_node/ws" 2>/dev/null)
    if [ "$ws_response" = "400" ]; then
        echo -e "${GREEN}✅ Endpoint reachable (400 = WebSocket upgrade required)${NC}"
    elif [ "$ws_response" = "101" ]; then
        echo -e "${GREEN}✅ WebSocket upgrade successful${NC}"
    elif [ "$ws_response" = "000" ]; then
        echo -e "${YELLOW}⚠️  Connection failed${NC}"
    else
        echo -e "${YELLOW}⚠️  Unexpected response: HTTP $ws_response${NC}"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    echo "Public Endpoints:"
    echo "  HTTPS RPC:  https://$remote_node/rpc"
    echo "  HTTPS API:  https://$remote_node/"
    echo "  WebSocket:  wss://$remote_node/ws"
    echo "  WS Health:  https://$remote_node/ws-health"
    echo ""
    echo "Test commands:"
    echo "  HTTPS:"
    echo "    curl https://$remote_node/rpc/status"
    echo "    curl https://$remote_node/cosmos/base/tendermint/v1beta1/node_info"
    echo "  WebSocket:"
    echo "    curl https://$remote_node/ws-health"
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
    echo "📦 Update Node Binary"
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
    echo -e "${BLUE}Choose Update Method${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1) Push from local build (./build directory)"
    echo "  2) Download directly on remote from GitHub release"
    echo "  3) Cancel"
    echo ""
    read -p "Enter choice [1-3]: " binary_source_choice
    
    local_bin_path=""
    new_hash=""
    
    case $binary_source_choice in
        1)
            # Use local build
            echo ""
            echo "Using local binary..."
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
            
            if [ "$local_hash" = "$remote_hash" ]; then
                echo ""
                echo -e "${GREEN}✅ Remote binary is already up to date (hashes match)${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo ""
            echo "Uploading binary to remote..."
            if ! scp "$local_bin_path" "$remote_user@$remote_host:/tmp/pokerchaind.new"; then
                echo -e "${YELLOW}❌ Failed to copy binary${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo -e "${GREEN}✓${NC} Binary uploaded"
            new_hash="$local_hash"
            ;;
            
        2)
            # Download on remote from GitHub
            echo ""
            read -p "Enter release tag (e.g., v0.1.4) or press Enter for latest: " release_tag
            if [ -z "$release_tag" ]; then
                release_tag="latest"
                echo "Using latest release"
            else
                echo "Using release: $release_tag"
            fi
            
            echo ""
            echo "Detecting remote architecture..."
            remote_arch=$(ssh "$remote_user@$remote_host" 'uname -m')
            remote_os=$(ssh "$remote_user@$remote_host" 'uname -s' | tr '[:upper:]' '[:lower:]')
            
            case "$remote_arch" in
                x86_64)
                    remote_arch="amd64"
                    ;;
                aarch64|arm64)
                    remote_arch="arm64"
                    ;;
                *)
                    echo -e "${YELLOW}❌ Unsupported architecture: $remote_arch${NC}"
                    read -p "Press Enter to continue..."
                    return
                    ;;
            esac
            
            echo "Remote: ${remote_os}/${remote_arch}"
            
            # Get actual release tag if using latest
            if [ "$release_tag" = "latest" ]; then
                echo ""
                echo "Getting latest release information..."
                release_tag=$(curl -s "https://api.github.com/repos/block52/pokerchain/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
                
                if [ -z "$release_tag" ]; then
                    echo -e "${YELLOW}❌ Could not determine latest release${NC}"
                    read -p "Press Enter to continue..."
                    return
                fi
                
                echo "Latest release: $release_tag"
            fi
            
            local binary_name="pokerchaind-${remote_os}-${remote_arch}"
            local archive_name="${binary_name}-${release_tag}.tar.gz"
            local download_url="https://github.com/block52/pokerchain/releases/download/${release_tag}/${archive_name}"
            local checksum_url="https://github.com/block52/pokerchain/releases/download/${release_tag}/${archive_name}.sha256"
            
            echo ""
            echo "Downloading on remote server..."
            echo "URL: $download_url"
            
            # Download and extract on remote
            ssh "$remote_user@$remote_host" bash <<EOF
set -e

# Create temp directory
TEMP_DIR=\$(mktemp -d)
cd "\$TEMP_DIR"

# Download archive
echo "Downloading binary archive..."
if ! curl -L -f -o "$archive_name" "$download_url"; then
    echo "Failed to download binary"
    rm -rf "\$TEMP_DIR"
    exit 1
fi

echo "Downloaded $archive_name"

# Download checksum if available
echo "Downloading checksum..."
if curl -L -f -o "${archive_name}.sha256" "$checksum_url" 2>/dev/null; then
    echo "Downloaded checksum"
    
    # Verify checksum
    echo "Verifying checksum..."
    expected_hash=\$(cat "${archive_name}.sha256")
    actual_hash=\$(sha256sum "$archive_name" | awk '{print \$1}')
    
    if [ "\$expected_hash" = "\$actual_hash" ]; then
        echo "✓ Checksum verified"
    else
        echo "❌ Checksum mismatch!"
        echo "  Expected: \$expected_hash"
        echo "  Actual:   \$actual_hash"
        rm -rf "\$TEMP_DIR"
        exit 1
    fi
else
    echo "⚠ Checksum not available, skipping verification"
fi

# Extract binary
echo "Extracting binary..."
if ! tar -xzf "$archive_name"; then
    echo "Failed to extract archive"
    rm -rf "\$TEMP_DIR"
    exit 1
fi

if [ ! -f "$binary_name" ]; then
    echo "Binary not found in archive"
    ls -la
    rm -rf "\$TEMP_DIR"
    exit 1
fi

echo "✓ Extracted binary"

# Move to /tmp for installation
mv "$binary_name" /tmp/pokerchaind.new
chmod +x /tmp/pokerchaind.new

# Calculate hash
NEW_HASH=\$(sha256sum /tmp/pokerchaind.new | awk '{print \$1}')
echo "NEW_HASH:\$NEW_HASH"

# Cleanup
cd /
rm -rf "\$TEMP_DIR"
EOF
            
            if [ $? -ne 0 ]; then
                echo -e "${YELLOW}❌ Failed to download on remote${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            # Extract the new hash from the output
            new_hash=$(ssh "$remote_user@$remote_host" "sha256sum /tmp/pokerchaind.new 2>/dev/null | awk '{print \$1}'")
            
            if [ -z "$new_hash" ]; then
                echo -e "${YELLOW}❌ Failed to get new binary hash${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo ""
            echo "Downloaded binary sha256: $new_hash"
            
            if [ "$new_hash" = "$remote_hash" ]; then
                echo ""
                echo -e "${GREEN}✅ Remote binary is already up to date (hashes match)${NC}"
                ssh "$remote_user@$remote_host" "rm -f /tmp/pokerchaind.new"
                read -p "Press Enter to continue..."
                return
            fi
            ;;
            
        *)
            echo "Update cancelled."
            read -p "Press Enter to continue..."
            return
            ;;
    esac
    
    # Now ask what to do with the new binary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}After Download - Choose Action${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1) Replace binary only"
    echo "  2) Replace binary and restart service"
    echo "  3) Cancel"
    echo ""
    read -p "Enter choice [1-3]: " action_choice
    
    case $action_choice in
        1)
            echo ""
            echo "Replacing binary on remote..."
            
            if ! ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind.new $remote_bin_path && sudo chmod +x $remote_bin_path"; then
                echo -e "${YELLOW}❌ Failed to replace binary${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo -e "${GREEN}✅ Binary updated on remote${NC}"
            echo ""
            echo "⚠️  Remember to restart pokerchaind service manually:"
            echo "  ssh $remote_user@$remote_host 'sudo systemctl restart pokerchaind'"
            ;;
            
        2)
            echo ""
            echo "Replacing binary on remote..."
            
            if ! ssh "$remote_user@$remote_host" "sudo mv /tmp/pokerchaind.new $remote_bin_path && sudo chmod +x $remote_bin_path"; then
                echo -e "${YELLOW}❌ Failed to replace binary${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo -e "${GREEN}✅ Binary updated on remote${NC}"
            echo ""
            echo "Restarting pokerchaind service..."
            
            if ! ssh "$remote_user@$remote_host" "sudo systemctl restart pokerchaind"; then
                echo -e "${YELLOW}❌ Failed to restart service${NC}"
                read -p "Press Enter to continue..."
                return
            fi
            
            echo -e "${GREEN}✅ Service restarted${NC}"
            echo ""
            echo "Checking service status..."
            sleep 2
            ssh "$remote_user@$remote_host" "sudo systemctl status pokerchaind --no-pager | head -20"
            ;;
            
        *)
            echo "Update cancelled."
            echo ""
            echo "Cleaning up temporary files on remote..."
            ssh "$remote_user@$remote_host" "rm -f /tmp/pokerchaind.new"
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
    echo "  3) Yes - Download from GitHub"
    echo ""
    read -p "Enter choice [1-3] (default: 1): " genesis_choice
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
    elif [ "$genesis_choice" = "3" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${BLUE}Download Genesis from GitHub${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        local github_repo="block52/pokerchain"
        local genesis_file="genesis.json"
        
        echo "Choose genesis file source:"
        echo "  1) Main branch (latest)"
        echo "  2) Specific tag/release"
        echo ""
        read -p "Enter choice [1-2] (default: 1): " github_choice
        github_choice=${github_choice:-1}
        
        local github_ref="main"
        
        if [ "$github_choice" = "2" ]; then
            echo ""
            read -p "Enter tag or branch name (e.g., v0.1.6): " github_ref
            if [ -z "$github_ref" ]; then
                echo -e "${YELLOW}❌ Tag/branch cannot be empty${NC}"
                echo "Using main branch instead"
                github_ref="main"
            fi
        fi
        
        local github_url="https://raw.githubusercontent.com/${github_repo}/${github_ref}/${genesis_file}"
        
        echo ""
        echo "Downloading genesis file..."
        echo "URL: $github_url"
        echo ""
        
        # Download to temporary location on remote server
        if ! ssh "$remote_user@$remote_host" "curl -L -f -o /tmp/genesis.json.new '$github_url'"; then
            echo -e "${YELLOW}❌ Failed to download genesis from GitHub${NC}"
            echo ""
            echo "Possible reasons:"
            echo "  - Invalid tag/branch name"
            echo "  - Network connectivity issue"
            echo "  - File not found in repository"
            read -p "Press Enter to continue..."
            return
        fi
        
        echo -e "${GREEN}✓${NC} Downloaded genesis file"
        
        # Validate the downloaded genesis
        echo ""
        echo "Validating downloaded genesis..."
        
        local new_chain_id=$(ssh "$remote_user@$remote_host" "cat /tmp/genesis.json.new | jq -r '.chain_id' 2>/dev/null")
        local new_app_hash=$(ssh "$remote_user@$remote_host" "cat /tmp/genesis.json.new | jq -r '.app_hash' 2>/dev/null")
        
        if [ -z "$new_chain_id" ] || [ "$new_chain_id" = "null" ]; then
            echo -e "${YELLOW}❌ Downloaded genesis file is invalid (missing chain_id)${NC}"
            ssh "$remote_user@$remote_host" "rm -f /tmp/genesis.json.new"
            read -p "Press Enter to continue..."
            return
        fi
        
        echo "Downloaded genesis file:"
        echo "  Chain ID:  $new_chain_id"
        echo "  App Hash:  ${new_app_hash:-"(empty)"}"
        echo "  Source:    $github_ref"
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
            read -p "Are you ABSOLUTELY SURE you want to change the chain ID? (type 'YES' to confirm): " chain_id_confirm
            
            if [ "$chain_id_confirm" != "YES" ]; then
                echo ""
                echo "Genesis replacement cancelled."
                ssh "$remote_user@$remote_host" "rm -f /tmp/genesis.json.new"
                return
            fi
        fi
        
        # Backup existing genesis
        echo ""
        echo "Backing up existing genesis..."
        ssh "$remote_user@$remote_host" "cp ~/.pokerchain/config/genesis.json ~/.pokerchain/config/genesis.json.backup" || {
            echo -e "${YELLOW}⚠️  Could not backup existing genesis${NC}"
        }
        
        echo "Backup created: ~/.pokerchain/config/genesis.json.backup"
        
        # Replace genesis
        echo "Installing new genesis..."
        ssh "$remote_user@$remote_host" "mv /tmp/genesis.json.new ~/.pokerchain/config/genesis.json" || {
            echo -e "${YELLOW}❌ Failed to replace genesis file${NC}"
            echo "Restoring backup..."
            ssh "$remote_user@$remote_host" "mv ~/.pokerchain/config/genesis.json.backup ~/.pokerchain/config/genesis.json"
            read -p "Press Enter to continue..."
            return
        }
        
        echo -e "${GREEN}✅ Genesis file updated from GitHub${NC}"
        echo "   Chain ID: $new_chain_id"
        echo "   App Hash: ${new_app_hash:-"(empty)"}"
        echo "   Source:   $github_ref"
        genesis_updated=true
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Backup and Reset Validator Key?${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # First, backup the current validator key
    echo "Creating backup of current validator key..."
    ssh "$remote_user@$remote_host" "cp ~/.pokerchain/config/priv_validator_key.json ~/.pokerchain/config/priv_validator_key.json.backup" || {
        echo -e "${YELLOW}⚠️  Could not backup validator key${NC}"
    }
    echo "Backup created: ~/.pokerchain/config/priv_validator_key.json.backup"
    
    # Get current validator address for display
    local current_address=$(ssh "$remote_user@$remote_host" "cat ~/.pokerchain/config/priv_validator_key.json | jq -r '.address' 2>/dev/null")
    if [ -n "$current_address" ]; then
        echo "Current validator address: $current_address"
    fi
    
    echo ""
    echo "Would you like to replace the validator key?"
    echo "  1) No - Keep existing validator key (use backup)"
    echo "  2) Yes - Generate from seed phrase (seeds.txt)"
    echo ""
    read -p "Enter choice [1-2] (default: 1): " validator_key_choice
    validator_key_choice=${validator_key_choice:-1}
    
    if [ "$validator_key_choice" = "2" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${BLUE}Generate Validator Key from Seed${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Check for genvalidatorkey tool
        local genvalidatorkey_path="./genvalidatorkey"
        if [ ! -f "$genvalidatorkey_path" ]; then
            echo -e "${YELLOW}genvalidatorkey tool not found, checking for source...${NC}"
            
            if [ -f "./genvalidatorkey.go" ]; then
                echo "Building genvalidatorkey tool..."
                if go build -o genvalidatorkey ./genvalidatorkey.go; then
                    echo -e "${GREEN}✓ Built genvalidatorkey tool${NC}"
                else
                    echo -e "${RED}❌ Failed to build genvalidatorkey tool${NC}"
                    echo "Using backed up validator key instead."
                    validator_key_choice="1"
                fi
            else
                echo -e "${RED}❌ genvalidatorkey.go not found in current directory${NC}"
                echo "Using backed up validator key instead."
                validator_key_choice="1"
            fi
        fi
        
        if [ "$validator_key_choice" = "2" ]; then
            # Try to read from seeds.txt
            local seed_phrase=""
            local seeds_file="./seeds.txt"
            
            if [ -f "$seeds_file" ]; then
                echo -e "${GREEN}Found seeds.txt file${NC}"
                echo ""
                echo "Available seed phrases:"
                
                local line_num=1
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        # Show truncated preview (first 3 words)
                        local preview=$(echo "$line" | cut -d' ' -f1-3)
                        echo "  $line_num) $preview..."
                    fi
                    ((line_num++))
                done < "$seeds_file"
                
                echo ""
                read -p "Select line number (or press Enter to type custom seed): " seed_line_num
                
                if [ -n "$seed_line_num" ]; then
                    seed_phrase=$(sed -n "${seed_line_num}p" "$seeds_file" | tr -d '\r\n')
                    
                    if [ -z "$seed_phrase" ]; then
                        echo -e "${YELLOW}❌ Invalid line number or empty line${NC}"
                        echo ""
                        read -p "Enter seed phrase manually: " seed_phrase
                    else
                        local preview=$(echo "$seed_phrase" | cut -d' ' -f1-3)
                        echo "Using seed: $preview..."
                    fi
                else
                    read -p "Enter seed phrase: " seed_phrase
                fi
            else
                echo -e "${YELLOW}seeds.txt not found${NC}"
                echo ""
                read -p "Enter seed phrase: " seed_phrase
            fi
            
            if [ -z "$seed_phrase" ]; then
                echo -e "${YELLOW}❌ Seed phrase cannot be empty${NC}"
                echo "Using backed up validator key instead."
                validator_key_choice="1"
            else
                # Generate validator key locally
                echo ""
                echo "Generating validator key from seed..."
                
                local temp_key="/tmp/priv_validator_key.json.$$"
                if echo "$seed_phrase" | ./genvalidatorkey > "$temp_key" 2>/dev/null; then
                    # Verify the generated key is valid JSON
                    local new_address=$(cat "$temp_key" | jq -r '.address' 2>/dev/null)
                    
                    if [ -n "$new_address" ] && [ "$new_address" != "null" ]; then
                        echo -e "${GREEN}✓ Generated new validator key${NC}"
                        echo "New validator address: $new_address"
                        echo ""
                        
                        # Copy to remote server
                        echo "Copying new validator key to remote server..."
                        if scp "$temp_key" "$remote_user@$remote_host:~/.pokerchain/config/priv_validator_key.json"; then
                            echo -e "${GREEN}✅ Validator key replaced${NC}"
                            echo "   Old address: $current_address"
                            echo "   New address: $new_address"
                        else
                            echo -e "${YELLOW}❌ Failed to copy validator key to remote${NC}"
                            echo "Restoring backed up key..."
                            ssh "$remote_user@$remote_host" "cp ~/.pokerchain/config/priv_validator_key.json.backup ~/.pokerchain/config/priv_validator_key.json"
                        fi
                        
                        # Clean up temp file
                        rm -f "$temp_key"
                    else
                        echo -e "${YELLOW}❌ Generated key is invalid${NC}"
                        echo "Using backed up validator key instead."
                        rm -f "$temp_key"
                    fi
                else
                    echo -e "${YELLOW}❌ Failed to generate validator key${NC}"
                    echo "Using backed up validator key instead."
                    rm -f "$temp_key"
                fi
            fi
        fi
    fi
    
    if [ "$validator_key_choice" = "1" ]; then
        echo ""
        echo -e "${GREEN}✓ Using existing validator key (preserved from backup)${NC}"
        if [ -n "$current_address" ]; then
            echo "Validator address: $current_address"
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Resetting blockchain state...${NC}"
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
    echo -e "${BLUE}Step 5: Verifying preserved files...${NC}"
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
            echo -e "${BLUE}Step 6: Starting pokerchaind service...${NC}"
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
            echo -e "${BLUE}Step 7: Create Validator Transaction? (Optional)${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "The validator KEY is already set up from Step 3."
            echo "Now you can optionally create a VALIDATOR TRANSACTION to stake tokens."
            echo ""
            echo "This requires:"
            echo "  • An account with tokens (from genesis or transferred)"
            echo "  • Chain producing blocks (at least 2-3 blocks)"
            echo ""
            echo "Would you like to create a validator transaction now?"
            echo "  1) Yes - Import account key and stake tokens"
            echo "  2) No - I'll do it manually later"
            echo ""
            read -p "Enter choice [1-2]: " validator_choice
            
            if [ "$validator_choice" = "1" ]; then
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${BLUE}Import Account Key (for signing transactions)${NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "NOTE: This is your ACCOUNT KEY (wallet), not your validator key."
                echo "      The validator key (priv_validator_key.json) is already configured."
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
                
                # Ask which account key to import
                echo "Which account (wallet) key would you like to import?"
                echo "  1) alice (default genesis account with tokens)"
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
                    echo "Balance: $balance stake"
                fi
                
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${BLUE}Validator Configuration${NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                
                read -p "Validator moniker (default: validator): " moniker
                moniker=${moniker:-validator}
                
                read -p "Amount to stake (default: 100000000000stake): " stake_amount
                stake_amount=${stake_amount:-100000000000stake}
                
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

# Deploy Remote PVM (option 10)
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

# Deploy WebSocket Server (option 12)
deploy_websocket_server() {
    print_header
    echo ""
    echo -e "${BLUE}Deploy WebSocket Server${NC}"
    echo ""
    echo "Where do you want to run the WebSocket server?"
    echo ""
    echo -e "${GREEN}1)${NC} Local Development"
    echo "   - Connects to local testnet (localhost:9090)"
    echo "   - Runs in foreground for easy debugging"
    echo "   - Perfect for testing with local chain"
    echo ""
    echo -e "${GREEN}2)${NC} Remote Production Server"
    echo "   - Deploys to remote node via SSH"
    echo "   - Creates systemd service"
    echo "   - Connects to node's local gRPC"
    echo ""
    echo -e "${GREEN}3)${NC} Back to menu"
    echo ""
    read -p "Enter choice [1-3]: " deploy_choice

    case $deploy_choice in
        1)
            deploy_websocket_server_local
            ;;
        2)
            deploy_websocket_server_remote
            ;;
        3)
            return
            ;;
        *)
            echo -e "${YELLOW}Invalid choice${NC}"
            read -p "Press Enter to continue..."
            return
            ;;
    esac
}

# Deploy WebSocket Server Locally
deploy_websocket_server_local() {
    print_header
    echo ""
    echo -e "${BLUE}Local WebSocket Server${NC}"
    echo ""

    # Build for current OS
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: Building ws-server binary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        arch="amd64"
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
        arch="arm64"
    fi

    echo "Building ws-server for $os/$arch..."
    mkdir -p ./build
    go build -o ./build/ws-server ./cmd/ws-server

    if [ ! -f "./build/ws-server" ]; then
        echo -e "${YELLOW}❌ Failed to build ws-server binary${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓${NC} Binary built successfully: ./build/ws-server"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Default local configuration
    local grpc_url="localhost:9090"
    local tendermint_ws="ws://localhost:26657/websocket"
    local ws_port="8585"
    local address_prefix="b52"

    echo "Default configuration for local testnet:"
    echo "  GRPC_URL:          $grpc_url"
    echo "  TENDERMINT_WS_URL: $tendermint_ws"
    echo "  WS_SERVER_PORT:    $ws_port"
    echo "  ADDRESS_PREFIX:    $address_prefix"
    echo ""

    read -p "Use these defaults? (y/n): " use_defaults
    if [[ ! "$use_defaults" =~ ^[Yy]$ ]]; then
        echo ""
        read -p "GRPC_URL [$grpc_url]: " custom_grpc
        grpc_url=${custom_grpc:-$grpc_url}

        read -p "TENDERMINT_WS_URL [$tendermint_ws]: " custom_tm
        tendermint_ws=${custom_tm:-$tendermint_ws}

        read -p "WS_SERVER_PORT [$ws_port]: " custom_port
        ws_port=${custom_port:-$ws_port}
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Starting WebSocket Server${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if port is already in use and kill the process
    local existing_pid=$(lsof -t -i :$ws_port 2>/dev/null)
    if [ -n "$existing_pid" ]; then
        echo -e "${YELLOW}Port $ws_port is already in use by PID $existing_pid${NC}"
        echo "Killing existing process..."
        kill $existing_pid 2>/dev/null
        sleep 1
        # Force kill if still running
        if kill -0 $existing_pid 2>/dev/null; then
            kill -9 $existing_pid 2>/dev/null
        fi
        echo -e "${GREEN}✓${NC} Killed process $existing_pid"
        echo ""
    fi

    echo -e "${YELLOW}Starting ws-server in foreground...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    echo "Endpoints:"
    echo "  WebSocket: ws://localhost:$ws_port/ws"
    echo "  Health:    http://localhost:$ws_port/health"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Run with environment variables
    GRPC_URL="$grpc_url" \
    TENDERMINT_WS_URL="$tendermint_ws" \
    WS_SERVER_PORT=":$ws_port" \
    ADDRESS_PREFIX="$address_prefix" \
    ./build/ws-server

    echo ""
    echo "WebSocket server stopped."
    read -p "Press Enter to continue..."
}

# Deploy WebSocket Server to Remote
deploy_websocket_server_remote() {
    print_header
    echo ""
    echo -e "${BLUE}Remote WebSocket Server Deployment${NC}"
    echo ""

    # Get remote host details
    echo -e "${BLUE}Enter the remote server details:${NC}"
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
    echo -e "${BLUE}Step 1: Building ws-server binary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Build the ws-server binary for Linux
    echo "Building ws-server for Linux amd64..."
    mkdir -p ./build
    GOOS=linux GOARCH=amd64 go build -o ./build/ws-server-linux ./cmd/ws-server

    if [ ! -f "./build/ws-server-linux" ]; then
        echo -e "${YELLOW}❌ Failed to build ws-server binary${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓${NC} Binary built successfully: ./build/ws-server-linux"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Testing SSH connection${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$remote_user@$remote_host" "echo 'SSH connection successful'" 2>/dev/null; then
        echo -e "${YELLOW}❌ Cannot connect to $remote_user@$remote_host${NC}"
        echo "Please ensure SSH key access is configured"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓${NC} SSH connection successful"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Uploading binary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Upload the binary
    echo "Uploading ws-server binary to $remote_host..."
    scp ./build/ws-server-linux "$remote_user@$remote_host:/tmp/ws-server"

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}❌ Failed to upload binary${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓${NC} Binary uploaded"

    # Move to /usr/local/bin and set permissions
    echo "Installing binary to /usr/local/bin..."
    ssh "$remote_user@$remote_host" "sudo mv /tmp/ws-server /usr/local/bin/ws-server && sudo chmod +x /usr/local/bin/ws-server"

    echo -e "${GREEN}✓${NC} Binary installed to /usr/local/bin/ws-server"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Creating systemd service${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Create systemd service file with environment variables
    # The ws-server connects to the LOCAL pokerchain node's gRPC and Tendermint
    cat << 'SERVICEEOF' | ssh "$remote_user@$remote_host" "sudo tee /etc/systemd/system/poker-ws.service > /dev/null"
[Unit]
Description=Poker WebSocket Server
After=network.target pokerchaind.service
Wants=pokerchaind.service

[Service]
Type=simple
User=root
# Environment variables for ws-server configuration
# GRPC_URL: Local gRPC endpoint (pokerchaind runs on 9090)
Environment="GRPC_URL=localhost:9090"
# TENDERMINT_WS_URL: Local Tendermint WebSocket for event subscriptions
Environment="TENDERMINT_WS_URL=ws://localhost:26657/websocket"
# WS_SERVER_PORT: Port for the WebSocket server to listen on
Environment="WS_SERVER_PORT=:8585"
# ADDRESS_PREFIX: Bech32 address prefix
Environment="ADDRESS_PREFIX=b52"
ExecStart=/usr/local/bin/ws-server
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

    echo -e "${GREEN}✓${NC} Systemd service file created"

    # Reload systemd and enable service
    echo "Enabling and starting service..."
    ssh "$remote_user@$remote_host" "sudo systemctl daemon-reload && sudo systemctl enable poker-ws && sudo systemctl restart poker-ws"

    echo -e "${GREEN}✓${NC} Service enabled and started"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Verifying deployment${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Wait a moment for service to start
    sleep 2

    # Check service status
    echo "Checking service status..."
    ssh "$remote_user@$remote_host" "sudo systemctl status poker-ws --no-pager -l" | head -20

    echo ""

    # Check if port 8585 is listening
    echo "Checking if WebSocket server is listening on port 8585..."
    if ssh "$remote_user@$remote_host" "ss -tlnp | grep -q ':8585'"; then
        echo -e "${GREEN}✓${NC} WebSocket server is listening on port 8585"
    else
        echo -e "${YELLOW}⚠️${NC} Port 8585 not yet listening (service may still be starting)"
    fi

    # Test health endpoint
    echo ""
    echo "Testing health endpoint..."
    local health_response=$(ssh "$remote_user@$remote_host" "curl -s http://localhost:8585/health 2>/dev/null")

    if [ -n "$health_response" ]; then
        echo -e "${GREEN}✓${NC} Health check response: $health_response"
    else
        echo -e "${YELLOW}⚠️${NC} Health endpoint not responding yet"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 6: Updating NGINX to proxy /ws to port 8585${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Update NGINX config to point /ws to port 8585 (ws-server) instead of 8545 (old PVM)
    echo "Checking NGINX configuration..."
    local nginx_updated=false

    # Check and update all site configs that have /ws pointing to wrong port
    ssh "$remote_user@$remote_host" bash << 'NGINXEOF'
        updated=false
        for conf in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*; do
            if [ -f "$conf" ] && grep -q "location /ws" "$conf" 2>/dev/null; then
                # Check if it's pointing to old port 8545
                if grep -q "proxy_pass http://127.0.0.1:8545" "$conf" 2>/dev/null; then
                    echo "  Updating $conf: 8545 -> 8585"
                    sed -i 's|proxy_pass http://127.0.0.1:8545[^;]*;|proxy_pass http://127.0.0.1:8585;|g' "$conf"
                    updated=true
                elif grep -q "proxy_pass http://127.0.0.1:8585" "$conf" 2>/dev/null; then
                    echo "  $conf: Already configured for port 8585"
                fi
            fi
        done

        if [ "$updated" = true ]; then
            echo ""
            echo "Testing NGINX configuration..."
            if nginx -t 2>&1 | grep -q "syntax is ok"; then
                echo "Reloading NGINX..."
                systemctl reload nginx
                echo "NGINX_UPDATED=true"
            else
                echo "NGINX config test failed!"
                nginx -t
            fi
        else
            echo "NGINX_UPDATED=false"
        fi
NGINXEOF

    echo -e "${GREEN}✓${NC} NGINX configuration updated"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ WebSocket Server Deployment Complete!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Deployment Summary:"
    echo "  Host:     $remote_host"
    echo "  Binary:   /usr/local/bin/ws-server"
    echo "  Service:  poker-ws.service"
    echo "  Port:     8585"
    echo ""
    echo "Useful commands:"
    echo "  Check status:  ssh $remote_user@$remote_host 'sudo systemctl status poker-ws'"
    echo "  View logs:     ssh $remote_user@$remote_host 'sudo journalctl -u poker-ws -f'"
    echo "  Restart:       ssh $remote_user@$remote_host 'sudo systemctl restart poker-ws'"
    echo "  Health check:  curl http://$remote_host:8585/health"
    echo ""
    echo "⚠️  Note: Ensure port 8585 is open in firewall (or use NGINX proxy)"
    echo ""

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
                deploy_websocket_server
                ;;
            13)
                print_header
                echo ""
                echo "Thank you for using Pokerchain Network Setup!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-13.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run pre-checks and start main loop
check_dependencies
main