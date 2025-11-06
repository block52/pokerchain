#!/bin/bash

# Bridge Deposit Scanner & Batch Processor
# Scans for all deposits and processes unprocessed ones

set -e

# Configuration
ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/uwae8IxsUFGbRFh8fagTMrGz1w5iuvpc"
CONTRACT_ADDRESS="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
VALIDATOR_HOST="${VALIDATOR_HOST:-node1.block52.xyz}"
VALIDATOR_USER="${VALIDATOR_USER:-root}"
DEPOSITED_EVENT_TOPIC="0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           Bridge Deposit Scanner & Batch Processor"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Scan all deposits from Ethereum
scan_all_deposits() {
    echo -e "${BLUE}Scanning all deposits from Base...${NC}"
    
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
    
    echo "$response" | jq -r '.result' > /tmp/all_deposits.json
    
    local count=$(jq '. | length' /tmp/all_deposits.json)
    echo -e "${GREEN}✓ Found $count total deposits${NC}"
    
    # Parse each deposit
    echo ""
    echo "Deposits:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-8s %-20s %-66s %-10s\n" "Nonce" "Amount" "Transaction" "Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    jq -r '.[] | @json' /tmp/all_deposits.json | while read -r event; do
        parse_and_check_deposit "$event"
    done
}

# Parse deposit and check if processed
parse_and_check_deposit() {
    local event="$1"
    
    # Extract data
    local tx_hash=$(echo "$event" | jq -r '.transactionHash')
    local data=$(echo "$event" | jq -r '.data')
    data="${data#0x}"
    
    # Parse amount and nonce
    local amount_hex="0x${data:0:64}"
    local amount=$(printf "%d" "$amount_hex")
    
    local nonce_hex="0x${data:64:64}"
    local nonce=$(printf "%d" "$nonce_hex")
    
    # Check if processed on Cosmos
    local status=$(check_processed_on_cosmos "$tx_hash")
    
    # Color code status
    local status_colored
    if [ "$status" = "PROCESSED" ]; then
        status_colored="${GREEN}✓ PROCESSED${NC}"
    else
        status_colored="${YELLOW}○ PENDING${NC}"
    fi
    
    printf "%-8s %-20s %-66s " "$nonce" "$amount" "$tx_hash"
    echo -e "$status_colored"
    
    # Store pending deposits
    if [ "$status" = "PENDING" ]; then
        echo "$nonce|$tx_hash|$amount" >> /tmp/pending_deposits.txt
    fi
}

# Check if transaction is processed on Cosmos
check_processed_on_cosmos() {
    local tx_hash="$1"
    
    # Query Cosmos chain
    local result=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" \
        "pokerchaind query poker show-processed-eth-tx $tx_hash 2>/dev/null" || echo "not found")
    
    if [[ "$result" == *"not found"* ]]; then
        echo "PENDING"
    else
        echo "PROCESSED"
    fi
}

# Process pending deposits
process_pending() {
    if [ ! -f /tmp/pending_deposits.txt ]; then
        echo ""
        echo -e "${GREEN}✓ No pending deposits to process${NC}"
        return 0
    fi
    
    local count=$(wc -l < /tmp/pending_deposits.txt)
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}Found $count pending deposits${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "Process all pending deposits? (y/n): " process_all
    if [[ ! $process_all =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi
    
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
            return 1
        fi
    else
        echo -e "${GREEN}✓ Using validator address: $from_address${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Processing pending deposits...${NC}"
    echo ""
    
    local processed=0
    local failed=0
    
    while IFS='|' read -r nonce tx_hash amount; do
        echo -e "${CYAN}Processing nonce $nonce...${NC}"
        
        if ./process-bridge-deposit.sh "$nonce" --from "$from_address" --validator "$VALIDATOR_HOST"; then
            ((processed++))
            echo -e "${GREEN}✓ Nonce $nonce processed${NC}"
        else
            ((failed++))
            echo -e "${RED}✗ Nonce $nonce failed${NC}"
        fi
        
        echo ""
        sleep 2  # Rate limit
    done < /tmp/pending_deposits.txt
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ Processed: $processed${NC}"
    if [ $failed -gt 0 ]; then
        echo -e "${RED}✗ Failed: $failed${NC}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Show menu
show_menu() {
    print_header
    echo ""
    echo "Options:"
    echo "  1) Scan and list all deposits"
    echo "  2) Process all pending deposits (batch)"
    echo "  3) Process specific deposit by nonce"
    echo "  4) Monitor for new deposits (continuous)"
    echo "  5) Exit"
    echo ""
    read -p "Choose option [1-5]: " choice
}

# Monitor for new deposits
monitor_deposits() {
    echo ""
    echo -e "${BLUE}Monitoring for new deposits...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    local last_count=0
    
    while true; do
        # Scan deposits
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
        
        local current_count=$(echo "$response" | jq -r '.result | length')
        
        if [ "$current_count" -gt "$last_count" ]; then
            local new_deposits=$((current_count - last_count))
            echo -e "${GREEN}🔔 $new_deposits new deposit(s) detected! Total: $current_count${NC}"
            
            # Optionally auto-process
            read -t 5 -p "Process new deposits? (y/n): " process_new || process_new="n"
            if [[ $process_new =~ ^[Yy]$ ]]; then
                scan_all_deposits
                process_pending
            fi
        else
            echo -e "${CYAN}[$(date '+%H:%M:%S')] No new deposits. Total: $current_count${NC}"
        fi
        
        last_count=$current_count
        sleep 30  # Check every 30 seconds
    done
}

# Process specific deposit
process_specific() {
    echo ""
    read -p "Enter deposit nonce: " nonce
    
    if [ -z "$nonce" ]; then
        echo -e "${RED}❌ Nonce required${NC}"
        return 1
    fi
    
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
            return 1
        fi
    else
        echo -e "${GREEN}✓ Using validator address: $from_address${NC}"
    fi
    
    ./process-bridge-deposit.sh "$nonce" --from "$from_address" --validator "$VALIDATOR_HOST"
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    # Check if process-bridge-deposit.sh exists
    if [ ! -f "./process-bridge-deposit.sh" ]; then
        echo -e "${RED}❌ process-bridge-deposit.sh not found${NC}"
        echo "Please ensure it's in the same directory"
        exit 1
    fi
    
    while true; do
        # Clean up temp files
        rm -f /tmp/pending_deposits.txt /tmp/all_deposits.json
        
        show_menu
        
        case $choice in
            1)
                print_header
                scan_all_deposits
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                print_header
                scan_all_deposits
                process_pending
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                process_specific
                ;;
            4)
                monitor_deposits
                ;;
            5)
                echo ""
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run
main