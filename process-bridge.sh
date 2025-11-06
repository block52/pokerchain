#!/bin/bash

# Bridge Deposit Processor
# Fetches deposit data from Base (via Alchemy) and submits mint transaction to Pokerchain

set -e

# Configuration
ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/uwae8IxsUFGbRFh8fagTMrGz1w5iuvpc"
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
    echo "Usage: $0 <nonce> [options]"
    echo ""
    echo "Options:"
    echo "  --validator <host>     Validator host (default: node1.block52.xyz)"
    echo "  --user <user>          SSH user (default: root)"
    echo "  --from <address>       Cosmos address to submit from (optional, auto-detects)"
    echo "  --dry-run              Show what would be done without executing"
    echo ""
    echo "Examples:"
    echo "  $0 1                                      # Auto-detect validator address"
    echo "  $0 5 --from cosmos1abc...                 # Specify address"
    echo "  $0 5 --validator node1.block52.xyz        # Custom validator"
    echo "  $0 10 --dry-run                           # Test without executing"
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

# Query Ethereum logs for specific deposit
query_deposit() {
    local nonce="$1"
    
    echo -e "${BLUE}Querying Base blockchain for deposit #${nonce}...${NC}"
    
    # Convert nonce to hex (padded to 32 bytes)
    local nonce_hex=$(printf "0x%064x" "$nonce")
    
    # Query logs with nonce as indexed parameter
    # The Deposited event has: event Deposited(string indexed account, uint256 amount, uint256 index)
    # Topics: [0] = event signature, [1] = keccak256(account), [2] = none, [3] = none
    # Data: amount (32 bytes) + index (32 bytes)
    
    local payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "$CONTRACT_ADDRESS",
    "topics": ["$DEPOSITED_EVENT_TOPIC"],
    "fromBlock": "0x0",
    "toBlock": "latest"
  }],
  "id": 1
}
EOF
)
    
    local response=$(curl -s -X POST "$ALCHEMY_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    # Parse response and find the event with matching nonce
    echo "$response" | jq -r ".result[] | select(.data as \$data | 
        (\$data | .[130:194]) == \"$(printf "%064x" $nonce)\")" > /tmp/deposit_event.json
    
    if [ ! -s /tmp/deposit_event.json ]; then
        echo -e "${RED}❌ No deposit found for nonce $nonce${NC}"
        return 1
    fi
    
    cat /tmp/deposit_event.json
}

# Parse deposit event
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
    local tx_hash="$2"
    local recipient="$3"
    local amount="$4"
    local nonce="$5"
    local dry_run="$6"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Submitting Mint Transaction${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Transaction Details:"
    echo "  From: $from_address"
    echo "  Recipient: $recipient"
    echo "  Amount: $amount"
    echo "  Eth TX: $tx_hash"
    echo "  Nonce: $nonce"
    echo ""
    
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN - Command that would be executed:${NC}"
        echo ""
        echo "ssh $VALIDATOR_USER@$VALIDATOR_HOST << 'ENDSSH'"
        echo "pokerchaind tx poker mint \\"
        echo "  --eth-tx-hash='$tx_hash' \\"
        echo "  --recipient='$recipient' \\"
        echo "  --amount=$amount \\"
        echo "  --nonce=$nonce \\"
        echo "  --from='$from_address' \\"
        echo "  --chain-id='$CHAIN_ID' \\"
        echo "  --gas='$GAS' \\"
        echo "  --gas-prices='$GAS_PRICES' \\"
        echo "  --yes"
        echo "ENDSSH"
        echo ""
        return 0
    fi
    
    echo -e "${YELLOW}Connecting to validator...${NC}"
    
    # Execute on remote validator
    ssh "$VALIDATOR_USER@$VALIDATOR_HOST" << ENDSSH
set -e

echo "Submitting mint transaction..."

pokerchaind tx poker mint \\
  --eth-tx-hash='$tx_hash' \\
  --recipient='$recipient' \\
  --amount=$amount \\
  --nonce=$nonce \\
  --from='$from_address' \\
  --chain-id='$CHAIN_ID' \\
  --gas='$GAS' \\
  --gas-prices='$GAS_PRICES' \\
  --yes

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
}

# Check if deposit was already processed
check_if_processed() {
    local tx_hash="$1"
    
    echo -e "${BLUE}Checking if deposit already processed...${NC}"
    
    ssh "$VALIDATOR_USER@$VALIDATOR_HOST" << ENDSSH 2>/dev/null || true
pokerchaind query poker processed-eth-tx $tx_hash 2>/dev/null
ENDSSH
    
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}⚠️  This deposit may have already been processed${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Main function
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    local nonce="$1"
    shift
    
    local dry_run="false"
    local from_address=""
    
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
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate nonce
    if ! [[ "$nonce" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid nonce. Must be a number.${NC}"
        exit 1
    fi
    
    print_header
    
    # Query deposit from Ethereum
    if ! query_deposit "$nonce" > /tmp/deposit_event.json; then
        exit 1
    fi
    
    # Parse deposit details
    if ! parse_deposit "/tmp/deposit_event.json"; then
        exit 1
    fi
    
    # Check if already processed
    if [ "$dry_run" != "true" ]; then
        check_if_processed "$DEPOSIT_TX_HASH"
    fi
    
    # Get from address if not provided
    if [ -z "$from_address" ]; then
        echo ""
        echo -e "${BLUE}Getting validator address...${NC}"
        
        # Try to get the first key from the validator
        from_address=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" \
            "pokerchaind keys list --output json 2>/dev/null | jq -r '.[0].address' 2>/dev/null" || echo "")
        
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
    
    # Submit transaction
    submit_mint_tx \
        "$from_address" \
        "$DEPOSIT_TX_HASH" \
        "$DEPOSIT_RECIPIENT" \
        "$DEPOSIT_AMOUNT" \
        "$DEPOSIT_NONCE" \
        "$dry_run"
    
    # Cleanup
    rm -f /tmp/deposit_event.json
    
    echo ""
    echo -e "${GREEN}✅ Done!${NC}"
    echo ""
}

# Run main
main "$@"