#!/bin/bash

# Script to create a poker table/game using a user's seed phrase
# Usage: ./create-table.sh [options]

set -e

# Default values
CHAIN_ID="pokerchain"
NODE="http://localhost:26657"
KEYRING_BACKEND="test"
KEY_NAME="temp-poker-key"

# Default game parameters (can be overridden by arguments)
MIN_BUY_IN="1000000"        # 1 B52 token (assuming 6 decimals)
MAX_BUY_IN="100000000"      # 100 B52 tokens
MIN_PLAYERS="2"
MAX_PLAYERS="9"
SMALL_BLIND="50000"         # 0.05 B52
BIG_BLIND="100000"          # 0.1 B52
TIMEOUT="300"               # 5 minutes in seconds
GAME_TYPE="texas-holdem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Poker Table Creation Script ===${NC}\n"

# Function to show usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -s, --seed PHRASE       Seed phrase (24 words)"
    echo "  -f, --seed-file FILE    Read seed phrase from file (e.g., seeds.txt line number)"
    echo "  -n, --node URL          Node URL (default: http://localhost:26657)"
    echo "  -c, --chain-id ID       Chain ID (default: pokerchain)"
    echo ""
    echo "Game Parameters:"
    echo "  --min-buy-in NUM        Minimum buy-in amount (default: 1000000)"
    echo "  --max-buy-in NUM        Maximum buy-in amount (default: 100000000)"
    echo "  --min-players NUM       Minimum players (default: 2)"
    echo "  --max-players NUM       Maximum players (default: 9)"
    echo "  --small-blind NUM       Small blind amount (default: 50000)"
    echo "  --big-blind NUM         Big blind amount (default: 100000)"
    echo "  --timeout SECS          Action timeout in seconds (default: 300)"
    echo "  --game-type TYPE        Game type (default: texas-holdem)"
    echo ""
    echo "Examples:"
    echo "  $0 -s 'word1 word2 ... word24'"
    echo "  $0 -f seeds.txt:1  # Use first line from seeds.txt"
    echo "  $0 --min-buy-in 5000000 --max-buy-in 50000000"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--seed)
            SEED_PHRASE="$2"
            shift 2
            ;;
        -f|--seed-file)
            SEED_FILE="$2"
            shift 2
            ;;
        -n|--node)
            NODE="$2"
            shift 2
            ;;
        -c|--chain-id)
            CHAIN_ID="$2"
            shift 2
            ;;
        --min-buy-in)
            MIN_BUY_IN="$2"
            shift 2
            ;;
        --max-buy-in)
            MAX_BUY_IN="$2"
            shift 2
            ;;
        --min-players)
            MIN_PLAYERS="$2"
            shift 2
            ;;
        --max-players)
            MAX_PLAYERS="$2"
            shift 2
            ;;
        --small-blind)
            SMALL_BLIND="$2"
            shift 2
            ;;
        --big-blind)
            BIG_BLIND="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --game-type)
            GAME_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Handle seed phrase input
if [[ -z "$SEED_PHRASE" && -z "$SEED_FILE" ]]; then
    echo -e "${YELLOW}No seed phrase provided. Please provide one:${NC}"
    echo "1. Enter seed phrase manually"
    echo "2. Select from seeds.txt file"
    read -p "Choose option (1 or 2): " choice
    
    if [[ "$choice" == "1" ]]; then
        echo -e "${YELLOW}Enter your 24-word seed phrase:${NC}"
        read -r SEED_PHRASE
    elif [[ "$choice" == "2" ]]; then
        if [[ ! -f "seeds.txt" ]]; then
            echo -e "${RED}Error: seeds.txt not found in current directory${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Available seed phrases from seeds.txt:${NC}"
        mapfile -t MNEMONICS < seeds.txt
        for i in "${!MNEMONICS[@]}"; do
            mnemonic="${MNEMONICS[$i]}"
            words=($mnemonic)
            preview="${words[0]} ${words[1]} ${words[2]} ... ${words[21]} ${words[22]} ${words[23]}"
            echo "  $((i+1)). $preview"
        done
        
        read -p "Select seed number (1-${#MNEMONICS[@]}): " seed_num
        if [[ $seed_num -lt 1 || $seed_num -gt ${#MNEMONICS[@]} ]]; then
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi
        SEED_PHRASE="${MNEMONICS[$((seed_num-1))]}"
    else
        echo -e "${RED}Invalid choice${NC}"
        exit 1
    fi
elif [[ -n "$SEED_FILE" ]]; then
    # Parse seed file format: filename:line_number
    if [[ "$SEED_FILE" =~ ^(.+):([0-9]+)$ ]]; then
        file="${BASH_REMATCH[1]}"
        line="${BASH_REMATCH[2]}"
        
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}Error: Seed file not found: $file${NC}"
            exit 1
        fi
        
        SEED_PHRASE=$(sed -n "${line}p" "$file")
        if [[ -z "$SEED_PHRASE" ]]; then
            echo -e "${RED}Error: Could not read line $line from $file${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: Invalid seed file format. Use: filename:line_number${NC}"
        exit 1
    fi
fi

# Validate seed phrase
word_count=$(echo "$SEED_PHRASE" | wc -w)
if [[ $word_count -ne 24 && $word_count -ne 12 ]]; then
    echo -e "${RED}Error: Seed phrase must be 12 or 24 words (got $word_count words)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Seed phrase validated ($word_count words)${NC}\n"

# Check if pokerchaind binary exists
if ! command -v pokerchaind &> /dev/null; then
    echo -e "${RED}Error: pokerchaind binary not found in PATH${NC}"
    echo "Please ensure pokerchaind is installed and in your PATH"
    exit 1
fi

# Generate unique key name with timestamp to avoid conflicts
KEY_NAME="poker-table-creator-$(date +%s)"

echo -e "${YELLOW}Step 1: Recovering key from seed phrase...${NC}"

# Create temporary keyring directory
TEMP_KEYRING_DIR=$(mktemp -d)
cleanup() {
    echo -e "\n${YELLOW}Cleaning up temporary keyring...${NC}"
    rm -rf "$TEMP_KEYRING_DIR"
}
trap cleanup EXIT

# Recover key from seed phrase
echo "$SEED_PHRASE" | pokerchaind keys add "$KEY_NAME" \
    --recover \
    --keyring-backend "$KEYRING_BACKEND" \
    --keyring-dir "$TEMP_KEYRING_DIR" \
    --output json > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Failed to recover key from seed phrase${NC}"
    exit 1
fi

# Get the address
ADDRESS=$(pokerchaind keys show "$KEY_NAME" \
    --keyring-backend "$KEYRING_BACKEND" \
    --keyring-dir "$TEMP_KEYRING_DIR" \
    --address)

echo -e "${GREEN}✓ Key recovered successfully${NC}"
echo -e "  Address: ${GREEN}$ADDRESS${NC}\n"

# Check account balance
echo -e "${YELLOW}Step 2: Checking account balance...${NC}"
BALANCE=$(pokerchaind query bank balances "$ADDRESS" --node "$NODE" --output json 2>/dev/null || echo "{}")
echo -e "  Balance: $BALANCE\n"

# Display game parameters
echo -e "${YELLOW}Step 3: Creating game with parameters:${NC}"
echo "  Min Buy-in:    $MIN_BUY_IN"
echo "  Max Buy-in:    $MAX_BUY_IN"
echo "  Min Players:   $MIN_PLAYERS"
echo "  Max Players:   $MAX_PLAYERS"
echo "  Small Blind:   $SMALL_BLIND"
echo "  Big Blind:     $BIG_BLIND"
echo "  Timeout:       $TIMEOUT seconds"
echo "  Game Type:     $GAME_TYPE"
echo ""

read -p "Proceed with table creation? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}Cancelled by user${NC}"
    exit 0
fi

# Create the game transaction
echo -e "\n${YELLOW}Step 4: Broadcasting create-game transaction...${NC}"

TX_OUTPUT=$(pokerchaind tx poker create-game \
    "$MIN_BUY_IN" \
    "$MAX_BUY_IN" \
    "$MIN_PLAYERS" \
    "$MAX_PLAYERS" \
    "$SMALL_BLIND" \
    "$BIG_BLIND" \
    "$TIMEOUT" \
    "$GAME_TYPE" \
    --from "$KEY_NAME" \
    --keyring-backend "$KEYRING_BACKEND" \
    --keyring-dir "$TEMP_KEYRING_DIR" \
    --chain-id "$CHAIN_ID" \
    --node "$NODE" \
    --gas auto \
    --gas-adjustment 1.5 \
    --yes \
    --output json 2>&1)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Transaction failed${NC}"
    echo "$TX_OUTPUT"
    exit 1
fi

# Parse transaction hash
TX_HASH=$(echo "$TX_OUTPUT" | grep -o '"txhash":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$TX_HASH" ]]; then
    echo -e "${YELLOW}Warning: Could not extract transaction hash from output${NC}"
    echo "$TX_OUTPUT"
else
    echo -e "${GREEN}✓ Transaction broadcast successfully!${NC}"
    echo -e "  TX Hash: ${GREEN}$TX_HASH${NC}"
    echo ""
    echo -e "${YELLOW}Waiting for transaction to be included in a block...${NC}"
    sleep 6
    
    # Query transaction result
    echo -e "\n${YELLOW}Step 5: Querying transaction result...${NC}"
    TX_RESULT=$(pokerchaind query tx "$TX_HASH" --node "$NODE" --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Transaction confirmed!${NC}\n"
        
        # Try to extract game ID from events
        GAME_ID=$(echo "$TX_RESULT" | grep -o '"game_id","value":"[^"]*"' | cut -d'"' -f6 | head -1)
        
        if [[ -n "$GAME_ID" ]]; then
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}  🎰 Table Created Successfully! 🎰${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "  Game ID: ${GREEN}$GAME_ID${NC}"
            echo -e "  Creator: $ADDRESS"
            echo -e "  TX Hash: $TX_HASH"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            
            echo -e "${YELLOW}To query the game details:${NC}"
            echo "  pokerchaind query poker game $GAME_ID --node $NODE"
        else
            echo -e "${YELLOW}Transaction successful but could not extract game ID${NC}"
            echo -e "${YELLOW}Full transaction result:${NC}"
            echo "$TX_RESULT" | jq '.' 2>/dev/null || echo "$TX_RESULT"
        fi
    else
        echo -e "${YELLOW}Could not query transaction (it may still be pending)${NC}"
        echo "  TX Hash: $TX_HASH"
        echo "  Check status with: pokerchaind query tx $TX_HASH --node $NODE"
    fi
fi

echo -e "\n${GREEN}Script completed!${NC}"
