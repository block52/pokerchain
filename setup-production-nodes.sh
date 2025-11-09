#!/bin/bash

# Production Cluster Setup Script with Mnemonic Support
# Generates production-ready configs locally in ./production/nodeX directories
# Supports generating validator keys from mnemonics for secure backup/recovery
#
# Usage: ./setup-production-cluster.sh [num_nodes] [chain_binary] [chain_id]
#        If parameters are not provided, the script will prompt interactively

set -e

# Configuration
OUTPUT_DIR="./production"
KEYRING_BACKEND="test"  # For initial setup, change to "file" in production
STAKE_AMOUNT="100000000000stake"
INITIAL_BALANCE="1000000000000stake"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Node configuration (you'll set these interactively)
declare -a NODE_HOSTNAMES
declare -a NODE_IPS
declare -a NODE_IDS
declare -a NODE_ADDRS
declare -a NODE_MONIKERS
declare -a NODE_MNEMONICS

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        POKERCHAIN PRODUCTION CLUSTER SETUP                       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get configuration from command-line or interactively
if [ -n "$1" ] && [ "$1" -ge 1 ] 2>/dev/null; then
    NUM_NODES=$1
else
    while true; do
        read -p "How many validator nodes do you want to set up? [default: 4]: " input_nodes
        input_nodes=${input_nodes:-4}
        if [ "$input_nodes" -ge 1 ] 2>/dev/null; then
            NUM_NODES=$input_nodes
            break
        else
            echo -e "${RED}Please enter a valid number (1 or greater)${NC}"
        fi
    done
fi

if [ -n "$2" ]; then
    CHAIN_BINARY=$2
else
    read -p "Chain binary name [default: pokerchaind]: " input_binary
    CHAIN_BINARY=${input_binary:-"pokerchaind"}
fi

if [ -n "$3" ]; then
    CHAIN_ID=$3
else
    read -p "Chain ID [default: pokerchain]: " input_chain_id
    CHAIN_ID=${input_chain_id:-"pokerchain"}
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Configuration:${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "Number of nodes: ${YELLOW}${NUM_NODES}${NC}"
echo -e "Chain binary: ${YELLOW}${CHAIN_BINARY}${NC}"
echo -e "Chain ID: ${YELLOW}${CHAIN_ID}${NC}"
echo -e "Output directory: ${YELLOW}${OUTPUT_DIR}${NC}"
echo ""

# Detect target architecture for production
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        TARGET ARCHITECTURE SELECTION                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Production servers are typically Linux. Select target architecture:"
echo ""
echo "1) Linux AMD64 (x86_64) - Most cloud providers, VPS, Intel/AMD servers"
echo "2) Linux ARM64 (aarch64) - ARM-based servers, AWS Graviton"
echo "3) Auto-detect from current system"
echo ""
read -p "Enter choice [1-3] (default: 1): " ARCH_CHOICE
ARCH_CHOICE=${ARCH_CHOICE:-1}

case $ARCH_CHOICE in
    1)
        TARGET_OS="linux"
        TARGET_ARCH="amd64"
        BUILD_TARGET="linux-amd64"
        ;;
    2)
        TARGET_OS="linux"
        TARGET_ARCH="arm64"
        BUILD_TARGET="linux-arm64"
        ;;
    3)
        TARGET_OS="linux"
        if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
            TARGET_ARCH="arm64"
            BUILD_TARGET="linux-arm64"
        else
            TARGET_ARCH="amd64"
            BUILD_TARGET="linux-amd64"
        fi
        ;;
    *)
        echo -e "${YELLOW}Invalid choice, defaulting to Linux AMD64${NC}"
        TARGET_OS="linux"
        TARGET_ARCH="amd64"
        BUILD_TARGET="linux-amd64"
        ;;
esac

echo -e "${GREEN}✓ Target architecture: ${TARGET_OS}/${TARGET_ARCH}${NC}"
echo ""

# Build for specific target architecture
build_for_target() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Building pokerchaind for ${TARGET_OS}/${TARGET_ARCH}...${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local output_binary="./build/pokerchaind-${BUILD_TARGET}"
    mkdir -p ./build
    
    if [ -f "Makefile" ]; then
        # Check if Makefile has the specific target
        if grep -q "build-${BUILD_TARGET}:" Makefile; then
            echo "Using Makefile target: build-${BUILD_TARGET}"
            if make build-${BUILD_TARGET}; then
                CHAIN_BINARY="$output_binary"
                echo -e "${GREEN}✓ Build successful: $CHAIN_BINARY${NC}"
            else
                echo -e "${RED}❌ Build failed${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Makefile doesn't have build-${BUILD_TARGET} target, using go build directly...${NC}"
            echo "Running: GOOS=${TARGET_OS} GOARCH=${TARGET_ARCH} go build -o $output_binary ./cmd/pokerchaind"
            if GOOS=${TARGET_OS} GOARCH=${TARGET_ARCH} go build -o "$output_binary" ./cmd/pokerchaind; then
                CHAIN_BINARY="$output_binary"
                echo -e "${GREEN}✓ Build successful: $CHAIN_BINARY${NC}"
            else
                echo -e "${RED}❌ Build failed${NC}"
                exit 1
            fi
        fi
    else
        echo "Running: GOOS=${TARGET_OS} GOARCH=${TARGET_ARCH} go build -o $output_binary ./cmd/pokerchaind"
        if GOOS=${TARGET_OS} GOARCH=${TARGET_ARCH} go build -o "$output_binary" ./cmd/pokerchaind; then
            CHAIN_BINARY="$output_binary"
            echo -e "${GREEN}✓ Build successful: $CHAIN_BINARY${NC}"
        else
            echo -e "${RED}❌ Build failed${NC}"
            exit 1
        fi
    fi
    
    # Show binary info
    echo ""
    if command -v file &> /dev/null; then
        echo "Binary verification:"
        file "$CHAIN_BINARY"
    fi
    if command -v ls &> /dev/null; then
        local size=$(ls -lh "$CHAIN_BINARY" | awk '{print $5}')
        echo "Binary size: $size"
    fi
    echo ""
}

# Check if binary exists
check_binary() {
    # First check for architecture-specific build
    local arch_binary="./build/pokerchaind-${BUILD_TARGET}"
    local generic_binary="./build/pokerchaind"
    
    if [ -f "$arch_binary" ]; then
        CHAIN_BINARY="$arch_binary"
        echo -e "${GREEN}✓ Found architecture-specific binary: $CHAIN_BINARY${NC}"
        
        # Verify it's the right architecture
        if command -v file &> /dev/null; then
            local file_output=$(file "$CHAIN_BINARY")
            echo "  Binary info: $file_output"
            if ! echo "$file_output" | grep -q "Linux"; then
                echo -e "${YELLOW}⚠ Warning: Binary may not be for Linux${NC}"
            fi
        fi
        return 0
    elif [ -f "$generic_binary" ]; then
        echo -e "${YELLOW}⚠ Found generic binary: $generic_binary${NC}"
        
        # Check if it's the right architecture
        if command -v file &> /dev/null; then
            local file_output=$(file "$generic_binary")
            echo "  Binary info: $file_output"
            
            if echo "$file_output" | grep -q "Linux"; then
                if [ "$TARGET_ARCH" = "amd64" ] && echo "$file_output" | grep -q "x86-64"; then
                    CHAIN_BINARY="$generic_binary"
                    echo -e "${GREEN}✓ Binary is compatible with target${NC}"
                    return 0
                elif [ "$TARGET_ARCH" = "arm64" ] && echo "$file_output" | grep -q "ARM aarch64"; then
                    CHAIN_BINARY="$generic_binary"
                    echo -e "${GREEN}✓ Binary is compatible with target${NC}"
                    return 0
                else
                    echo -e "${YELLOW}⚠ Binary architecture doesn't match target: ${TARGET_OS}/${TARGET_ARCH}${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Binary is not for Linux${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Cannot verify binary architecture (install 'file' command)${NC}"
        fi
        
        echo ""
        read -p "Build for correct architecture ${TARGET_OS}/${TARGET_ARCH}? (y/n): " BUILD_NOW
        if [[ $BUILD_NOW =~ ^[Yy]$ ]]; then
            build_for_target
            return 0
        else
            CHAIN_BINARY="$generic_binary"
            echo -e "${YELLOW}⚠ Using existing binary - it may not work on production servers!${NC}"
            return 0
        fi
    fi
    
    if command -v pokerchaind &> /dev/null; then
        echo -e "${YELLOW}⚠ Found pokerchaind in PATH${NC}"
        local which_binary=$(which pokerchaind)
        
        if command -v file &> /dev/null; then
            local file_output=$(file "$which_binary")
            echo "  Binary info: $file_output"
            
            if ! echo "$file_output" | grep -q "Linux"; then
                echo -e "${YELLOW}⚠ Binary in PATH is not for Linux${NC}"
                echo ""
                read -p "Build for ${TARGET_OS}/${TARGET_ARCH}? (y/n): " BUILD_NOW
                if [[ $BUILD_NOW =~ ^[Yy]$ ]]; then
                    build_for_target
                    return 0
                fi
            fi
        fi
    fi
    
    # No suitable binary found
    echo -e "${RED}❌ No suitable binary found for ${TARGET_OS}/${TARGET_ARCH}${NC}"
    echo ""
    read -p "Build now? (y/n): " BUILD_NOW
    if [[ $BUILD_NOW =~ ^[Yy]$ ]]; then
        build_for_target
        return 0
    else
        echo ""
        echo "Please build the binary for production deployment:"
        echo "  make build-${BUILD_TARGET}"
        echo "  # or"
        echo "  GOOS=${TARGET_OS} GOARCH=${TARGET_ARCH} go build -o ./build/pokerchaind-${BUILD_TARGET} ./cmd/pokerchaind"
        exit 1
    fi
}

check_binary
echo ""

# Check/build the validator key generator tool
check_genvalidatorkey_tool() {
    local tool_path="./genvalidatorkey"
    
    if [ -f "$tool_path" ]; then
        echo -e "${GREEN}✓ Found genvalidatorkey tool${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}genvalidatorkey tool not found, checking for source...${NC}"
    
    if [ -f "./genvalidatorkey.go" ]; then
        echo "Building genvalidatorkey tool..."
        if go build -o genvalidatorkey ./genvalidatorkey.go; then
            echo -e "${GREEN}✓ Built genvalidatorkey tool${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to build genvalidatorkey tool${NC}"
            return 1
        fi
    elif [ -f "./cmd/genvalidatorkey/main.go" ]; then
        echo "Building genvalidatorkey tool..."
        if go build -o genvalidatorkey ./cmd/genvalidatorkey/main.go; then
            echo -e "${GREEN}✓ Built genvalidatorkey tool${NC}"
            return 0
        else
            echo -e "${RED}❌ Failed to build genvalidatorkey tool${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ genvalidatorkey tool not available${NC}"
        echo "  Random validator keys will be generated by init command."
        echo "  To use mnemonic-based keys, add genvalidatorkey.go to your project."
        return 1
    fi
}

# Ask about mnemonic usage
USE_MNEMONICS=false
if check_genvalidatorkey_tool; then
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        VALIDATOR KEY GENERATION METHOD                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Choose validator key generation method:"
    echo ""
    echo "1) Generate from mnemonics (RECOMMENDED - allows key recovery)"
    echo "2) Random generation (default init behavior)"
    echo ""
    read -p "Enter choice [1-2] (default: 1): " KEY_GEN_CHOICE
    KEY_GEN_CHOICE=${KEY_GEN_CHOICE:-1}
    
    if [ "$KEY_GEN_CHOICE" = "1" ]; then
        USE_MNEMONICS=true
        echo -e "${GREEN}✓ Will generate validator keys from mnemonics${NC}"
        echo ""
        echo "For each validator, you can either:"
        echo "  - Press Enter to generate a new mnemonic"
        echo "  - Paste an existing mnemonic to recover a key"
        echo ""
    else
        echo -e "${YELLOW}Using random key generation${NC}"
    fi
fi
echo ""

# Function to generate or recover validator key from mnemonic
generate_validator_key_from_mnemonic() {
    local node_home=$1
    local node_moniker=$2
    local mnemonic=$3
    local key_file="$node_home/config/priv_validator_key.json"
    
    mkdir -p "$node_home/config"
    
    if [ -z "$mnemonic" ]; then
        # Generate new mnemonic
        echo "  Generating new mnemonic for $node_moniker..."
        ./genvalidatorkey generate "$key_file" > /tmp/genkey_output_$$.txt 2>&1
        
        # Extract mnemonic from output
        mnemonic=$(grep -A 1 "Generated mnemonic" /tmp/genkey_output_$$.txt | tail -n 1)
        
        echo -e "  ${GREEN}✓${NC} Generated validator key with new mnemonic"
        echo ""
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}⚠️  SAVE THIS MNEMONIC SECURELY - Required for key recovery!${NC}"
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "  $mnemonic"
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        rm -f /tmp/genkey_output_$$.txt
    else
        # Use provided mnemonic
        echo "  Recovering validator key from mnemonic..."
        if ./genvalidatorkey "$mnemonic" "$key_file" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Recovered validator key from mnemonic"
        else
            echo -e "  ${RED}❌ Failed to generate key from mnemonic${NC}"
            return 1
        fi
    fi
    
    echo "$mnemonic"
    return 0
}

# Function to resolve hostname to IP
resolve_hostname() {
    local hostname=$1
    local ip=""
    
    # Try getent first (most reliable)
    if command -v getent &> /dev/null; then
        ip=$(getent hosts "$hostname" | awk '{ print $1 }' | head -n1)
    # Try dig
    elif command -v dig &> /dev/null; then
        ip=$(dig +short "$hostname" | grep -E '^[0-9.]+$' | head -n1)
    # Try nslookup
    elif command -v nslookup &> /dev/null; then
        ip=$(nslookup "$hostname" | awk '/^Address: / { print $2 }' | grep -v '#' | head -n1)
    # Try host
    elif command -v host &> /dev/null; then
        ip=$(host "$hostname" | awk '/has address/ { print $4 }' | head -n1)
    fi
    
    echo "$ip"
}

# Get node information from user
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Configure Node Information${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Enter details for each validator node:"
echo "IP addresses will be automatically resolved from hostnames."
echo ""

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo -e "${GREEN}━━━ Node $i ━━━${NC}"
    
    while true; do
        read -p "Hostname (e.g., node$i.yourproject.com): " hostname
        
        if [ -z "$hostname" ]; then
            echo -e "${RED}  ✗ Hostname cannot be empty${NC}"
            continue
        fi
        
        NODE_HOSTNAMES[$i]=$hostname
        
        # Try to resolve hostname
        echo -n "  Resolving IP address... "
        ip=$(resolve_hostname "$hostname")
        
        if [ -n "$ip" ]; then
            echo -e "${GREEN}✓${NC}"
            echo "  Resolved: $hostname → $ip"
            NODE_IPS[$i]=$ip
            break
        else
            echo -e "${YELLOW}failed${NC}"
            echo -e "${YELLOW}  Could not resolve hostname automatically.${NC}"
            read -p "  Enter IP address manually (or 'r' to retry hostname): " manual_input
            
            if [[ "$manual_input" =~ ^[Rr]$ ]]; then
                continue
            elif [ -n "$manual_input" ]; then
                NODE_IPS[$i]=$manual_input
                echo -e "  ${GREEN}✓${NC} Using IP: $manual_input"
                break
            else
                echo -e "${RED}  ✗ IP address cannot be empty${NC}"
                continue
            fi
        fi
    done
    
    read -p "Moniker (e.g., validator$i): " moniker
    NODE_MONIKERS[$i]=${moniker:-"validator$i"}
    
    # Get mnemonic if using mnemonic-based keys
    if [ "$USE_MNEMONICS" = true ]; then
        echo ""
        read -p "Mnemonic (press Enter to generate new): " input_mnemonic
        NODE_MNEMONICS[$i]="$input_mnemonic"
    fi
    
    echo ""
done

# Confirm configuration
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Configuration Summary:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "Node $i:"
    echo "  Moniker:  ${NODE_MONIKERS[$i]}"
    echo "  Hostname: ${NODE_HOSTNAMES[$i]}"
    echo "  IP:       ${NODE_IPS[$i]}"
    if [ "$USE_MNEMONICS" = true ]; then
        if [ -z "${NODE_MNEMONICS[$i]}" ]; then
            echo "  Key:      New mnemonic will be generated"
        else
            echo "  Key:      Using provided mnemonic"
        fi
    fi
    echo ""
done

read -p "Proceed with this configuration? (y/n): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Clean up old production data
if [ -d "$OUTPUT_DIR" ]; then
    echo ""
    echo -e "${YELLOW}Removing existing production directory...${NC}"
    rm -rf $OUTPUT_DIR
fi

mkdir -p $OUTPUT_DIR

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Initializing Nodes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Create mnemonics file to store all mnemonics securely
MNEMONICS_FILE="$OUTPUT_DIR/MNEMONICS_BACKUP.txt"
if [ "$USE_MNEMONICS" = true ]; then
    cat > $MNEMONICS_FILE << EOF
# VALIDATOR KEY MNEMONICS - KEEP THIS FILE EXTREMELY SECURE!
# Generated: $(date)
# Chain ID: $CHAIN_ID
#
# These mnemonics can be used to recover validator keys.
# Store this file in a secure location (encrypted storage, password manager, etc.)
# DO NOT commit this file to version control!

EOF
    chmod 600 $MNEMONICS_FILE
fi

for i in $(seq 0 $((NUM_NODES - 1))); do
    NODE_HOME="$OUTPUT_DIR/node$i"
    NODE_MONIKER="${NODE_MONIKERS[$i]}"
    
    echo "Initializing ${NODE_MONIKER}..."
    
    # Generate validator key from mnemonic if enabled
    if [ "$USE_MNEMONICS" = true ]; then
        mnemonic=$(generate_validator_key_from_mnemonic "$NODE_HOME" "$NODE_MONIKER" "${NODE_MNEMONICS[$i]}")
        
        # Save mnemonic to backup file
        cat >> $MNEMONICS_FILE << EOF
# Node $i: ${NODE_MONIKER}
# Hostname: ${NODE_HOSTNAMES[$i]}
# IP: ${NODE_IPS[$i]}
$mnemonic

EOF
    fi
    
    # Initialize the node (will use existing priv_validator_key.json if present)
    $CHAIN_BINARY init $NODE_MONIKER --chain-id $CHAIN_ID --home $NODE_HOME
    
    # If we generated the key from mnemonic, the init might have overwritten it
    # So regenerate it after init if needed
    if [ "$USE_MNEMONICS" = true ] && [ -n "$mnemonic" ]; then
        ./genvalidatorkey "$mnemonic" "$NODE_HOME/config/priv_validator_key.json" > /dev/null 2>&1
    fi
    
    # Create validator key
    echo "  Creating validator account key..."
    $CHAIN_BINARY keys add $NODE_MONIKER \
        --keyring-backend $KEYRING_BACKEND \
        --home $NODE_HOME \
        --output json 2>&1 | grep -v "WARNING" || true
    
    # Store node ID and address
    NODE_ID=$($CHAIN_BINARY comet show-node-id --home $NODE_HOME)
    NODE_ADDR=$($CHAIN_BINARY keys show $NODE_MONIKER -a --keyring-backend $KEYRING_BACKEND --home $NODE_HOME)
    NODE_IDS[$i]=$NODE_ID
    NODE_ADDRS[$i]=$NODE_ADDR
    
    echo -e "  ${GREEN}✓${NC} Node ID: $NODE_ID"
    echo -e "  ${GREEN}✓${NC} Address: $NODE_ADDR"
    echo ""
done

if [ "$USE_MNEMONICS" = true ]; then
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  CRITICAL: Mnemonics saved to: $MNEMONICS_FILE${NC}"
    echo -e "${RED}⚠️  This file contains sensitive information!${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo "  1. Copy this file to secure storage immediately"
    echo "  2. Consider encrypting it with: gpg -c $MNEMONICS_FILE"
    echo "  3. Store encrypted copy in multiple secure locations"
    echo "  4. Delete plaintext after securing: shred -u $MNEMONICS_FILE"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Adding Genesis Accounts${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Add all validator accounts to node0's genesis first
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "Adding ${NODE_MONIKERS[$i]} to genesis..."
    $CHAIN_BINARY genesis add-genesis-account ${NODE_ADDRS[$i]} $INITIAL_BALANCE \
        --home $OUTPUT_DIR/node0 \
        --keyring-backend $KEYRING_BACKEND
    echo -e "  ${GREEN}✓${NC} Added ${NODE_ADDRS[$i]}"
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Creating Genesis Transactions${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 0 $((NUM_NODES - 1))); do
    NODE_HOME="$OUTPUT_DIR/node$i"
    NODE_MONIKER="${NODE_MONIKERS[$i]}"
    NODE_IP="${NODE_IPS[$i]}"
    
    echo "Creating gentx for ${NODE_MONIKER}..."
    
    # Copy the genesis from node0 to current node
    if [ $i -ne 0 ]; then
        cp $OUTPUT_DIR/node0/config/genesis.json $NODE_HOME/config/genesis.json
    fi
    
    # Create gentx with node IP in memo
    $CHAIN_BINARY genesis gentx $NODE_MONIKER $STAKE_AMOUNT \
        --chain-id $CHAIN_ID \
        --keyring-backend $KEYRING_BACKEND \
        --home $NODE_HOME \
        --node-id ${NODE_IDS[$i]} \
        --ip $NODE_IP
    
    echo -e "  ${GREEN}✓${NC} Created gentx for ${NODE_MONIKER}"
    
    # Copy gentx to node0
    if [ $i -ne 0 ]; then
        cp $NODE_HOME/config/gentx/* $OUTPUT_DIR/node0/config/gentx/
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 5: Collecting Genesis Transactions${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

$CHAIN_BINARY genesis collect-gentxs --home $OUTPUT_DIR/node0
echo -e "${GREEN}✓${NC} Collected all genesis transactions"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 6: Distributing Final Genesis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 $((NUM_NODES - 1))); do
    cp $OUTPUT_DIR/node0/config/genesis.json $OUTPUT_DIR/node$i/config/genesis.json
    echo -e "${GREEN}✓${NC} Copied genesis to node$i"
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 7: Configuring Network Settings${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if template-app.toml exists
TEMPLATE_APP_TOML="./template-app.toml"
if [ ! -f "$TEMPLATE_APP_TOML" ]; then
    echo -e "${YELLOW}Warning: template-app.toml not found${NC}"
    echo "Will use generated app.toml and modify it."
    USE_TEMPLATE=false
else
    echo -e "${GREEN}✓ Found template-app.toml${NC}"
    USE_TEMPLATE=true
fi

for i in $(seq 0 $((NUM_NODES - 1))); do
    CONFIG_FILE="$OUTPUT_DIR/node$i/config/config.toml"
    APP_CONFIG_FILE="$OUTPUT_DIR/node$i/config/app.toml"
    
    # Build peer list for this node (excluding itself)
    PEERS=""
    for j in $(seq 0 $((NUM_NODES - 1))); do
        if [ $i -ne $j ]; then
            if [ -n "$PEERS" ]; then
                PEERS="$PEERS,"
            fi
            PEERS="${PEERS}${NODE_IDS[$j]}@${NODE_IPS[$j]}:26656"
        fi
    done
    
    # Update persistent_peers
    sed -i.bak "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/g" $CONFIG_FILE
    
    # Production settings
    # Listen on all interfaces for P2P and RPC
    sed -i.bak 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' $CONFIG_FILE
    sed -i.bak 's/laddr = "tcp:\/\/0.0.0.0:26656"/laddr = "tcp:\/\/0.0.0.0:26656"/g' $CONFIG_FILE
    
    # Set external address
    sed -i.bak "s/external_address = \"\"/external_address = \"${NODE_IPS[$i]}:26656\"/g" $CONFIG_FILE
    
    # Production P2P settings
    sed -i.bak 's/pex = true/pex = true/g' $CONFIG_FILE
    sed -i.bak 's/addr_book_strict = true/addr_book_strict = false/g' $CONFIG_FILE
    sed -i.bak 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/g' $CONFIG_FILE
    sed -i.bak 's/max_num_outbound_peers = 10/max_num_outbound_peers = 50/g' $CONFIG_FILE
    
    # Handle app.toml
    if [ "$USE_TEMPLATE" = true ]; then
        cp $TEMPLATE_APP_TOML $APP_CONFIG_FILE
        # Bind API to all interfaces for production
        sed -i.bak 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/g' $APP_CONFIG_FILE
        sed -i.bak 's/address = "localhost:9090"/address = "0.0.0.0:9090"/g' $APP_CONFIG_FILE
    else
        # Fallback: modify generated app.toml
        sed -i.bak 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/g' $APP_CONFIG_FILE
        sed -i.bak 's/address = "localhost:9090"/address = "0.0.0.0:9090"/g' $APP_CONFIG_FILE
        
        # Enable API
        sed -i.bak 's/enable = false/enable = true/g' $APP_CONFIG_FILE
        
        # Set minimum gas prices (use actual prices in production)
        if grep -q 'minimum-gas-prices = ""' $APP_CONFIG_FILE; then
            sed -i.bak 's/minimum-gas-prices = ""/minimum-gas-prices = "0.001stake"/g' $APP_CONFIG_FILE
        elif grep -q "minimum-gas-prices = ''" $APP_CONFIG_FILE; then
            sed -i.bak "s/minimum-gas-prices = ''/minimum-gas-prices = \"0.001stake\"/g" $APP_CONFIG_FILE
        elif grep -q 'minimum-gas-prices =' $APP_CONFIG_FILE; then
            sed -i.bak 's/minimum-gas-prices = .*/minimum-gas-prices = "0.001stake"/g' $APP_CONFIG_FILE
        else
            echo 'minimum-gas-prices = "0.001stake"' >> $APP_CONFIG_FILE
        fi
    fi
    
    # Clean up backup files
    rm -f $CONFIG_FILE.bak $APP_CONFIG_FILE.bak
    
    echo -e "${GREEN}✓${NC} Configured ${NODE_MONIKERS[$i]}"
    echo "  Peers: $PEERS"
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 8: Creating Deployment Package${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Create deployment scripts for each node
for i in $(seq 0 $((NUM_NODES - 1))); do
    DEPLOY_SCRIPT="$OUTPUT_DIR/deploy-node$i.sh"
    
    cat > $DEPLOY_SCRIPT << EOF
#!/bin/bash
# Deployment script for ${NODE_MONIKERS[$i]}
# Target: ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]})

set -e

REMOTE_HOST="${NODE_HOSTNAMES[$i]}"
REMOTE_USER="\${1:-root}"
NODE_NAME="node$i"

echo "═══════════════════════════════════════════════════════════════════"
echo "Deploying ${NODE_MONIKERS[$i]} to \$REMOTE_USER@\$REMOTE_HOST"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Stop any running pokerchaind
echo "Stopping pokerchaind service..."
ssh "\$REMOTE_USER@\$REMOTE_HOST" "
    sudo systemctl stop pokerchaind 2>/dev/null || true
    pkill -9 pokerchaind 2>/dev/null || true
    sleep 2
"

# Backup existing data
echo "Backing up existing data..."
ssh "\$REMOTE_USER@\$REMOTE_HOST" "
    if [ -d /root/.pokerchain ]; then
        BACKUP_DIR=\"/root/pokerchain-backup-\\\$(date +%Y%m%d-%H%M%S)\"
        mkdir -p \\\$BACKUP_DIR
        cp -r /root/.pokerchain/* \\\$BACKUP_DIR/ 2>/dev/null || true
        echo \"Backup created: \\\$BACKUP_DIR\"
    fi
    rm -rf /root/.pokerchain
"

# Create directories
echo "Creating directories..."
ssh "\$REMOTE_USER@\$REMOTE_HOST" "
    mkdir -p /root/.pokerchain/config
    mkdir -p /root/.pokerchain/data
"

# Copy configuration files
echo "Uploading configuration..."
scp -r ./\$NODE_NAME/config/* "\$REMOTE_USER@\$REMOTE_HOST:/root/.pokerchain/config/"
scp -r ./\$NODE_NAME/data/* "\$REMOTE_USER@\$REMOTE_HOST:/root/.pokerchain/data/"

# Set permissions
echo "Setting permissions..."
ssh "\$REMOTE_USER@\$REMOTE_HOST" "
    chmod 700 /root/.pokerchain
    chmod 700 /root/.pokerchain/config
    chmod 700 /root/.pokerchain/data
    chmod 600 /root/.pokerchain/config/priv_validator_key.json
    chmod 600 /root/.pokerchain/data/priv_validator_state.json
"

# Copy binary (if available)
if [ -f "../build/pokerchaind" ]; then
    echo "Uploading pokerchaind binary..."
    scp ../build/pokerchaind "\$REMOTE_USER@\$REMOTE_HOST:/tmp/"
    ssh "\$REMOTE_USER@\$REMOTE_HOST" "
        sudo mv /tmp/pokerchaind /usr/local/bin/
        sudo chmod +x /usr/local/bin/pokerchaind
        sudo chown root:root /usr/local/bin/pokerchaind
    "
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Deployment complete for ${NODE_MONIKERS[$i]}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Copy pokerchaind.service to the remote server"
echo "2. Enable and start the service:"
echo "   ssh \$REMOTE_USER@\$REMOTE_HOST 'sudo systemctl enable pokerchaind && sudo systemctl start pokerchaind'"
echo ""
EOF

    chmod +x $DEPLOY_SCRIPT
    echo -e "${GREEN}✓${NC} Created deployment script: $DEPLOY_SCRIPT"
done

# Create master deployment script
MASTER_DEPLOY="$OUTPUT_DIR/deploy-all.sh"
cat > $MASTER_DEPLOY << 'EOF'
#!/bin/bash
# Master deployment script - deploys all nodes

set -e

REMOTE_USER="${1:-root}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        DEPLOYING ALL PRODUCTION NODES                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    cat >> $MASTER_DEPLOY << EOF
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Deploying node$i: ${NODE_MONIKERS[$i]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./deploy-node$i.sh "\$REMOTE_USER"
echo ""

EOF
done

cat >> $MASTER_DEPLOY << 'EOF'
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        ALL NODES DEPLOYED SUCCESSFULLY                           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Start all nodes with:"
EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "echo \"ssh \$REMOTE_USER@${NODE_HOSTNAMES[$i]} 'sudo systemctl start pokerchaind'\"" >> $MASTER_DEPLOY
done

cat >> $MASTER_DEPLOY << 'EOF'
echo ""
EOF

chmod +x $MASTER_DEPLOY
echo -e "${GREEN}✓${NC} Created master deployment script: $MASTER_DEPLOY"

# Save node info
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 9: Saving Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

NODE_INFO_FILE="$OUTPUT_DIR/NODE_INFO.md"
cat > $NODE_INFO_FILE << EOF
# Production Cluster Configuration

## Chain Information
- **Chain ID:** $CHAIN_ID
- **Number of Validators:** $NUM_NODES
- **Generated:** $(date)
- **Validator Key Method:** $([ "$USE_MNEMONICS" = true ] && echo "Mnemonic-based (recoverable)" || echo "Random")

EOF

if [ "$USE_MNEMONICS" = true ]; then
    cat >> $NODE_INFO_FILE << EOF
## ⚠️ SECURITY CRITICAL

**Mnemonics Backup File:** \`MNEMONICS_BACKUP.txt\`

This file contains the seed phrases for all validator keys. You MUST:
1. Copy it to secure, encrypted storage immediately
2. Store encrypted copies in multiple secure locations
3. Never commit it to version control
4. Delete the plaintext version after securing

To encrypt: \`gpg -c MNEMONICS_BACKUP.txt\`
To delete securely: \`shred -u MNEMONICS_BACKUP.txt\`

EOF
fi

cat >> $NODE_INFO_FILE << EOF
## Validator Nodes

EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    cat >> $NODE_INFO_FILE << EOF
### Node $i: ${NODE_MONIKERS[$i]}
- **Hostname:** ${NODE_HOSTNAMES[$i]}
- **IP Address:** ${NODE_IPS[$i]}
- **Node ID:** ${NODE_IDS[$i]}
- **Validator Address:** ${NODE_ADDRS[$i]}
- **Config Directory:** ./node$i/
- **Deployment Script:** ./deploy-node$i.sh

**Endpoints:**
- P2P: ${NODE_IPS[$i]}:26656
- RPC: http://${NODE_IPS[$i]}:26657
- API: http://${NODE_IPS[$i]}:1317

**Persistent Peers Entry:**
\`\`\`
${NODE_IDS[$i]}@${NODE_IPS[$i]}:26656
\`\`\`

EOF
done

cat >> $NODE_INFO_FILE << EOF

## Deployment Instructions

### 1. Build the Binary
\`\`\`bash
make build
\`\`\`

### 2. Deploy Individual Node
\`\`\`bash
cd production
./deploy-node0.sh root  # Replace 'root' with your SSH user
\`\`\`

### 3. Deploy All Nodes at Once
\`\`\`bash
cd production
./deploy-all.sh root    # Replace 'root' with your SSH user
\`\`\`

### 4. Copy systemd Service to Each Node
\`\`\`bash
scp pokerchaind.service root@${NODE_HOSTNAMES[0]}:/tmp/
ssh root@${NODE_HOSTNAMES[0]} 'sudo mv /tmp/pokerchaind.service /etc/systemd/system/ && sudo systemctl daemon-reload'
\`\`\`

### 5. Start Services on All Nodes
\`\`\`bash
EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "ssh root@${NODE_HOSTNAMES[$i]} 'sudo systemctl enable pokerchaind && sudo systemctl start pokerchaind'" >> $NODE_INFO_FILE
done

cat >> $NODE_INFO_FILE << EOF
\`\`\`

### 6. Verify Network
\`\`\`bash
# Check node status
curl http://${NODE_IPS[0]}:26657/status

# Check peers
curl http://${NODE_IPS[0]}:26657/net_info

# Check validators
pokerchaind query staking validators --node tcp://${NODE_IPS[0]}:26657
\`\`\`

## Key Recovery

EOF

if [ "$USE_MNEMONICS" = true ]; then
    cat >> $NODE_INFO_FILE << EOF
### Recovering Validator Keys from Mnemonics

If you need to recover a validator key:

\`\`\`bash
# Using the genvalidatorkey tool
./genvalidatorkey "your 24 word mnemonic phrase here" recovered_priv_validator_key.json

# Copy to node config
scp recovered_priv_validator_key.json root@node0.example.com:/root/.pokerchain/config/priv_validator_key.json
\`\`\`

EOF
else
    cat >> $NODE_INFO_FILE << EOF
### Key Backup

Validator keys were generated randomly. Ensure you have backups of:
- \`priv_validator_key.json\` from each node
- These files cannot be recovered without a backup!

EOF
fi

cat >> $NODE_INFO_FILE << EOF

## Security Considerations

⚠️ **IMPORTANT:** Before deploying to production:

1. **Secure validator keys** - backup priv_validator_key.json files
2. **Secure mnemonics** - if used, encrypt and store in multiple locations
3. **Change keyring backend** from "test" to "file" or "os"
4. **Configure firewall** - only allow necessary ports
5. **Enable monitoring** - set up Prometheus/Grafana
6. **Backup regularly** - especially validator keys and chain data
7. **Use TLS/SSL** - for API/RPC endpoints
8. **Review gas prices** - set appropriate minimum-gas-prices

## Monitoring

Monitor each node with:
\`\`\`bash
# Via SSH
ssh root@${NODE_HOSTNAMES[0]} 'journalctl -u pokerchaind -f'

# Via RPC
curl http://${NODE_IPS[0]}:26657/status | jq '.result.sync_info'
\`\`\`

## Emergency Procedures

### Stop All Nodes
\`\`\`bash
EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "ssh root@${NODE_HOSTNAMES[$i]} 'sudo systemctl stop pokerchaind'" >> $NODE_INFO_FILE
done

cat >> $NODE_INFO_FILE << EOF
\`\`\`

### Restart All Nodes
\`\`\`bash
EOF

for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "ssh root@${NODE_HOSTNAMES[$i]} 'sudo systemctl restart pokerchaind'" >> $NODE_INFO_FILE
done

cat >> $NODE_INFO_FILE << EOF
\`\`\`

## Support

For issues or questions, refer to the project documentation.
EOF

echo -e "${GREEN}✓${NC} Saved node information: $NODE_INFO_FILE"

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        PRODUCTION CLUSTER SETUP COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📁 Production files generated in: ${OUTPUT_DIR}/${NC}"
echo ""
echo -e "${YELLOW}📋 Configuration Summary:${NC}"
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "  Node $i: ${NODE_MONIKERS[$i]} @ ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]})"
done
echo ""

if [ "$USE_MNEMONICS" = true ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  CRITICAL: SECURE YOUR MNEMONICS IMMEDIATELY!  ⚠️           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Mnemonics file: $MNEMONICS_FILE${NC}"
    echo ""
    echo "Recommended actions RIGHT NOW:"
    echo "1. Encrypt: gpg -c $MNEMONICS_FILE"
    echo "2. Copy encrypted file to secure storage (password manager, encrypted USB, etc.)"
    echo "3. Verify you can decrypt: gpg -d $MNEMONICS_FILE.gpg"
    echo "4. Securely delete plaintext: shred -u $MNEMONICS_FILE"
    echo ""
fi

echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo "1. Review the configuration:"
echo "   cat $OUTPUT_DIR/NODE_INFO.md"
echo ""
echo "2. Build the binary (if not already done):"
echo "   make build"
echo ""
echo "3. Deploy to all nodes:"
echo "   cd $OUTPUT_DIR"
echo "   ./deploy-all.sh root"
echo ""
echo "4. Copy systemd service to each node and start:"
echo "   (see NODE_INFO.md for detailed instructions)"
echo ""
echo -e "${YELLOW}⚠️  SECURITY REMINDERS:${NC}"
if [ "$USE_MNEMONICS" = true ]; then
    echo "  • SECURE THE MNEMONICS FILE - it can recover all validator keys!"
fi
echo "  • Backup all validator keys (priv_validator_key.json)"
echo "  • Change keyring backend from 'test' to 'file' in production"
echo "  • Configure firewall rules on each node"
echo "  • Set up monitoring and alerting"
echo "  • Review and adjust gas prices in app.toml"
echo ""
echo -e "${GREEN}🎉 Your production cluster is ready to deploy!${NC}"
echo ""

# Interactive SSH deployment prompts
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        SSH DEPLOYMENT                                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Would you like to deploy the nodes to remote servers now via SSH?"
echo ""
read -p "Deploy nodes via SSH? (y/n): " DEPLOY_NOW

if [[ ! $DEPLOY_NOW =~ ^[Yy]$ ]]; then
    echo ""
    echo "Skipping deployment. You can deploy later using:"
    echo "  cd $OUTPUT_DIR"
    echo "  ./deploy-node0.sh  # Deploy individual node"
    echo "  ./deploy-all.sh    # Deploy all nodes"
    echo ""
    exit 0
fi

echo ""
echo "Deployment Options:"
echo "1) Deploy all nodes at once"
echo "2) Deploy specific nodes"
echo "3) Skip deployment"
echo ""
read -p "Enter choice [1-3] (default: 1): " DEPLOY_CHOICE
DEPLOY_CHOICE=${DEPLOY_CHOICE:-1}

case $DEPLOY_CHOICE in
    1)
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}Deploying All Nodes${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -p "SSH username for remote servers [default: root]: " SSH_USER
        SSH_USER=${SSH_USER:-root}

        echo ""
        echo "SSH user: $SSH_USER"
        echo ""
        read -p "Continue with deployment? (y/n): " CONFIRM_DEPLOY

        if [[ ! $CONFIRM_DEPLOY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled."
            exit 0
        fi

        # Check if deploy-production-node.sh exists
        if [ ! -f "./deploy-production-node.sh" ]; then
            echo -e "${RED}❌ deploy-production-node.sh not found in current directory${NC}"
            echo "Please ensure you are in the repository root directory."
            exit 1
        fi

        chmod +x ./deploy-production-node.sh

        # Deploy each node
        for i in $(seq 0 $((NUM_NODES - 1))); do
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Deploying Node $i: ${NODE_MONIKERS[$i]}${NC}"
            echo -e "${GREEN}Target: ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]})${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            if ./deploy-production-node.sh "$i" "${NODE_HOSTNAMES[$i]}" "$SSH_USER"; then
                echo -e "${GREEN}✅ Node $i deployed successfully${NC}"
            else
                echo -e "${RED}❌ Failed to deploy Node $i${NC}"
                echo ""
                read -p "Continue with remaining nodes? (y/n): " CONTINUE
                if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                    echo "Deployment stopped."
                    exit 1
                fi
            fi
        done

        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║        ALL NODES DEPLOYED!                                       ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        ;;

    2)
        echo ""
        echo "Available nodes:"
        for i in $(seq 0 $((NUM_NODES - 1))); do
            echo "  $i) ${NODE_MONIKERS[$i]} @ ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]})"
        done
        echo ""
        read -p "Enter node numbers to deploy (space-separated, e.g., '0 2 3'): " NODES_TO_DEPLOY

        if [ -z "$NODES_TO_DEPLOY" ]; then
            echo "No nodes selected. Exiting."
            exit 0
        fi

        read -p "SSH username for remote servers [default: root]: " SSH_USER
        SSH_USER=${SSH_USER:-root}

        echo ""
        echo "Will deploy nodes: $NODES_TO_DEPLOY"
        echo "SSH user: $SSH_USER"
        echo ""
        read -p "Continue with deployment? (y/n): " CONFIRM_DEPLOY

        if [[ ! $CONFIRM_DEPLOY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled."
            exit 0
        fi

        # Check if deploy-production-node.sh exists
        if [ ! -f "./deploy-production-node.sh" ]; then
            echo -e "${RED}❌ deploy-production-node.sh not found in current directory${NC}"
            echo "Please ensure you are in the repository root directory."
            exit 1
        fi

        chmod +x ./deploy-production-node.sh

        # Deploy selected nodes
        for i in $NODES_TO_DEPLOY; do
            if [ $i -ge 0 ] && [ $i -lt $NUM_NODES ]; then
                echo ""
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}Deploying Node $i: ${NODE_MONIKERS[$i]}${NC}"
                echo -e "${GREEN}Target: ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]})${NC}"
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""

                if ./deploy-production-node.sh "$i" "${NODE_HOSTNAMES[$i]}" "$SSH_USER"; then
                    echo -e "${GREEN}✅ Node $i deployed successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to deploy Node $i${NC}"
                    echo ""
                    read -p "Continue with remaining nodes? (y/n): " CONTINUE
                    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                        echo "Deployment stopped."
                        exit 1
                    fi
                fi
            else
                echo -e "${RED}Invalid node number: $i (valid range: 0-$((NUM_NODES - 1)))${NC}"
            fi
        done

        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║        SELECTED NODES DEPLOYED!                                  ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        ;;

    3)
        echo ""
        echo "Skipping deployment. You can deploy later using:"
        echo "  cd $OUTPUT_DIR"
        echo "  ./deploy-node0.sh  # Deploy individual node"
        echo "  ./deploy-all.sh    # Deploy all nodes"
        echo ""
        exit 0
        ;;

    *)
        echo ""
        echo -e "${YELLOW}Invalid choice. Skipping deployment.${NC}"
        echo "You can deploy later using:"
        echo "  cd $OUTPUT_DIR"
        echo "  ./deploy-node0.sh  # Deploy individual node"
        echo "  ./deploy-all.sh    # Deploy all nodes"
        echo ""
        exit 0
        ;;
esac

echo ""
echo -e "${YELLOW}🎯 Next Steps:${NC}"
echo ""
echo "Your nodes are now deployed! Monitor them with:"
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "  ssh $SSH_USER@${NODE_HOSTNAMES[$i]} 'journalctl -u pokerchaind -f'"
done
echo ""
echo "Check node status:"
for i in $(seq 0 $((NUM_NODES - 1))); do
    echo "  curl http://${NODE_IPS[$i]}:26657/status | jq .result.sync_info"
done
echo ""