#!/bin/bash

# Local Network Manager Script
# Usage: ./manage-local-nodes.sh [start|stop|status|logs] [chain_binary]

set -e

COMMAND=${1:-"start"}
OUTPUT_DIR="./test"
CHAIN_BINARY_NAME="pokerchaind"
CHAIN_BINARY=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect and set chain binary location
detect_binary() {
    local user_binary=$1
    
    # If user provided a binary path as argument, use it
    if [ -n "$user_binary" ]; then
        if [ -f "$user_binary" ]; then
            CHAIN_BINARY="$user_binary"
            return 0
        elif command -v "$user_binary" &> /dev/null; then
            CHAIN_BINARY="$user_binary"
            return 0
        fi
    fi
    
    # Check if we have a saved binary path from setup
    if [ -f "$OUTPUT_DIR/.chain_binary" ]; then
        SAVED_BINARY=$(cat "$OUTPUT_DIR/.chain_binary")
        if [ -f "$SAVED_BINARY" ]; then
            CHAIN_BINARY="$SAVED_BINARY"
            return 0
        elif command -v "$SAVED_BINARY" &> /dev/null; then
            CHAIN_BINARY="$SAVED_BINARY"
            return 0
        fi
    fi
    
    # Check if binary is in ./build directory (preferred default)
    if [ -f "./build/$CHAIN_BINARY_NAME" ]; then
        CHAIN_BINARY="./build/$CHAIN_BINARY_NAME"
        return 0
    fi
    
    # Check if binary is in PATH
    if command -v "$CHAIN_BINARY_NAME" &> /dev/null; then
        CHAIN_BINARY="$CHAIN_BINARY_NAME"
        return 0
    fi
    
    # Binary not found
    echo -e "${RED}Error: $CHAIN_BINARY_NAME not found.${NC}"
    echo "Please ensure the binary is built:"
    echo "  make build"
    echo "  # or"
    echo "  make install"
    exit 1
}

detect_binary "$2"

# Show which binary we're using (only for start command)
if [ "$COMMAND" = "start" ]; then
    echo -e "${GREEN}Using binary: ${YELLOW}${CHAIN_BINARY}${NC}"
fi

# Count nodes
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}Error: Testnet directory not found. Run setup-testnet.sh first.${NC}"
    exit 1
fi

NUM_NODES=$(ls -d $OUTPUT_DIR/node* 2>/dev/null | wc -l)

start_nodes() {
    echo -e "${GREEN}Starting $NUM_NODES nodes...${NC}"
    for i in $(seq 0 $((NUM_NODES - 1))); do
        NODE_HOME="$OUTPUT_DIR/node$i"
        LOG_FILE="$OUTPUT_DIR/node$i.log"
        
        if pgrep -f "$CHAIN_BINARY start --home $NODE_HOME" > /dev/null; then
            echo -e "  ${YELLOW}⚠${NC}  Node$i is already running"
        else
            $CHAIN_BINARY start --home $NODE_HOME > $LOG_FILE 2>&1 &
            echo -e "  ${GREEN}✓${NC} Started node$i (PID: $!)"
        fi
    done
    echo ""
    echo -e "${GREEN}All nodes started!${NC}"
    echo "Run './manage-testnet.sh status' to check node status"
    echo "Run './manage-testnet.sh logs [node_number]' to view logs"
}

stop_nodes() {
    echo -e "${YELLOW}Stopping all nodes...${NC}"
    pkill -f "$CHAIN_BINARY start" && echo -e "${GREEN}✓${NC} All nodes stopped" || echo -e "${YELLOW}No running nodes found${NC}"
}

status_nodes() {
    echo -e "${GREEN}Node Status:${NC}"
    echo ""
    for i in $(seq 0 $((NUM_NODES - 1))); do
        NODE_HOME="$OUTPUT_DIR/node$i"
        RPC_PORT=$((26657 + i))
        API_PORT=$((1317 + i))
        
        if pgrep -f "$CHAIN_BINARY start --home $NODE_HOME" > /dev/null; then
            echo -e "${GREEN}Node$i: RUNNING${NC}"
            
            # Try to get block height with better parsing
            if command -v curl &> /dev/null; then
                HEIGHT=$(curl -s http://localhost:$RPC_PORT/status 2>/dev/null | grep -oE '"latest_block_height":"[0-9]+"' | grep -oE '[0-9]+' || echo "N/A")
                if [ -z "$HEIGHT" ] || [ "$HEIGHT" = "N/A" ]; then
                    # Try alternative JSON parsing
                    HEIGHT=$(curl -s http://localhost:$RPC_PORT/status 2>/dev/null | grep latest_block_height | grep -oE '[0-9]+' | head -1 || echo "N/A")
                fi
                echo "  Block Height: $HEIGHT"
            fi
            
            echo "  RPC: http://localhost:$RPC_PORT"
            echo "  API: http://localhost:$API_PORT"
        else
            echo -e "${RED}Node$i: STOPPED${NC}"
        fi
        echo ""
    done
}

show_logs() {
    NODE_NUM=${3:-0}
    LOG_FILE="$OUTPUT_DIR/node$NODE_NUM.log"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}Error: Log file not found for node$NODE_NUM${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Showing logs for node$NODE_NUM (Ctrl+C to exit):${NC}"
    tail -f $LOG_FILE
}

case $COMMAND in
    start)
        start_nodes
        ;;
    stop)
        stop_nodes
        ;;
    status)
        status_nodes
        ;;
    logs)
        show_logs $@
        ;;
    restart)
        stop_nodes
        sleep 2
        start_nodes
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [node_number]} [chain_binary]"
        echo ""
        echo "Commands:"
        echo "  start    - Start all testnet nodes"
        echo "  stop     - Stop all testnet nodes"
        echo "  restart  - Restart all testnet nodes"
        echo "  status   - Show status of all nodes"
        echo "  logs N   - Show logs for node N (default: 0)"
        exit 1
        ;;
esac