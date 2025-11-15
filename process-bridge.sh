#!/bin/bash

# Bridge Deposit Processor
# Fetches deposit data from Base CosmosBridge contract by index and submits mint transaction to Pokerchain

set -e

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "❌ ERROR: .env file not found!"
    echo "Please copy .env.example to .env and add your Alchemy API key"
    exit 1
fi

# Configuration
CONTRACT_ADDRESS="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
VALIDATOR_HOST="${VALIDATOR_HOST:-node1.block52.xyz}"
VALIDATOR_USER="${VALIDATOR_USER:-root}"
CHAIN_ID="pokerchain"
GAS="300000"
GAS_PRICES="0.001stake"

# Event signature for Deposited(string indexed account, uint256 amount, uint256 index)
# keccak256("Deposited(string,uint256,uint256)") = 0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2
DEPOSITED_EVENT_TOPIC="0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           Bridge Deposit Processor"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 <deposit_index> [options]"
    echo ""
    echo "Arguments:"
    echo "  <deposit_index>        Deposit index to process (decimal integer)"
    echo ""
    echo "Options:"
    echo "  --validator <host>     Validator host (default: node1.block52.xyz)"
    echo "  --user <user>          SSH user (default: root)"
    echo "  --from <address>       Cosmos address to submit from (optional, auto-detects)"
    echo "  --local                Run locally without SSH (for testing)"
    echo "  --home <path>          Home directory for local pokerchaind (default: ~/.pokerchain)"
    echo "  --dry-run              Show what would be done without executing"
    echo "  --debug                Show detailed debug information"
    echo ""
    echo "Examples:"
    echo "  $0 42                                     # Process deposit index 42"
    echo "  $0 42 --from cosmos1abc...                # Specify address"
    echo "  $0 42 --validator node1.block52.xyz       # Custom validator"
    echo "  $0 42 --local --from cosmos1abc...        # Run locally (no SSH)"
    echo "  $0 42 --local --home ./test/node0         # Local with custom home"
    echo "  $0 42 --dry-run                           # Test without executing"
    echo "  $0 42 --debug                             # Show debug output"
    echo ""
}

# Convert hex to decimal
hex_to_dec() {
    printf "%d" "$1"
}

# Decode hex string to text
decode_hex_string() {
    local hex="$1"
    # Remove 0x prefix
    hex="${hex#0x}"
    # Convert hex to text
    echo "$hex" | xxd -r -p
}

# Convert decimal to hex with 0x prefix and pad to 32 bytes
dec_to_hex() {
    printf "0x%x" "$1"
}

# Pad hex value to 32 bytes (64 hex chars)
pad_hex() {
    local hex="$1"
    # Remove 0x prefix if present
    hex="${hex#0x}"
    # Pad to 64 characters
    printf "%064s" "$hex" | tr ' ' '0'
}

# Query deposit from contract by index
query_deposit_by_index() {
    local deposit_index="$1"
    local debug="${2:-false}"
    
    echo -e "${BLUE}Querying deposit index ${deposit_index} from contract...${NC}"
    
    # Function signature for deposits(uint256): keccak256("deposits(uint256)") = 0xb02c43d0
    local function_sig="0xb02c43d0"
    
    # Encode the index parameter (pad to 32 bytes)
    local index_hex=$(dec_to_hex "$deposit_index")
    local padded_index=$(pad_hex "$index_hex")
    
    # Construct the call data
    local call_data="${function_sig}${padded_index}"
    
    if [ "$debug" = "true" ]; then
        echo ""
        echo "Debug Info:"
        echo "  RPC URL: $ALCHEMY_URL"
        echo "  Contract: $CONTRACT_ADDRESS"
        echo "  Function: deposits(uint256)"
        echo "  Deposit Index: $deposit_index"
        echo "  Call Data: $call_data"
        echo ""
    fi
    
    # Query the contract
    local payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "$CONTRACT_ADDRESS",
    "data": "$call_data"
  }, "latest"],
  "id": 1
}
EOF
)
    
    if [ "$debug" = "true" ]; then
        echo "Request payload:"
        echo "$payload" | jq '.'
        echo ""
    fi
    
    echo "Fetching deposit data from Base..."
    local response=$(curl -s -X POST "$ALCHEMY_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$debug" = "true" ]; then
        echo ""
        echo "Raw response:"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        echo ""
    fi
    
    # Check if response is valid
    if [ -z "$response" ]; then
        echo -e "${RED}❌ No response from Alchemy RPC${NC}"
        return 1
    fi
    
    # Check for JSON-RPC error
    local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [ -n "$error" ]; then
        echo -e "${RED}❌ RPC Error: $error${NC}"
        if [ "$debug" = "true" ]; then
            echo "$response" | jq '.error'
        fi
        return 1
    fi
    
    # Get the result
    local result=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$result" = "null" ] || [ -z "$result" ] || [ "$result" = "0x" ]; then
        echo -e "${RED}❌ Deposit index $deposit_index not found${NC}"
        return 1
    fi
    
    echo "$result"
}

# Parse deposit data returned from contract
parse_deposit_data() {
    local result="$1"
    local deposit_index="$2"
    
    # Remove 0x prefix
    result="${result#0x}"
    
    # Solidity returns: (string account, uint256 amount)
    # Layout: [offset_to_string(32)] [amount(32)] [string_length(32)] [string_data(...)]
    
    # Extract amount (bytes 32-64)
    local amount_hex="0x${result:64:64}"
    local amount=$(hex_to_dec "$amount_hex")
    
    # Extract string offset (bytes 0-32)
    local string_offset_hex="0x${result:0:64}"
    local string_offset=$(hex_to_dec "$string_offset_hex")
    
    # String data starts at offset * 2 (in hex chars)
    local string_start=$((string_offset * 2))
    
    # Extract string length (32 bytes at the string offset)
    local string_len_hex="0x${result:$string_start:64}"
    local string_len=$(hex_to_dec "$string_len_hex")
    
    # Extract string data
    local string_data_start=$((string_start + 64))
    local string_hex="${result:$string_data_start:$((string_len * 2))}"
    
    # Convert hex to ASCII
    local recipient=$(echo "$string_hex" | xxd -r -p)
    
    echo -e "${GREEN}✓ Deposit found:${NC}"
    echo "  Index: $deposit_index"
    echo "  Recipient: $recipient"
    echo "  Amount: $amount"
    
    # Export for later use
    export DEPOSIT_RECIPIENT="$recipient"
    export DEPOSIT_AMOUNT="$amount"
    export DEPOSIT_INDEX="$deposit_index"
}

# Query Ethereum logs for specific block (DEPRECATED - kept for reference)
query_deposits_in_block() {
    local block_number="$1"
    local debug="${2:-false}"
    
    # Convert block number to hex
    local block_hex=$(dec_to_hex "$block_number")
    
    echo -e "${BLUE}Querying Base blockchain for deposits in block ${block_number} (${block_hex})...${NC}"
    
    if [ "$debug" = "true" ]; then
        echo ""
        echo "Debug Info:"
        echo "  RPC URL: $ALCHEMY_URL"
        echo "  Contract: $CONTRACT_ADDRESS"
        echo "  Event Topic: $DEPOSITED_EVENT_TOPIC"
        echo "  Block Number (decimal): $block_number"
        echo "  Block Number (hex): $block_hex"
        echo ""
    fi
    
    # Query logs for the specific block
    local payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "$CONTRACT_ADDRESS",
    "topics": ["$DEPOSITED_EVENT_TOPIC"],
    "fromBlock": "$block_hex",
    "toBlock": "$block_hex"
  }],
  "id": 1
}
EOF
)
    
    if [ "$debug" = "true" ]; then
        echo "Request payload:"
        echo "$payload" | jq '.'
        echo ""
    fi
    
    echo "Fetching deposit events from Base..."
    local response=$(curl -s -X POST "$ALCHEMY_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$debug" = "true" ]; then
        echo ""
        echo "Raw response:"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        echo ""
    fi
    
    # Check if response is valid
    if [ -z "$response" ]; then
        echo -e "${RED}❌ No response from Alchemy RPC${NC}"
        return 1
    fi
    
    # Check for JSON-RPC error
    local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [ -n "$error" ]; then
        echo -e "${RED}❌ RPC Error: $error${NC}"
        if [ "$debug" = "true" ]; then
            echo "$response" | jq '.error'
        fi
        return 1
    fi
    
    # Check if result is null or empty
    local result_check=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$result_check" = "null" ] || [ -z "$result_check" ]; then
        echo -e "${YELLOW}ℹ️  No deposit events found in block $block_number${NC}"
        return 1
    fi
    
    # Count total deposits in this block
    local total=$(echo "$response" | jq -r '.result | length' 2>/dev/null)
    echo -e "${GREEN}✓ Found $total deposit event(s) in block $block_number${NC}"
    echo ""
    
    # Save all results
    echo "$response" | jq -r '.result' > /tmp/block_deposit_events.json
    
    # Display all deposits found
    local event_num=0
    echo "$response" | jq -c '.result[]' | while read -r event; do
        event_num=$((event_num + 1))
        
        local tx_hash=$(echo "$event" | jq -r '.transactionHash')
        local data=$(echo "$event" | jq -r '.data')
        data="${data#0x}"
        
        # Extract amount (first 32 bytes)
        local amount_hex="0x${data:0:64}"
        local amount=$(printf "%d" "$amount_hex" 2>/dev/null || echo "0")
        
        # Extract index/nonce from data (second 32 bytes)
        local index_hex="0x${data:64:64}"
        local index=$(printf "%d" "$index_hex" 2>/dev/null || echo "0")
        
        echo "Deposit #$event_num:"
        echo "  Transaction Hash: $tx_hash"
        echo "  Amount: $amount"
        echo "  Nonce/Index: $index"
        echo ""
        
        # Save each event to separate file for processing
        echo "$event" > "/tmp/deposit_event_${index}.json"
    done
    
    echo "$response"
}

# Parse deposit event (DEPRECATED - kept for reference)
parse_deposit() {
    local event_file="$1"
    
    if [ ! -f "$event_file" ]; then
        echo -e "${RED}❌ Event file not found${NC}"
        return 1
    fi
    
    # Extract transaction hash
    local tx_hash=$(jq -r '.transactionHash' "$event_file")
    
    # Extract data field (contains amount and index)
    local data=$(jq -r '.data' "$event_file")
    
    # Remove 0x prefix
    data="${data#0x}"
    
    # Extract amount (first 32 bytes / 64 hex chars)
    local amount_hex="0x${data:0:64}"
    local amount=$(hex_to_dec "$amount_hex")
    
    # Extract index (second 32 bytes / 64 hex chars)
    local index_hex="0x${data:64:64}"
    local index=$(hex_to_dec "$index_hex")
    
    # Get the full transaction to extract recipient from input data
    local tx_data=$(get_transaction "$tx_hash")
    local recipient=$(extract_recipient_from_tx "$tx_data")
    
    echo -e "${GREEN}✓ Deposit found:${NC}"
    echo "  Transaction: $tx_hash"
    echo "  Recipient: $recipient"
    echo "  Amount: $amount"
    echo "  Nonce: $index"
    
    # Export for later use
    export DEPOSIT_TX_HASH="$tx_hash"
    export DEPOSIT_RECIPIENT="$recipient"
    export DEPOSIT_AMOUNT="$amount"
    export DEPOSIT_NONCE="$index"
}

# Get transaction details
get_transaction() {
    local tx_hash="$1"
    
    local payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["$tx_hash"],
  "id": 1
}
EOF
)
    
    curl -s -X POST "$ALCHEMY_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" | jq -r '.result'
}

# Extract Cosmos recipient address from transaction input data
extract_recipient_from_tx() {
    local tx_data="$1"
    
    # Extract input data
    local input=$(echo "$tx_data" | jq -r '.input')
    
    # Remove 0x prefix
    input="${input#0x}"
    
    # Function signature is first 4 bytes (8 hex chars)
    # For depositUnderlying(uint256,string): 0x3ccfd60b
    # Layout: [selector(4)] [amount(32)] [string_offset(32)] [string_length(32)] [string_data(...)]
    
    # Skip: selector(8) + amount(64) + string_offset(64) = 136 chars
    # Read string length at position 136
    local string_len_hex="0x${input:136:64}"
    local string_len=$(hex_to_dec "$string_len_hex")
    
    # String data starts at position 200
    local string_hex="${input:200:$((string_len * 2))}"
    
    # Convert hex to ASCII
    local recipient=$(echo "$string_hex" | xxd -r -p)
    
    echo "$recipient"
}

# Submit mint transaction to validator
submit_mint_tx() {
    local from_address="$1"
    local recipient="$2"
    local amount="$3"
    local nonce="$4"
    local dry_run="$5"
    local local_mode="$6"
    local home_dir="$7"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Submitting Mint Transaction${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Transaction Details:"
    echo "  From: $from_address"
    echo "  Recipient: $recipient"
    echo "  Amount: $amount"
    echo "  Deposit Index: $nonce"
    echo "  Mode: $([ "$local_mode" = "true" ] && echo "Local" || echo "Remote (SSH)")"
    [ "$local_mode" = "true" ] && echo "  Home: $home_dir"
    echo ""
    
    # Build the pokerchaind command
    local cmd="pokerchaind tx poker mint \
  --recipient='$recipient' \
  --amount=$amount \
  --nonce=$nonce \
  --from='$from_address' \
  --chain-id='$CHAIN_ID' \
  --gas='$GAS' \
  --gas-prices='$GAS_PRICES' \
  --yes"
    
    if [ "$local_mode" = "true" ] && [ -n "$home_dir" ]; then
        cmd="$cmd --home='$home_dir'"
    fi
    
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN - Command that would be executed:${NC}"
        echo ""
        if [ "$local_mode" = "true" ]; then
            echo "$cmd"
        else
            echo "ssh $VALIDATOR_USER@$VALIDATOR_HOST << 'ENDSSH'"
            echo "$cmd"
            echo "ENDSSH"
        fi
        echo ""
        return 0
    fi
    
    if [ "$local_mode" = "true" ]; then
        echo -e "${YELLOW}Executing locally...${NC}"
        echo ""
        
        eval $cmd
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "Transaction submitted!"
            echo ""
            echo "Check transaction status:"
            echo "  pokerchaind query tx <txhash>"
            echo ""
            echo "Verify recipient balance:"
            echo "  pokerchaind query bank balances $recipient"
        fi
    else
        echo -e "${YELLOW}Connecting to validator...${NC}"
        
        # Execute on remote validator
        ssh "$VALIDATOR_USER@$VALIDATOR_HOST" << ENDSSH
set -e

echo "Submitting mint transaction..."

$cmd

echo ""
echo "Transaction submitted!"
echo ""
echo "Check transaction status:"
echo "  pokerchaind query tx <txhash>"
echo ""
echo "Verify recipient balance:"
echo "  pokerchaind query bank balances $recipient"

ENDSSH
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Mint transaction submitted successfully!${NC}"
        else
            echo ""
            echo -e "${RED}❌ Failed to submit transaction${NC}"
            return 1
        fi
    fi
}

# Check if deposit was already processed by nonce
check_if_processed() {
    local nonce="$1"
    local local_mode="$2"
    local home_dir="$3"
    
    echo -e "${BLUE}Checking if deposit index $nonce already processed...${NC}"
    
    if [ "$local_mode" = "true" ]; then
        local query_cmd="pokerchaind query poker processed-deposit $nonce"
        if [ -n "$home_dir" ]; then
            query_cmd="$query_cmd --home '$home_dir'"
        fi
        eval $query_cmd 2>/dev/null || true
    else
        ssh "$VALIDATOR_USER@$VALIDATOR_HOST" << ENDSSH 2>/dev/null || true
pokerchaind query poker processed-deposit $nonce 2>/dev/null
ENDSSH
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}⚠️  This deposit may have already been processed${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Process deposit by index
process_deposit_by_index() {
    local deposit_index="$1"
    local from_address="$2"
    local dry_run="$3"
    local debug="$4"
    local local_mode="$5"
    local home_dir="$6"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Processing Deposit Index: $deposit_index${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Query deposit from contract
    local result=$(query_deposit_by_index "$deposit_index" "$debug")
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to fetch deposit data${NC}"
        return 1
    fi
    
    # Parse deposit details
    if ! parse_deposit_data "$result" "$deposit_index"; then
        echo -e "${RED}❌ Failed to parse deposit data${NC}"
        return 1
    fi
    
    # Check if already processed
    if [ "$dry_run" != "true" ]; then
        check_if_processed "$DEPOSIT_INDEX" "$local_mode" "$home_dir"
    fi
    
    # Submit transaction
    submit_mint_tx \
        "$from_address" \
        "$DEPOSIT_RECIPIENT" \
        "$DEPOSIT_AMOUNT" \
        "$DEPOSIT_INDEX" \
        "$dry_run" \
        "$local_mode" \
        "$home_dir"
}

# Process deposits from a block (DEPRECATED - kept for reference)
process_deposits_from_block() {
    local block_number="$1"
    local from_address="$2"
    local dry_run="$3"
    local debug="$4"
    
    # Query deposits in the block
    local response=$(query_deposits_in_block "$block_number" "$debug")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Get all deposit indices from the block
    local indices=()
    while read -r event; do
        local data=$(echo "$event" | jq -r '.data')
        data="${data#0x}"
        
        # Extract index/nonce from data (second 32 bytes)
        local index_hex="0x${data:64:64}"
        local index=$(printf "%d" "$index_hex" 2>/dev/null || echo "0")
        
        indices+=("$index")
    done < <(echo "$response" | jq -c '.result[]')
    
    if [ ${#indices[@]} -eq 0 ]; then
        echo -e "${YELLOW}ℹ️  No deposits to process${NC}"
        return 0
    fi
    
    # Process each deposit
    for index in "${indices[@]}"; do
        local event_file="/tmp/deposit_event_${index}.json"
        
        if [ ! -f "$event_file" ]; then
            echo -e "${YELLOW}⚠️  Skipping index $index - event file not found${NC}"
            continue
        fi
        
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Processing Deposit with Nonce: $index${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Parse deposit details
        if ! parse_deposit "$event_file"; then
            echo -e "${RED}❌ Failed to parse deposit $index${NC}"
            continue
        fi
        
        # Check if already processed
        if [ "$dry_run" != "true" ]; then
            check_if_processed "$DEPOSIT_TX_HASH"
        fi
        
        # Submit transaction
        submit_mint_tx \
            "$from_address" \
            "$DEPOSIT_TX_HASH" \
            "$DEPOSIT_RECIPIENT" \
            "$DEPOSIT_AMOUNT" \
            "$DEPOSIT_NONCE" \
            "$dry_run"
        
        # Cleanup
        rm -f "$event_file"
    done
}

# Main function
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    # Check for help flag first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_usage
            exit 0
        fi
    done
    
    local deposit_index="$1"
    shift
    
    local dry_run="false"
    local from_address=""
    local debug="false"
    local local_mode="false"
    local home_dir="$HOME/.pokerchain"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --validator)
                VALIDATOR_HOST="$2"
                shift 2
                ;;
            --user)
                VALIDATOR_USER="$2"
                shift 2
                ;;
            --from)
                from_address="$2"
                shift 2
                ;;
            --local)
                local_mode="true"
                shift
                ;;
            --home)
                home_dir="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --debug)
                debug="true"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Auto-enable local mode if validator is localhost
    if [[ "$VALIDATOR_HOST" == "localhost" ]] || [[ "$VALIDATOR_HOST" == "127.0.0.1" ]]; then
        local_mode="true"
        echo -e "${BLUE}ℹ️  Auto-enabling local mode (validator is localhost)${NC}"
    fi
    
    # Validate deposit index
    if ! [[ "$deposit_index" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid deposit index. Must be a positive integer.${NC}"
        exit 1
    fi
    
    print_header
    
    # Get from address if not provided
    if [ -z "$from_address" ]; then
        echo ""
        echo -e "${BLUE}Getting validator address...${NC}"
        
        if [ "$local_mode" = "true" ]; then
            # Get local keys
            local keys_cmd="pokerchaind keys list --output json 2>/dev/null"
            if [ -n "$home_dir" ]; then
                keys_cmd="$keys_cmd --home '$home_dir'"
            fi
            from_address=$(eval $keys_cmd | jq -r '.[0].address' 2>/dev/null || echo "")
        else
            # Try to get the first key from the remote validator
            from_address=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" \
                "pokerchaind keys list --output json 2>/dev/null | jq -r '.[0].address' 2>/dev/null" || echo "")
        fi
        
        if [ -z "$from_address" ] || [ "$from_address" = "null" ]; then
            echo -e "${YELLOW}⚠️  Could not auto-detect validator address${NC}"
            echo ""
            read -p "Enter Cosmos address to submit from: " from_address
            if [ -z "$from_address" ]; then
                echo -e "${RED}❌ From address required${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}✓ Using validator address: $from_address${NC}"
        fi
    fi
    
    echo ""
    
    # Process the deposit by index
    process_deposit_by_index "$deposit_index" "$from_address" "$dry_run" "$debug" "$local_mode" "$home_dir"
    
    echo ""
    echo -e "${GREEN}✅ Done!${NC}"
    echo ""
}

# Run main
main "$@"