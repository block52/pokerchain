#!/bin/bash

# Production Nodes Setup Script
# Generates configuration for production nodes in /production/nodeX directories
# These configs can then be deployed via SSH to remote servers

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROD_DIR="./production"
CHAIN_ID="pokerchain"
GENESIS_NODE="node1.block52.xyz"
GENESIS_RPC_PORT=26657

# Default node configuration
DEFAULT_MONIKER_PREFIX="pokerchain-prod"

# Print header
print_header() {
    clear
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🎲 Production Nodes Setup 🎲"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Check if pokerchaind is installed
check_binary() {
    if ! command -v pokerchaind &> /dev/null; then
        echo -e "${RED}❌ pokerchaind not found in PATH${NC}"
        echo ""
        echo "Please install pokerchaind first:"
        echo "  make install"
        echo ""
        exit 1
    fi
}

# Get genesis file from genesis node
fetch_genesis() {
    local output_file="$1"
    
    echo "Fetching genesis file from $GENESIS_NODE..."
    
    if curl -s --max-time 10 "http://$GENESIS_NODE:$GENESIS_RPC_PORT/genesis" | jq -r '.result.genesis' > "$output_file" 2>/dev/null; then
        echo -e "${GREEN}✅ Genesis file downloaded${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to download genesis file${NC}"
        echo ""
        echo "Please ensure $GENESIS_NODE is accessible and running."
        return 1
    fi
}

# Get persistent peers from genesis node
get_persistent_peers() {
    echo "Getting node ID from $GENESIS_NODE..."
    
    local node_id=$(curl -s "http://$GENESIS_NODE:$GENESIS_RPC_PORT/status" | jq -r '.result.node_info.id' 2>/dev/null)
    
    if [ -n "$node_id" ] && [ "$node_id" != "null" ]; then
        echo "$node_id@$GENESIS_NODE:26656"
        return 0
    else
        echo -e "${YELLOW}⚠️  Could not get node ID from $GENESIS_NODE${NC}"
        return 1
    fi
}

# Initialize a production node
init_production_node() {
    local node_num=$1
    local node_name=$2
    local node_host=$3
    local node_type=$4  # validator or sync
    
    local node_dir="$PROD_DIR/node$node_num"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Setting up Node $node_num: $node_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Create node directory
    if [ -d "$node_dir" ]; then
        echo -e "${YELLOW}⚠️  Node directory exists: $node_dir${NC}"
        read -p "Delete and recreate? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$node_dir"
        else
            echo "Skipping node $node_num"
            return
        fi
    fi
    
    mkdir -p "$node_dir"
    
    # Initialize node
    echo "Initializing node..."
    pokerchaind init "$node_name" \
        --chain-id "$CHAIN_ID" \
        --home "$node_dir" \
        --overwrite
    
    # Download genesis file
    echo ""
    if ! fetch_genesis "$node_dir/config/genesis.json"; then
        echo -e "${RED}Failed to setup node $node_num${NC}"
        return 1
    fi
    
    # Get persistent peers
    echo ""
    local peers=$(get_persistent_peers)
    
    if [ -z "$peers" ]; then
        echo -e "${YELLOW}⚠️  No persistent peers found, continuing anyway...${NC}"
        peers=""
    else
        echo -e "${GREEN}✅ Persistent peers: $peers${NC}"
    fi
    
    # Configure config.toml
    local config_file="$node_dir/config/config.toml"
    echo ""
    echo "Configuring config.toml..."
    
    # Set persistent peers
    if [ -n "$peers" ]; then
        sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$peers\"/" "$config_file"
    fi
    
    # Enable CORS
    sed -i.bak 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "$config_file"
    
    # Set external address if provided
    if [ -n "$node_host" ]; then
        sed -i.bak "s/external_address = \"\"/external_address = \"$node_host:26656\"/" "$config_file"
    fi
    
    # Configure app.toml
    local app_file="$node_dir/config/app.toml"
    echo "Configuring app.toml..."
    
    # Enable API
    sed -i.bak 's/enable = false/enable = true/' "$app_file"
    
    # Enable unsafe CORS (for production, consider restricting this)
    sed -i.bak 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$app_file"
    
    # Set minimum gas prices
    sed -i.bak 's/minimum-gas-prices = ""/minimum-gas-prices = "0.01stake"/' "$app_file"
    
    # Clean up backup files
    rm -f "$config_file.bak" "$app_file.bak"
    
    # Create deployment info file
    cat > "$node_dir/deployment-info.txt" << EOF
Node Information
================

Node Number: $node_num
Node Name: $node_name
Node Type: $node_type
Target Host: $node_host
Chain ID: $CHAIN_ID
Genesis Node: $GENESIS_NODE

Configuration Files
===================
- $node_dir/config/genesis.json
- $node_dir/config/config.toml
- $node_dir/config/app.toml

Deployment Steps
================

1. Build and copy binary to remote server:
   GOOS=linux GOARCH=amd64 make build
   scp build/pokerchaind $node_host:/usr/local/bin/

2. Copy configuration files:
   ssh $node_host "mkdir -p ~/.pokerchain/config"
   scp -r $node_dir/config/* $node_host:~/.pokerchain/config/

3. Setup systemd service:
   scp pokerchaind.service $node_host:/etc/systemd/system/
   ssh $node_host "systemctl daemon-reload && systemctl enable pokerchaind"

4. Start the node:
   ssh $node_host "systemctl start pokerchaind"

5. Check status:
   ssh $node_host "systemctl status pokerchaind"
   ssh $node_host "journalctl -u pokerchaind -f"

Quick Deploy Command
====================
./deploy-production-node.sh $node_num $node_host

Endpoints (after deployment)
=============================
RPC:  http://$node_host:26657
API:  http://$node_host:1317
gRPC: $node_host:9090

Node ID
=======
(Will be generated on first start)

EOF
    
    # Create quick deploy script for this node
    cat > "$node_dir/deploy.sh" << EOF
#!/bin/bash
# Quick deploy script for $node_name

set -e

NODE_HOST="$node_host"
NODE_DIR="$node_dir"
REMOTE_USER="\${1:-root}"

echo "Deploying $node_name to \$NODE_HOST as \$REMOTE_USER..."
echo ""

# Build binary for Linux
echo "Building Linux binary..."
GOOS=linux GOARCH=amd64 make build

# Copy binary
echo "Copying binary..."
scp build/pokerchaind \$REMOTE_USER@\$NODE_HOST:/usr/local/bin/

# Copy configuration
echo "Copying configuration files..."
ssh \$REMOTE_USER@\$NODE_HOST "mkdir -p ~/.pokerchain/config ~/.pokerchain/data"
scp -r \$NODE_DIR/config/* \$REMOTE_USER@\$NODE_HOST:~/.pokerchain/config/

# Setup systemd
echo "Setting up systemd service..."
scp pokerchaind.service \$REMOTE_USER@\$NODE_HOST:/tmp/
ssh \$REMOTE_USER@\$NODE_HOST "sudo mv /tmp/pokerchaind.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable pokerchaind"

# Start node
echo "Starting node..."
ssh \$REMOTE_USER@\$NODE_HOST "sudo systemctl start pokerchaind"

echo ""
echo "Deployment complete! Checking status..."
sleep 3
ssh \$REMOTE_USER@\$NODE_HOST "sudo systemctl status pokerchaind --no-pager"

echo ""
echo "Monitor logs with:"
echo "  ssh \$REMOTE_USER@\$NODE_HOST 'journalctl -u pokerchaind -f'"
echo ""
echo "Check sync status:"
echo "  curl http://\$NODE_HOST:26657/status"
EOF
    
    chmod +x "$node_dir/deploy.sh"
    
    # If validator node, create validator setup instructions
    if [ "$node_type" = "validator" ]; then
        cat > "$node_dir/become-validator.sh" << EOF
#!/bin/bash
# Instructions to become a validator

echo "To make this node a validator, run these commands on the server:"
echo ""
echo "1. Create a validator key:"
echo "   pokerchaind keys add validator --keyring-backend test"
echo ""
echo "2. Fund the validator account (get address from step 1)"
echo "   Request tokens from faucet or transfer from another account"
echo ""
echo "3. Create validator:"
echo "   pokerchaind tx staking create-validator \\\\"
echo "     --amount=1000000stake \\\\"
echo "     --pubkey=\\\$(pokerchaind tendermint show-validator) \\\\"
echo "     --moniker=\"$node_name\" \\\\"
echo "     --chain-id=\"$CHAIN_ID\" \\\\"
echo "     --commission-rate=\"0.10\" \\\\"
echo "     --commission-max-rate=\"0.20\" \\\\"
echo "     --commission-max-change-rate=\"0.01\" \\\\"
echo "     --min-self-delegation=\"1\" \\\\"
echo "     --gas=\"auto\" \\\\"
echo "     --gas-prices=\"0.01stake\" \\\\"
echo "     --from=validator \\\\"
echo "     --keyring-backend test"
echo ""
echo "4. Check validator status:"
echo "   pokerchaind query staking validator \\\$(pokerchaind keys show validator --bech val -a --keyring-backend test)"
EOF
        chmod +x "$node_dir/become-validator.sh"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Node $node_num configured successfully!${NC}"
    echo ""
    echo "Configuration saved to: $node_dir"
    echo "Deployment info: $node_dir/deployment-info.txt"
    echo "Quick deploy: $node_dir/deploy.sh <remote-user>"
    
    if [ "$node_type" = "validator" ]; then
        echo "Validator setup: $node_dir/become-validator.sh"
    fi
}

# Interactive setup
interactive_setup() {
    print_header
    echo ""
    echo "This script will generate production node configurations."
    echo "Each node will be configured to connect to: $GENESIS_NODE"
    echo ""
    echo "Configurations will be saved to: $PROD_DIR/nodeX/"
    echo ""
    read -p "How many production nodes to configure? [1-10]: " num_nodes
    
    # Validate input
    if ! [[ "$num_nodes" =~ ^[0-9]+$ ]] || [ "$num_nodes" -lt 1 ] || [ "$num_nodes" -gt 10 ]; then
        echo -e "${RED}Invalid number. Please enter 1-10.${NC}"
        exit 1
    fi
    
    echo ""
    echo "You will be prompted for details for each node."
    echo ""
    read -p "Press Enter to continue..."
    
    # Create production directory
    mkdir -p "$PROD_DIR"
    
    # Setup each node
    for i in $(seq 1 $num_nodes); do
        print_header
        echo ""
        echo -e "${BLUE}Configuring Node $i of $num_nodes${NC}"
        echo ""
        
        read -p "Node name/moniker (default: $DEFAULT_MONIKER_PREFIX-$i): " node_name
        node_name=${node_name:-$DEFAULT_MONIKER_PREFIX-$i}
        
        read -p "Target hostname/IP (e.g., node$i.block52.xyz): " node_host
        
        echo ""
        echo "Node type:"
        echo "  1) Sync Node (read-only, no validation)"
        echo "  2) Validator Node (participates in consensus)"
        read -p "Select type [1-2]: " node_type_choice
        
        case $node_type_choice in
            1)
                node_type="sync"
                ;;
            2)
                node_type="validator"
                ;;
            *)
                echo -e "${YELLOW}Invalid choice, defaulting to sync node${NC}"
                node_type="sync"
                ;;
        esac
        
        # Initialize the node
        init_production_node "$i" "$node_name" "$node_host" "$node_type"
        
        echo ""
        if [ $i -lt $num_nodes ]; then
            read -p "Press Enter to configure next node..."
        fi
    done
    
    # Create summary
    print_header
    echo ""
    echo -e "${GREEN}✅ All nodes configured!${NC}"
    echo ""
    echo "Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    for i in $(seq 1 $num_nodes); do
        if [ -f "$PROD_DIR/node$i/deployment-info.txt" ]; then
            local node_name=$(grep "Node Name:" "$PROD_DIR/node$i/deployment-info.txt" | cut -d: -f2 | xargs)
            local node_host=$(grep "Target Host:" "$PROD_DIR/node$i/deployment-info.txt" | cut -d: -f2 | xargs)
            local node_type=$(grep "Node Type:" "$PROD_DIR/node$i/deployment-info.txt" | cut -d: -f2 | xargs)
            
            echo "Node $i: $node_name"
            echo "  Type: $node_type"
            echo "  Host: $node_host"
            echo "  Config: $PROD_DIR/node$i/"
            echo "  Deploy: $PROD_DIR/node$i/deploy.sh"
            echo ""
        fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Review configurations in $PROD_DIR/nodeX/"
    echo ""
    echo "2. Deploy a node:"
    echo "   cd $PROD_DIR/node1"
    echo "   ./deploy.sh <remote-user>"
    echo ""
    echo "3. Or use the master deployment script:"
    echo "   ./deploy-production-node.sh <node-number> <remote-host> [remote-user]"
    echo ""
    echo "4. Monitor deployment:"
    echo "   ssh <remote-host> 'journalctl -u pokerchaind -f'"
    echo ""
}

# Quick setup mode (non-interactive)
quick_setup() {
    local node_num=$1
    local node_name=$2
    local node_host=$3
    local node_type=${4:-sync}
    
    print_header
    
    mkdir -p "$PROD_DIR"
    
    init_production_node "$node_num" "$node_name" "$node_host" "$node_type"
    
    echo ""
    echo "Node configuration complete!"
    echo ""
    echo "Deploy with:"
    echo "  $PROD_DIR/node$node_num/deploy.sh"
}

# Show usage
usage() {
    echo "Usage:"
    echo "  $0                                          # Interactive mode"
    echo "  $0 <node-num> <name> <host> [type]        # Quick setup mode"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Interactive setup"
    echo "  $0 2 node2.block52.xyz node2.block52.xyz sync"
    echo "  $0 3 validator1 192.168.1.100 validator"
    echo ""
    echo "Node types: sync, validator"
}

# Main
main() {
    check_binary
    
    if [ $# -eq 0 ]; then
        # Interactive mode
        interactive_setup
    elif [ $# -ge 3 ]; then
        # Quick setup mode
        quick_setup "$1" "$2" "$3" "$4"
    else
        usage
        exit 1
    fi
}

# Run
main "$@"
