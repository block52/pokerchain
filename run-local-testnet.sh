#!/bin/bash

# Local Multi-Node Testnet Runner
# Runs up to 3 nodes on the local machine with different ports

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Base directories
BASE_DIR="$HOME/.pokerchain-testnet"
CHAIN_ID="pokerchain"

# Node configurations
declare -A NODE_DIRS
declare -A NODE_P2P_PORTS
declare -A NODE_RPC_PORTS
declare -A NODE_API_PORTS
declare -A NODE_GRPC_PORTS
declare -A NODE_GRPC_WEB_PORTS

NODE_DIRS[1]="$BASE_DIR/node1"
NODE_DIRS[2]="$BASE_DIR/node2"
NODE_DIRS[3]="$BASE_DIR/node3"

NODE_P2P_PORTS[1]=26656
NODE_P2P_PORTS[2]=26666
NODE_P2P_PORTS[3]=26676

NODE_RPC_PORTS[1]=26657
NODE_RPC_PORTS[2]=26667
NODE_RPC_PORTS[3]=26677

NODE_API_PORTS[1]=1317
NODE_API_PORTS[2]=1327
NODE_API_PORTS[3]=1337

NODE_GRPC_PORTS[1]=9090
NODE_GRPC_PORTS[2]=9091
NODE_GRPC_PORTS[3]=9092

NODE_GRPC_WEB_PORTS[1]=9091
NODE_GRPC_WEB_PORTS[2]=9092
NODE_GRPC_WEB_PORTS[3]=9093

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
    echo -e "${BLUE}Initializing 3-node local testnet...${NC}"
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
            exit 0
        fi
    fi
    
    echo "Creating testnet configuration..."
    echo ""
    
    # Create testnet with 3 validators
    pokerchaind testnet init-files \
        --v 3 \
        --output-dir "$BASE_DIR" \
        --chain-id "$CHAIN_ID" \
        --keyring-backend test \
        --starting-ip-address 192.168.1.2
    
    echo ""
    echo -e "${GREEN}✅ Testnet initialized!${NC}"
    echo ""
    
    # Update ports for each node
    for i in 1 2 3; do
        local node_dir="${NODE_DIRS[$i]}"
        local config_file="$node_dir/config/config.toml"
        local app_file="$node_dir/config/app.toml"
        
        echo "Configuring Node $i ports..."
        
        # Update config.toml
        if [ -f "$config_file" ]; then
            # P2P port
            sed -i.bak "s/laddr = \"tcp:\/\/0.0.0.0:26656\"/laddr = \"tcp:\/\/0.0.0.0:${NODE_P2P_PORTS[$i]}\"/" "$config_file"
            # RPC port
            sed -i.bak "s/laddr = \"tcp:\/\/127.0.0.1:26657\"/laddr = \"tcp:\/\/127.0.0.1:${NODE_RPC_PORTS[$i]}\"/" "$config_file"
            # Allow all CORS
            sed -i.bak 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "$config_file"
        fi
        
        # Update app.toml
        if [ -f "$app_file" ]; then
            # API port
            sed -i.bak "s/address = \"tcp:\/\/localhost:1317\"/address = \"tcp:\/\/localhost:${NODE_API_PORTS[$i]}\"/" "$app_file"
            # gRPC port
            sed -i.bak "s/address = \"localhost:9090\"/address = \"localhost:${NODE_GRPC_PORTS[$i]}\"/" "$app_file"
            # gRPC-web port
            sed -i.bak "s/address = \"localhost:9091\"/address = \"localhost:${NODE_GRPC_WEB_PORTS[$i]}\"/" "$app_file"
            # Enable API
            sed -i.bak 's/enable = false/enable = true/' "$app_file"
        fi
        
        # Clean up backup files
        rm -f "$config_file.bak" "$app_file.bak"
    done
    
    echo ""
    echo -e "${GREEN}✅ All nodes configured!${NC}"
    echo ""
    echo "Node configurations:"
    for i in 1 2 3; do
        echo -e "${GREEN}Node $i:${NC}"
        echo "  Home: ${NODE_DIRS[$i]}"
        echo "  P2P:  ${NODE_P2P_PORTS[$i]}"
        echo "  RPC:  ${NODE_RPC_PORTS[$i]}"
        echo "  API:  ${NODE_API_PORTS[$i]}"
        echo "  gRPC: ${NODE_GRPC_PORTS[$i]}"
        echo ""
    done
    
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
        local pid_file="${NODE_DIRS[$i]}/pokerchaind.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                echo -e "  Status: ${GREEN}Running${NC} (PID: $pid)"
                
                # Try to get block height
                local rpc_port="${NODE_RPC_PORTS[$i]}"
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
        
        echo "  RPC:  http://localhost:${NODE_RPC_PORTS[$i]}"
        echo "  API:  http://localhost:${NODE_API_PORTS[$i]}"
        echo ""
    done
    
    read -p "Press Enter to continue..."
}

# Start a specific node
start_node() {
    local node_num=$1
    local node_dir="${NODE_DIRS[$node_num]}"
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
    echo "  P2P:     ${NODE_P2P_PORTS[$node_num]}"
    echo "  RPC:     http://localhost:${NODE_RPC_PORTS[$node_num]}"
    echo "  API:     http://localhost:${NODE_API_PORTS[$node_num]}"
    echo "  gRPC:    localhost:${NODE_GRPC_PORTS[$node_num]}"
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
    local pid_file="${NODE_DIRS[$node_num]}/pokerchaind.pid"
    
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
        local pid_file="${NODE_DIRS[$i]}/pokerchaind.pid"
        local status="${RED}●${NC} Stopped"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                status="${GREEN}●${NC} Running"
            fi
        fi
        echo -e "  Node $i: $status (RPC: ${NODE_RPC_PORTS[$i]}, API: ${NODE_API_PORTS[$i]})"
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
                    local pid_file="${NODE_DIRS[$i]}/pokerchaind.pid"
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
