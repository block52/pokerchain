#!/bin/bash

# Local Multi-Node Testnet Runner
# Runs up to 3 nodes on the local machine with different ports

set -e

# Load environment variables from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
    echo "✅ Loaded .env configuration"
else
    echo "⚠️  Warning: .env file not found"
    echo "   Bridge service may not work. See documents/BRIDGE_CONFIGURATION.md"
fi

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Base directories
BASE_DIR="$HOME/.pokerchain-testnet"
CHAIN_ID="pokerchain"

# Helper functions for node configurations (bash 3.2 compatible)
get_node_dir() {
    echo "$BASE_DIR/node$1"
}

get_p2p_port() {
    case $1 in
        1) echo 26656 ;;
        2) echo 26666 ;;
        3) echo 26676 ;;
    esac
}

get_rpc_port() {
    case $1 in
        1) echo 26657 ;;
        2) echo 26667 ;;
        3) echo 26677 ;;
    esac
}

get_api_port() {
    case $1 in
        1) echo 1317 ;;
        2) echo 1327 ;;
        3) echo 1337 ;;
    esac
}

get_grpc_port() {
    case $1 in
        1) echo 9090 ;;
        2) echo 9091 ;;
        3) echo 9092 ;;
    esac
}

get_grpc_web_port() {
    case $1 in
        1) echo 9091 ;;
        2) echo 9092 ;;
        3) echo 9093 ;;
    esac
}

# Print header
print_header() {
    clear
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🎲 Local Multi-Node Testnet 🎲"
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

# Initialize testnet
init_testnet() {
    print_header
    echo -e "${BLUE}Local Testnet Initialization${NC}"
    echo ""

    # Ask how many nodes
    echo "How many nodes do you want to run?"
    echo ""
    echo -e "${GREEN}1)${NC} Single Node (fast, perfect for most testing including withdrawals)"
    echo -e "${GREEN}2)${NC} 3 Nodes (multi-validator consensus testing)"
    echo ""
    read -p "Enter choice [1-2]: " node_count_choice

    local num_nodes=1
    if [ "$node_count_choice" = "2" ]; then
        num_nodes=3
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Ask which genesis method
    echo "Which genesis method do you want to use?"
    echo ""
    echo -e "${GREEN}1)${NC} config.yml Method (Ignite - fast, easy, development)"
    echo "   • Uses config.yml for genesis accounts"
    echo "   • Faster setup (~5 seconds)"
    echo "   • Good for rapid iteration"
    echo ""
    echo -e "${GREEN}2)${NC} CLI Commands Method (Production-like - catches production bugs)"
    echo "   • Uses 'pokerchaind genesis' commands"
    echo "   • Same as production deployment"
    echo "   • Better for pre-production testing"
    echo "   • Recommended for withdrawal testing"
    echo ""
    read -p "Enter choice [1-2]: " genesis_method_choice

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$genesis_method_choice" = "1" ]; then
        echo -e "${BLUE}Using config.yml (Ignite) method...${NC}"
        init_testnet_with_config_yml $num_nodes
    else
        echo -e "${BLUE}Using production CLI commands method...${NC}"
        init_testnet_with_cli $num_nodes
    fi
}

# Initialize using config.yml (ignite method)
init_testnet_with_config_yml() {
    local num_nodes=$1

    echo ""
    echo -e "${YELLOW}⚠️  Note: This method uses Ignite CLI with config.yml${NC}"
    echo -e "${YELLOW}   Make sure config.yml has your bridge validator key configured!${NC}"
    echo ""
    read -p "Press Enter to continue..."

    # Clean old data
    if [ -d "$BASE_DIR" ]; then
        echo -e "${YELLOW}⚠️  Existing testnet data found at $BASE_DIR${NC}"
        read -p "Delete and recreate? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Removing old data..."
            rm -rf "$BASE_DIR"
        else
            echo "Cancelled."
            return
        fi
    fi

    echo ""
    echo -e "${RED}❌ Sorry, config.yml method not yet fully implemented for local testnet${NC}"
    echo -e "${YELLOW}   For now, please use CLI method (option 2)${NC}"
    echo -e "${YELLOW}   OR run: ignite chain serve --reset-once${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Initialize using CLI commands (production method)
init_testnet_with_cli() {
    local num_nodes=$1

    echo ""
    echo -e "${YELLOW}Setting up $num_nodes node(s) using production CLI commands...${NC}"
    echo ""

    # Clean old data
    if [ -d "$BASE_DIR" ]; then
        echo -e "${YELLOW}⚠️  Existing testnet data found at $BASE_DIR${NC}"
        read -p "Delete and recreate? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Removing old data..."
            rm -rf "$BASE_DIR"
        else
            echo "Cancelled."
            return
        fi
    fi

    # Create base directory
    mkdir -p "$BASE_DIR"

    echo "Initializing Node 1..."
    echo ""

    # Initialize node 1 using standard pokerchaind init
    local node1_dir="$(get_node_dir 1)"
    pokerchaind init node1 --chain-id "$CHAIN_ID" --home "$node1_dir" --default-denom stake

    # Add a test key
    echo "Creating test validator key..."
    pokerchaind keys add validator --keyring-backend test --home "$node1_dir" 2>&1 | grep -E "address:|mnemonic:" || true

    # Get the validator address
    local validator_addr=$(pokerchaind keys show validator -a --keyring-backend test --home "$node1_dir")

    # Add genesis account with funds (STAKE only - USDC comes from bridge)
    echo ""
    echo "Adding genesis account with funds..."
    pokerchaind genesis add-genesis-account "$validator_addr" 1000000000000stake --home "$node1_dir"

    # Generate genesis transaction
    echo "Creating genesis transaction..."
    pokerchaind genesis gentx validator 5000000000stake \
        --chain-id "$CHAIN_ID" \
        --keyring-backend test \
        --home "$node1_dir"

    # Collect genesis transactions
    echo "Collecting genesis transactions..."
    pokerchaind genesis collect-gentxs --home "$node1_dir"

    # Validate genesis
    echo "Validating genesis..."
    pokerchaind genesis validate --home "$node1_dir"

    echo ""
    echo -e "${GREEN}✅ Node 1 initialized with production-style genesis!${NC}"
    echo ""

    # Ask if user wants to import bridge state
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}🌉 Import Bridge State from Previous Chain?${NC}"
    echo ""
    echo "If you have withdrawal records from a previous chain that you want to preserve,"
    echo "you can paste the bridge state JSON here (from http://localhost:5173/genesis)."
    echo ""
    read -p "Import bridge state? (y/n): " import_bridge

    if [[ "$import_bridge" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}📋 Paste your bridge state JSON below, then press Ctrl+D:${NC}"
        echo ""

        # Read multi-line JSON input
        bridge_state_json=$(cat)

        if [ -n "$bridge_state_json" ]; then
            local genesis_file="$node1_dir/config/genesis.json"
            local genesis_backup="$node1_dir/config/genesis.json.backup"

            # Backup genesis
            cp "$genesis_file" "$genesis_backup"

            echo ""
            echo "Injecting bridge state into genesis..."

            # Use jq to merge bridge state into poker module
            jq --argjson bridge "$bridge_state_json" \
                '.app_state.poker.withdrawal_requests = $bridge.withdrawal_requests' \
                "$genesis_file" > "$genesis_file.tmp"

            if [ $? -eq 0 ]; then
                mv "$genesis_file.tmp" "$genesis_file"

                # Validate genesis again
                echo "Validating genesis with bridge state..."
                if pokerchaind genesis validate --home "$node1_dir" 2>&1 | grep -q "successfully"; then
                    echo -e "${GREEN}✅ Bridge state imported successfully!${NC}"
                    echo ""
                    echo "Imported withdrawals: $(echo "$bridge_state_json" | jq '.withdrawal_requests | length')"
                    rm -f "$genesis_backup"
                else
                    echo -e "${RED}❌ Genesis validation failed after import!${NC}"
                    echo "Restoring original genesis..."
                    mv "$genesis_backup" "$genesis_file"
                fi
            else
                echo -e "${RED}❌ Failed to parse JSON. Keeping original genesis.${NC}"
                rm -f "$genesis_file.tmp"
            fi
        else
            echo -e "${YELLOW}⚠️  No JSON provided, skipping bridge state import${NC}"
        fi

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi

    # Configure Node 1 settings
    local node_dir="$(get_node_dir 1)"
    local config_file="$node_dir/config/config.toml"
    local app_file="$node_dir/config/app.toml"

    echo "Configuring Node 1 settings..."

    # Update config.toml
    if [ -f "$config_file" ]; then
        # Allow all CORS for development
        sed -i.bak 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "$config_file"
        echo "  ✅ Enabled CORS"
    fi

    # Update app.toml
    if [ -f "$app_file" ]; then
        # Enable API
        sed -i.bak 's/enable = false/enable = true/' "$app_file"
        echo "  ✅ Enabled API server"

        # Enable CORS for API (allows UI at localhost:5173 to connect)
        sed -i.bak 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$app_file"
        echo "  ✅ Enabled API CORS (for UI development)"

        # Inject Alchemy URL from .env if available
        if [ -n "$ALCHEMY_URL" ]; then
            # Update ethereum_rpc_url in bridge section
            sed -i.bak "s|ethereum_rpc_url = .*|ethereum_rpc_url = \"$ALCHEMY_URL\"|" "$app_file"
            echo "  ✅ Configured bridge with Alchemy URL"
            echo "     URL: ${ALCHEMY_URL:0:50}..."
        else
            echo "  ⚠️  No ALCHEMY_URL found in .env - bridge will use default config"
        fi
    fi

    # Clean up backup files
    rm -f "$config_file.bak" "$app_file.bak"
    
    echo ""
    echo -e "${GREEN}✅ Node 1 configured and ready!${NC}"
    echo ""
    echo "Node 1 configuration:"
    echo "  Home: $(get_node_dir 1)"
    echo "  P2P:  $(get_p2p_port 1)"
    echo "  RPC:  http://localhost:$(get_rpc_port 1)"
    echo "  API:  http://localhost:$(get_api_port 1)"
    echo "  gRPC: localhost:$(get_grpc_port 1)"
    echo ""
    echo -e "${YELLOW}To start the node, select option 2 from the menu${NC}"
    echo ""

    read -p "Press Enter to continue..."
}

# Show node status
show_status() {
    print_header
    echo -e "${BLUE}Node Status:${NC}"
    echo ""
    
    for i in 1 2 3; do
        echo -e "${GREEN}Node $i:${NC}"
        
        # Check if process is running
        local pid_file="$(get_node_dir $i)/pokerchaind.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                echo -e "  Status: ${GREEN}Running${NC} (PID: $pid)"
                
                # Try to get block height
                local rpc_port="$(get_rpc_port $i)"
                if curl -s --max-time 2 "http://localhost:$rpc_port/status" > /dev/null 2>&1; then
                    local height=$(curl -s "http://localhost:$rpc_port/status" | jq -r '.result.sync_info.latest_block_height' 2>/dev/null)
                    if [ -n "$height" ] && [ "$height" != "null" ]; then
                        echo "  Block Height: $height"
                    fi
                fi
            else
                echo -e "  Status: ${RED}Stopped${NC} (stale PID file)"
                rm -f "$pid_file"
            fi
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
        
        echo "  RPC:  http://localhost:$(get_rpc_port $i)"
        echo "  API:  http://localhost:$(get_api_port $i)"
        echo ""
    done
    
    read -p "Press Enter to continue..."
}

# Start a specific node
start_node() {
    local node_num=$1
    local node_dir="$(get_node_dir $node_num)"
    local pid_file="$node_dir/pokerchaind.pid"
    
    print_header
    echo -e "${BLUE}Starting Node $node_num...${NC}"
    echo ""
    
    # Check if node directory exists
    if [ ! -d "$node_dir" ]; then
        echo -e "${RED}❌ Node $node_num not initialized${NC}"
        echo ""
        echo "Please run 'Initialize Testnet' first."
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    # Check if already running
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Node $node_num is already running (PID: $pid)${NC}"
            echo ""
            read -p "Press Enter to continue..."
            return
        else
            rm -f "$pid_file"
        fi
    fi
    
    echo "Node $node_num Configuration:"
    echo "  Home:    $node_dir"
    echo "  P2P:     $(get_p2p_port $node_num)"
    echo "  RPC:     http://localhost:$(get_rpc_port $node_num)"
    echo "  API:     http://localhost:$(get_api_port $node_num)"
    echo "  gRPC:    localhost:$(get_grpc_port $node_num)"
    echo ""
    echo -e "${YELLOW}Starting node in foreground...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the node and return to menu${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Trap Ctrl+C to clean up
    trap "echo ''; echo 'Node stopped.'; rm -f '$pid_file'; read -p 'Press Enter to continue...'; trap - INT; return" INT
    
    # Start the node
    pokerchaind start \
        --home "$node_dir" \
        --minimum-gas-prices="0.01stake" \
        --log_level info
    
    # Clean up trap
    trap - INT
}

# Stop a specific node
stop_node() {
    local node_num=$1
    local pid_file="$(get_node_dir $node_num)/pokerchaind.pid"
    
    echo "Stopping Node $node_num..."
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid"
            rm -f "$pid_file"
            echo -e "${GREEN}✅ Node $node_num stopped${NC}"
        else
            rm -f "$pid_file"
            echo -e "${YELLOW}⚠️  Node $node_num was not running${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Node $node_num was not running${NC}"
    fi
}

# Stop all nodes
stop_all() {
    print_header
    echo -e "${BLUE}Stopping all nodes...${NC}"
    echo ""
    
    for i in 1 2 3; do
        stop_node $i
    done
    
    echo ""
    echo -e "${GREEN}✅ All nodes stopped${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Show menu
show_menu() {
    print_header
    
    # Show quick status
    echo -e "${BLUE}Quick Status:${NC}"
    for i in 1 2 3; do
        local pid_file="$(get_node_dir $i)/pokerchaind.pid"
        local status="${RED}●${NC} Stopped"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                status="${GREEN}●${NC} Running"
            fi
        fi
        echo -e "  Node $i: $status (RPC: $(get_rpc_port $i), API: $(get_api_port $i))"
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Select an option:"
    echo ""
    echo -e "${GREEN}1)${NC} Initialize Testnet (first time setup)"
    echo -e "${GREEN}2)${NC} Start Node 1 (Validator)"
    echo -e "${GREEN}3)${NC} Start Node 2 (Validator)"
    echo -e "${GREEN}4)${NC} Start Node 3 (Validator)"
    echo -e "${GREEN}5)${NC} Show Detailed Status"
    echo -e "${GREEN}6)${NC} Stop All Nodes"
    echo -e "${GREEN}7)${NC} Clean & Reset Testnet"
    echo -e "${GREEN}8)${NC} Exit"
    echo ""
    echo -n "Enter your choice [1-8]: "
}

# Clean testnet
clean_testnet() {
    print_header
    echo -e "${YELLOW}⚠️  Warning: This will delete ALL testnet data!${NC}"
    echo ""
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" = "yes" ]; then
        echo ""
        echo "Stopping all nodes..."
        for i in 1 2 3; do
            stop_node $i
        done
        
        echo ""
        echo "Removing testnet data..."
        rm -rf "$BASE_DIR"
        
        echo ""
        echo -e "${GREEN}✅ Testnet data cleaned${NC}"
    else
        echo "Cancelled."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    check_binary
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                init_testnet
                ;;
            2)
                start_node 1
                ;;
            3)
                start_node 2
                ;;
            4)
                start_node 3
                ;;
            5)
                show_status
                ;;
            6)
                stop_all
                ;;
            7)
                clean_testnet
                ;;
            8)
                print_header
                echo ""
                echo "Thank you for using Local Multi-Node Testnet!"
                echo ""
                
                # Stop any running nodes
                echo "Checking for running nodes..."
                for i in 1 2 3; do
                    local pid_file="$(get_node_dir $i)/pokerchaind.pid"
                    if [ -f "$pid_file" ]; then
                        local pid=$(cat "$pid_file")
                        if ps -p "$pid" > /dev/null 2>&1; then
                            echo "Note: Node $i is still running. Stop it with option 6 if needed."
                        fi
                    fi
                done
                
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${YELLOW}Invalid option. Please choose 1-8.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run main
main
