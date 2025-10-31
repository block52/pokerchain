#!/bin/bash

# Cosmos SDK Multi-Node Testnet Setup Script
# Usage: ./setup-testnet.sh [num_nodes] [chain_binary] [chain_id] [--build]

set -e

# Configuration
NUM_NODES=${1:-4}
CHAIN_BINARY=${2:-"pokerchaind"}
CHAIN_ID=${3:-"pokerchain-testnet-1"}
OUTPUT_DIR="./testnet"
KEYRING_BACKEND="test"
STAKE_AMOUNT="1000000stake"
INITIAL_BALANCE="100000000000stake"
AUTO_BUILD=false

# Check for --build flag
for arg in "$@"; do
    if [ "$arg" == "--build" ]; then
        AUTO_BUILD=true
    fi
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect architecture
detect_architecture() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
    esac
    
    echo "${os}/${arch}"
}

DETECTED_ARCH=$(detect_architecture)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cosmos SDK Multi-Node Testnet Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Number of nodes: ${YELLOW}${NUM_NODES}${NC}"
echo -e "Chain binary: ${YELLOW}${CHAIN_BINARY}${NC}"
echo -e "Chain ID: ${YELLOW}${CHAIN_ID}${NC}"
echo -e "Output directory: ${YELLOW}${OUTPUT_DIR}${NC}"
echo -e "Architecture: ${BLUE}${DETECTED_ARCH}${NC}"
echo ""

# Check if binary exists
check_and_build_binary() {
    if ! command -v $CHAIN_BINARY &> /dev/null; then
        # Check if binary exists in ./build directory
        if [ -f "./build/$CHAIN_BINARY" ]; then
            echo -e "${YELLOW}Found binary in ./build directory${NC}"
            CHAIN_BINARY="./build/$CHAIN_BINARY"
            return 0
        fi
        
        echo -e "${RED}Error: $CHAIN_BINARY not found.${NC}"
        
        # Check if Makefile exists
        if [ -f "Makefile" ]; then
            if [ "$AUTO_BUILD" = true ]; then
                echo -e "${GREEN}Building binary using Makefile...${NC}"
                make build
                if [ -f "./build/$CHAIN_BINARY" ]; then
                    CHAIN_BINARY="./build/$CHAIN_BINARY"
                    echo -e "${GREEN}✓ Binary built successfully${NC}"
                    return 0
                fi
            else
                echo ""
                echo -e "${YELLOW}Would you like to build it now? Options:${NC}"
                echo "  1) make build          - Build for current platform ($DETECTED_ARCH)"
                echo "  2) make install        - Install to \$GOPATH/bin"
                echo "  3) Exit and build manually"
                echo ""
                read -p "Choose option (1-3): " choice
                
                case $choice in
                    1)
                        echo -e "${GREEN}Building binary...${NC}"
                        make build
                        if [ -f "./build/$CHAIN_BINARY" ]; then
                            CHAIN_BINARY="./build/$CHAIN_BINARY"
                            echo -e "${GREEN}✓ Binary built successfully${NC}"
                            return 0
                        fi
                        ;;
                    2)
                        echo -e "${GREEN}Installing binary...${NC}"
                        make install
                        echo -e "${GREEN}✓ Binary installed${NC}"
                        return 0
                        ;;
                    3)
                        echo "Please build your chain first:"
                        echo "  make build    # or"
                        echo "  make install"
                        exit 1
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        exit 1
                        ;;
                esac
            fi
        else
            echo ""
            echo "Please build your chain first:"
            echo "  ignite chain build"
            echo "  # or"
            echo "  make build"
            echo "  # or"
            echo "  make install"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Found $CHAIN_BINARY in PATH${NC}"
    fi
}

check_and_build_binary
echo ""

# Clean up old testnet data
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}Removing existing testnet directory...${NC}"
    rm -rf $OUTPUT_DIR
fi

mkdir -p $OUTPUT_DIR

# Arrays to store node info
declare -a NODE_IDS
declare -a NODE_ADDRS

echo -e "${GREEN}Step 1: Initializing nodes...${NC}"
for i in $(seq 0 $((NUM_NODES - 1))); do
    NODE_HOME="$OUTPUT_DIR/node$i"
    NODE_MONIKER="validator$i"
    
    echo "  Initializing node$i..."
    $CHAIN_BINARY init $NODE_MONIKER --chain-id $CHAIN_ID --home $NODE_HOME &> /dev/null
    
    # Create validator key
    echo "  Creating validator key for node$i..."
    $CHAIN_BINARY keys add $NODE_MONIKER \
        --keyring-backend $KEYRING_BACKEND \
        --home $NODE_HOME \
        --output json &> /dev/null
    
    # Store node ID and address
    NODE_ID=$($CHAIN_BINARY comet show-node-id --home $NODE_HOME)
    NODE_ADDR=$($CHAIN_BINARY keys show $NODE_MONIKER -a --keyring-backend $KEYRING_BACKEND --home $NODE_HOME)
    NODE_IDS[$i]=$NODE_ID
    NODE_ADDRS[$i]=$NODE_ADDR
    
    echo -e "    ${GREEN}✓${NC} Node$i ID: $NODE_ID"
    echo -e "    ${GREEN}✓${NC} Node$i Address: $NODE_ADDR"
done

echo ""
echo -e "${GREEN}Step 2: Adding genesis accounts...${NC}"
# Add all validator accounts to node0's genesis first
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "  Adding validator$i to genesis..."
    $CHAIN_BINARY genesis add-genesis-account ${NODE_ADDRS[$i]} $INITIAL_BALANCE \
        --home $OUTPUT_DIR/node0 \
        --keyring-backend $KEYRING_BACKEND &> /dev/null
    echo -e "    ${GREEN}✓${NC} Added ${NODE_ADDRS[$i]}"
done

echo ""
echo -e "${GREEN}Step 3: Creating genesis transactions...${NC}"
for i in $(seq 0 $((NUM_NODES - 1))); do
    NODE_HOME="$OUTPUT_DIR/node$i"
    NODE_MONIKER="validator$i"
    
    echo "  Creating gentx for node$i..."
    
    # Copy the genesis from node0 to current node (so it has all accounts)
    if [ $i -ne 0 ]; then
        cp $OUTPUT_DIR/node0/config/genesis.json $NODE_HOME/config/genesis.json
    fi
    
    $CHAIN_BINARY genesis gentx $NODE_MONIKER $STAKE_AMOUNT \
        --chain-id $CHAIN_ID \
        --keyring-backend $KEYRING_BACKEND \
        --home $NODE_HOME &> /dev/null
    
    echo -e "    ${GREEN}✓${NC} Created gentx for validator$i"
    
    # Copy gentx to node0
    if [ $i -ne 0 ]; then
        cp $NODE_HOME/config/gentx/* $OUTPUT_DIR/node0/config/gentx/
    fi
done

echo ""
echo -e "${GREEN}Step 4: Collecting genesis transactions...${NC}"
$CHAIN_BINARY genesis collect-gentxs --home $OUTPUT_DIR/node0 &> /dev/null
echo -e "  ${GREEN}✓${NC} Collected all genesis transactions"

echo ""
echo -e "${GREEN}Step 5: Distributing final genesis to all nodes...${NC}"
for i in $(seq 1 $((NUM_NODES - 1))); do
    cp $OUTPUT_DIR/node0/config/genesis.json $OUTPUT_DIR/node$i/config/genesis.json
    echo -e "  ${GREEN}✓${NC} Copied genesis to node$i"
done

echo ""
echo -e "${GREEN}Step 6: Configuring persistent peers...${NC}"
# Build persistent peers string
PEERS=""
for i in $(seq 0 $((NUM_NODES - 1))); do
    PORT=$((26656 + i))
    if [ -n "$PEERS" ]; then
        PEERS="$PEERS,"
    fi
    PEERS="${PEERS}${NODE_IDS[$i]}@localhost:$PORT"
done

for i in $(seq 0 $((NUM_NODES - 1))); do
    CONFIG_FILE="$OUTPUT_DIR/node$i/config/config.toml"
    
    # Update persistent_peers
    sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/g" $CONFIG_FILE
    
    # Set different ports for each node
    RPC_PORT=$((26657 + i))
    P2P_PORT=$((26656 + i))
    PPROF_PORT=$((6060 + i))
    GRPC_PORT=$((9090 + i))
    GRPC_WEB_PORT=$((9091 + i))
    API_PORT=$((1317 + i))
    
    # Update config.toml
    sed -i.bak "s/laddr = \"tcp:\/\/127.0.0.1:26657\"/laddr = \"tcp:\/\/127.0.0.1:$RPC_PORT\"/g" $CONFIG_FILE
    sed -i.bak "s/laddr = \"tcp:\/\/0.0.0.0:26656\"/laddr = \"tcp:\/\/0.0.0.0:$P2P_PORT\"/g" $CONFIG_FILE
    sed -i.bak "s/pprof_laddr = \"localhost:6060\"/pprof_laddr = \"localhost:$PPROF_PORT\"/g" $CONFIG_FILE
    
    # Update app.toml
    APP_CONFIG_FILE="$OUTPUT_DIR/node$i/config/app.toml"
    sed -i.bak "s/address = \"tcp:\/\/localhost:1317\"/address = \"tcp:\/\/localhost:$API_PORT\"/g" $APP_CONFIG_FILE
    sed -i.bak "s/address = \"localhost:9090\"/address = \"localhost:$GRPC_PORT\"/g" $APP_CONFIG_FILE
    sed -i.bak "s/address = \"localhost:9091\"/address = \"localhost:$GRPC_WEB_PORT\"/g" $APP_CONFIG_FILE
    
    # Enable API
    sed -i.bak 's/enable = false/enable = true/g' $APP_CONFIG_FILE
    
    # Set minimum gas prices (set to 0stake for testing, or use 0.001stake for production-like)
    sed -i.bak 's/minimum-gas-prices = ""/minimum-gas-prices = "0stake"/g' $APP_CONFIG_FILE
    
    echo -e "  ${GREEN}✓${NC} Configured node$i (RPC: $RPC_PORT, P2P: $P2P_PORT, API: $API_PORT)"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testnet setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}To start the testnet, run the following commands in separate terminals:${NC}"
echo ""

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo -e "${GREEN}Terminal $((i + 1)):${NC}"
    echo "$CHAIN_BINARY start --home $OUTPUT_DIR/node$i"
    echo ""
done

echo -e "${YELLOW}Or start all nodes in the background:${NC}"
echo ""
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "$CHAIN_BINARY start --home $OUTPUT_DIR/node$i > $OUTPUT_DIR/node$i.log 2>&1 &"
done

echo ""
echo -e "${YELLOW}Node Information:${NC}"
for i in $(seq 0 $((NUM_NODES - 1))); do
    RPC_PORT=$((26657 + i))
    API_PORT=$((1317 + i))
    echo "Node$i - RPC: http://localhost:$RPC_PORT | API: http://localhost:$API_PORT"
done

echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "# Check node status:"
echo "$CHAIN_BINARY status --node tcp://localhost:26657"
echo ""
echo "# Query account balance:"
echo "$CHAIN_BINARY query bank balances ${NODE_ADDRS[0]} --node tcp://localhost:26657"
echo ""
echo "# Stop all nodes:"
echo "pkill -f $CHAIN_BINARY"
echo ""
echo -e "${BLUE}Script options:${NC}"
echo "./setup-testnet.sh [num_nodes] [chain_binary] [chain_id] [--build]"
echo "  --build: Automatically build the binary if not found"
echo ""
echo -e "${GREEN}Happy testing!${NC}"