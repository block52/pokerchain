#!/bin/bash

# Bridge Deposit Processor
# Fetches deposit data from Base CosmosBridge contract by index and submits mint transaction to Pokerchain
#
# FEATURES:
# =========
# - Auto-detects available keys on the validator (no hardcoded key names)
# - Supports multiple validators via --validator flag
# - Can list available keys with --list-keys
# - Validates deposit hasn't been processed before submitting
#
# SETUP REQUIREMENTS:
# ===================
# - .env file with ALCHEMY_URL for Base blockchain queries
# - SSH access to validator node
# - At least one key in the validator's keyring-test with stake for gas
# - On-chain bridge keeper configured with Ethereum RPC endpoint
#
# USAGE:
# ======
# ./process-bridge.sh <deposit_index>                    # Auto-detect key
# ./process-bridge.sh <deposit_index> --from <keyname>   # Specify key
# ./process-bridge.sh --list-keys                        # Show available keys
# ./process-bridge.sh --list-keys --validator <host>     # Keys on specific validator

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
CHAIN_ID="pokerchain"
GAS="300000"
GAS_PRICES="0.001stake"  # Gasless transactions
DEFAULT_FROM_KEY=""  # Will be auto-detected from validator keyring

# Default network
VALIDATOR_HOST="${VALIDATOR_HOST:-}"
VALIDATOR_USER="${VALIDATOR_USER:-root}"

# Query all deposits and their status
query_all_deposits() {
    local local_mode="$1"
    local home_dir="$2"
    local max_deposits="${3:-20}"  # Default to checking first 20 deposits

    echo -e "  ${CYAN}🔍${NC} Scanning Base chain for deposits..."
    echo ""

    local deposits=()
    local i=0
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_idx=0

    while [ $i -lt $max_deposits ]; do
        # Show spinner
        printf "\r  ${PURPLE}${spinner[$spin_idx]}${NC} Checking deposit ${WHITE}#%d${NC}...  " "$i"
        spin_idx=$(( (spin_idx + 1) % 10 ))

        # Query deposit from contract
        local result=$(query_deposit_by_index "$i" "false" 2>/dev/null)

        if [ -z "$result" ] || [ "$result" = "0x" ]; then
            break  # No more deposits
        fi

        # Parse the result to get recipient and amount
        local result_clean="${result#0x}"
        local amount_hex="0x${result_clean:64:64}"
        local amount=$(printf "%d" "$amount_hex" 2>/dev/null || echo "0")

        # Get string data
        local string_offset_hex="0x${result_clean:0:64}"
        local string_offset=$(printf "%d" "$string_offset_hex" 2>/dev/null || echo "0")
        local string_start=$((string_offset * 2))
        local string_len_hex="0x${result_clean:$string_start:64}"
        local string_len=$(printf "%d" "$string_len_hex" 2>/dev/null || echo "0")
        local string_data_start=$((string_start + 64))
        local string_hex="${result_clean:$string_data_start:$((string_len * 2))}"
        local recipient=$(echo "$string_hex" | xxd -r -p 2>/dev/null)

        if [ -z "$recipient" ] || [ "$amount" = "0" ]; then
            break
        fi

        # Check if processed
        local tx_hash_input="${CONTRACT_ADDRESS}-${i}"
        local eth_tx_hash="0x$(echo -n "$tx_hash_input" | shasum -a 256 | cut -d' ' -f1)"

        local is_processed="pending"
        local query_result=""
        if [ "$local_mode" = "true" ]; then
            query_result=$(pokerchaind query poker is-tx-processed --eth-tx-hash="$eth_tx_hash" --output json ${home_dir:+--home=$home_dir} 2>/dev/null)
        else
            query_result=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" "pokerchaind query poker is-tx-processed --eth-tx-hash='$eth_tx_hash' --output json 2>/dev/null" 2>/dev/null)
        fi

        if echo "$query_result" | grep -q '"processed":\s*true'; then
            is_processed="processed"
        fi

        # Format amount for display (USDC has 6 decimals)
        local amount_usdc=$(echo "scale=6; $amount / 1000000" | bc 2>/dev/null || echo "$amount")

        deposits+=("$i|$recipient|$amount_usdc|$is_processed")

        i=$((i + 1))
    done

    printf "\r  ${GREEN}✓${NC} Found ${WHITE}%d${NC} deposits                    \n" "${#deposits[@]}"
    echo ""

    # Store deposits in global variable
    DEPOSIT_LIST=("${deposits[@]}")
}

# Draw a single deposit row
draw_deposit_row() {
    local idx="$1"
    local recipient="$2"
    local amount="$3"
    local status="$4"
    local is_selected="$5"
    local is_pending="$6"

    # Truncate recipient for display
    local short_recipient="${recipient:0:15}...${recipient: -12}"

    # Pad values for alignment
    local padded_idx=$(printf "%-4s" "$idx")
    local padded_recipient=$(printf "%-38s" "$short_recipient")
    local padded_amount=$(printf "\$%-13s" "$amount")

    if [ "$is_selected" = "true" ]; then
        # Selected row - highlighted
        if [ "$is_pending" = "true" ]; then
            echo -e "  ${CYAN}│${NC} ${WHITE}▶${NC}${CYAN}${BOLD}${padded_idx}${NC} ${CYAN}│${NC} ${BOLD}${WHITE}${padded_recipient}${NC} ${CYAN}│${NC} ${BOLD}${GREEN}${padded_amount}${NC} ${CYAN}│${NC} ${YELLOW}⏳ Pending${NC} ${CYAN}│${NC}"
        else
            echo -e "  ${GRAY}│${NC}  ${DIM}${padded_idx}${NC} ${GRAY}│${NC} ${DIM}${padded_recipient}${NC} ${GRAY}│${NC} ${DIM}${padded_amount}${NC} ${GRAY}│${NC} ${GREEN}✅ Done${NC}    ${GRAY}│${NC}"
        fi
    else
        # Not selected
        if [ "$is_pending" = "true" ]; then
            echo -e "  ${GRAY}│${NC}  ${CYAN}${padded_idx}${NC} ${GRAY}│${NC} ${WHITE}${padded_recipient}${NC} ${GRAY}│${NC} ${GREEN}${padded_amount}${NC} ${GRAY}│${NC} ${YELLOW}⏳ Pending${NC} ${GRAY}│${NC}"
        else
            echo -e "  ${GRAY}│${NC}  ${DIM}${padded_idx}${NC} ${GRAY}│${NC} ${DIM}${padded_recipient}${NC} ${GRAY}│${NC} ${DIM}${padded_amount}${NC} ${GRAY}│${NC} ${GREEN}✅ Done${NC}    ${GRAY}│${NC}"
        fi
    fi
}

# Interactive deposit selector with arrow key navigation
select_deposit() {
    local local_mode="$1"
    local home_dir="$2"

    # Query all deposits
    query_all_deposits "$local_mode" "$home_dir"

    if [ ${#DEPOSIT_LIST[@]} -eq 0 ]; then
        echo -e "  ${RED}✗${NC} No deposits found on Base chain"
        exit 1
    fi

    # Build arrays for navigation
    local pending_indices=()
    local pending_count=0
    local processed_count=0

    for deposit in "${DEPOSIT_LIST[@]}"; do
        IFS='|' read -r idx recipient amount status <<< "$deposit"
        if [ "$status" = "pending" ]; then
            pending_indices+=("$idx")
            pending_count=$((pending_count + 1))
        else
            processed_count=$((processed_count + 1))
        fi
    done

    if [ $pending_count -eq 0 ]; then
        echo -e "  ${GREEN}🎉 All deposits have been processed!${NC}"
        echo ""
        exit 0
    fi

    # Current selection index (into pending_indices array)
    local current_selection=0
    local selected_deposit_idx="${pending_indices[$current_selection]}"

    # Function to draw the full table
    draw_table() {
        # Clear screen area (move cursor up and redraw)
        # Show header with stats
        echo -e "${PURPLE}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${PURPLE}│${NC}  ${BOLD}📋 Deposit Queue${NC}                                                       ${PURPLE}│${NC}"
        echo -e "${PURPLE}│${NC}  ${DIM}Found ${WHITE}${#DEPOSIT_LIST[@]}${DIM} deposits: ${YELLOW}${pending_count} pending${DIM}, ${GREEN}${processed_count} processed${NC}                      ${PURPLE}│${NC}"
        echo -e "${PURPLE}└─────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        # Table header
        echo -e "  ${GRAY}┌──────┬────────────────────────────────────────┬────────────────┬───────────┐${NC}"
        echo -e "  ${GRAY}│${NC} ${BOLD}#${NC}    ${GRAY}│${NC} ${BOLD}Recipient${NC}                              ${GRAY}│${NC} ${BOLD}Amount${NC}         ${GRAY}│${NC} ${BOLD}Status${NC}    ${GRAY}│${NC}"
        echo -e "  ${GRAY}├──────┼────────────────────────────────────────┼────────────────┼───────────┤${NC}"

        for deposit in "${DEPOSIT_LIST[@]}"; do
            IFS='|' read -r idx recipient amount status <<< "$deposit"
            local is_pending="false"
            local is_selected="false"

            if [ "$status" = "pending" ]; then
                is_pending="true"
            fi

            if [ "$idx" = "$selected_deposit_idx" ]; then
                is_selected="true"
            fi

            draw_deposit_row "$idx" "$recipient" "$amount" "$status" "$is_selected" "$is_pending"
        done

        echo -e "  ${GRAY}└──────┴────────────────────────────────────────┴────────────────┴───────────┘${NC}"
        echo ""
        echo -e "  ${DIM}Use ${WHITE}↑${DIM}/${WHITE}↓${DIM} arrows to select, ${WHITE}Enter${DIM} to confirm, ${WHITE}q${DIM} to quit${NC}"
        echo ""
        echo -ne "  ${CYAN}▶${NC} Deposit ${BOLD}#${selected_deposit_idx}${NC} selected "
    }

    # Draw initial table
    draw_table

    # Read input
    while true; do
        # Read a single character
        IFS= read -rsn1 key

        # Check for escape sequence (arrow keys)
        # macOS bash 3.x doesn't support decimal timeouts, so use -t 1
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 1 key2 2>/dev/null || true
            key+="$key2"
        fi

        case "$key" in
            $'\x1b[A'|'k')  # Up arrow or k
                if [ $current_selection -gt 0 ]; then
                    current_selection=$((current_selection - 1))
                    selected_deposit_idx="${pending_indices[$current_selection]}"
                fi
                ;;
            $'\x1b[B'|'j')  # Down arrow or j
                if [ $current_selection -lt $((pending_count - 1)) ]; then
                    current_selection=$((current_selection + 1))
                    selected_deposit_idx="${pending_indices[$current_selection]}"
                fi
                ;;
            ''|$'\n')  # Enter
                break
                ;;
            'q'|'Q')  # Quit
                echo ""
                echo ""
                echo -e "  ${DIM}Cancelled.${NC}"
                echo ""
                exit 0
                ;;
            [0-9])  # Direct number input
                # Read rest of number if any (for 2-digit numbers)
                local num="$key"
                read -rsn1 -t 1 more_digit 2>/dev/null || true
                if [[ "$more_digit" =~ [0-9] ]]; then
                    num+="$more_digit"
                fi

                # Check if this is a valid pending index
                for i in "${!pending_indices[@]}"; do
                    if [ "${pending_indices[$i]}" = "$num" ]; then
                        current_selection=$i
                        selected_deposit_idx="$num"
                        break 2  # Break out of both loops
                    fi
                done
                ;;
        esac

        # Redraw - clear lines and redraw table
        local lines_to_clear=$((${#DEPOSIT_LIST[@]} + 12))
        for ((i=0; i<lines_to_clear; i++)); do
            echo -ne "\033[A\033[K"  # Move up and clear line
        done
        draw_table
    done

    SELECTED_DEPOSIT_INDEX="$selected_deposit_idx"
    echo ""
    echo ""
    echo -e "  ${GREEN}✓${NC} Processing deposit ${BOLD}#${SELECTED_DEPOSIT_INDEX}${NC}..."
}

# Interactive network selector (compatible with bash 3.x on macOS)
select_network() {
    echo -e "${PURPLE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC}  ${BOLD}🌐 Select Network${NC}                      ${PURPLE}│${NC}"
    echo -e "${PURPLE}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC}  🤠  Texas Hodl    ${DIM}node.texashodl.net${NC}"
    echo -e "  ${CYAN}[2]${NC}  🎰  Block52       ${DIM}node1.block52.xyz${NC}"
    echo -e "  ${CYAN}[3]${NC}  💻  Local         ${DIM}localhost${NC}"
    echo -e "  ${CYAN}[4]${NC}  ⚙️   Custom        ${DIM}enter your own${NC}"
    echo ""

    local choice
    echo -ne "  ${WHITE}Enter choice ${CYAN}[1-4]${WHITE}:${NC} "
    read choice

    echo ""
    case "$choice" in
        1)
            VALIDATOR_HOST="node.texashodl.net"
            echo -e "  ${GREEN}✓${NC} Connected to ${BOLD}Texas Hodl${NC} ${DIM}(${VALIDATOR_HOST})${NC}"
            ;;
        2)
            VALIDATOR_HOST="node1.block52.xyz"
            echo -e "  ${GREEN}✓${NC} Connected to ${BOLD}Block52${NC} ${DIM}(${VALIDATOR_HOST})${NC}"
            ;;
        3)
            VALIDATOR_HOST="localhost"
            echo -e "  ${GREEN}✓${NC} Connected to ${BOLD}Local${NC} ${DIM}(${VALIDATOR_HOST})${NC}"
            ;;
        4)
            echo -ne "  ${WHITE}Enter hostname:${NC} "
            read VALIDATOR_HOST
            echo -e "  ${GREEN}✓${NC} Connected to ${BOLD}${VALIDATOR_HOST}${NC}"
            ;;
        *)
            echo -e "  ${YELLOW}⚠${NC} Invalid selection, using ${BOLD}Texas Hodl${NC}"
            VALIDATOR_HOST="node.texashodl.net"
            ;;
    esac
    echo ""
}

# Event signature for Deposited(string indexed account, uint256 amount, uint256 index)
# keccak256("Deposited(string,uint256,uint256)") = 0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2
DEPOSITED_EVENT_TOPIC="0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2"

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Box drawing characters
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_H="═"
BOX_V="║"

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${PURPLE}🌉${NC}  ${BOLD}${WHITE}Bridge Deposit Processor${NC}                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${DIM}Base Chain → Pokerchain USDC Bridge${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show usage
show_usage() {
    echo "Usage: $0 [deposit_index] [options]"
    echo ""
    echo "Arguments:"
    echo "  [deposit_index]        Deposit index to process (optional - interactive if omitted)"
    echo ""
    echo "Options:"
    echo "  --validator <host>     Validator host (prompts if not specified)"
    echo "  --user <user>          SSH user (default: root)"
    echo "  --from <keyname>       Key name to sign with (auto-detects from keyring)"
    echo "  --local                Run locally without SSH (for testing)"
    echo "  --home <path>          Home directory for local pokerchaind (default: ~/.pokerchain)"
    echo "  --dry-run              Show what would be done without executing"
    echo "  --debug                Show detailed debug information"
    echo "  --list-keys            List available keys on validator and exit"
    echo ""
    echo "Interactive Mode (recommended):"
    echo "  $0                                        # Select network, then choose from pending deposits"
    echo "  $0 --validator node.texashodl.net         # Skip network selection, show pending deposits"
    echo ""
    echo "Direct Mode:"
    echo "  $0 42                                     # Process deposit index 42 (prompts for network)"
    echo "  $0 42 --validator node.texashodl.net      # Process deposit 42 on specific validator"
    echo "  $0 42 --from validator                    # Use specific key name"
    echo "  $0 42 --dry-run                           # Test without executing"
    echo ""
    echo "Utilities:"
    echo "  $0 --list-keys                            # Show available keys on validator"
    echo ""
}

# List available keys
list_keys() {
    local local_mode="$1"
    local home_dir="$2"

    echo -e "${BLUE}Listing available keys on validator...${NC}"
    echo ""

    local key_info=""
    if [ "$local_mode" = "true" ]; then
        key_info=$(pokerchaind keys list --keyring-backend=test --output=json ${home_dir:+--home=$home_dir} 2>/dev/null)
    else
        key_info=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" "pokerchaind keys list --keyring-backend=test --output=json 2>/dev/null")
    fi

    if [ -n "$key_info" ] && [ "$key_info" != "[]" ] && [ "$key_info" != "null" ]; then
        echo "$key_info" | jq -r '.[] | "  \(.name): \(.address)"'
        echo ""
        echo -e "${GREEN}Use --from <keyname> to specify which key to use${NC}"
    else
        echo -e "${RED}No keys found or could not connect to validator${NC}"
        echo ""
        echo "Check:"
        echo "  1. SSH access to $VALIDATOR_USER@$VALIDATOR_HOST"
        echo "  2. pokerchaind is installed"
        echo "  3. Keyring has keys: pokerchaind keys add <name> --keyring-backend=test"
    fi
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
    
    echo -e "${BLUE}Querying deposit index ${deposit_index} from contract...${NC}" >&2
    
    # Function signature for deposits(uint256): keccak256("deposits(uint256)") = 0xb02c43d0
    local function_sig="0xb02c43d0"
    
    # Encode the index parameter (pad to 32 bytes)
    local index_hex=$(dec_to_hex "$deposit_index")
    local padded_index=$(pad_hex "$index_hex")
    
    # Construct the call data
    local call_data="${function_sig}${padded_index}"
    
    if [ "$debug" = "true" ]; then
        echo "" >&2
        echo "Debug Info:" >&2
        echo "  RPC URL: $ALCHEMY_URL" >&2
        echo "  Contract: $CONTRACT_ADDRESS" >&2
        echo "  Function: deposits(uint256)" >&2
        echo "  Deposit Index: $deposit_index" >&2
        echo "  Call Data: $call_data" >&2
        echo "" >&2
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
        echo "Request payload:" >&2
        echo "$payload" | jq '.' >&2
        echo "" >&2
    fi
    
    echo "Fetching deposit data from Base..." >&2
    local response=$(curl -s -X POST "$ALCHEMY_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$debug" = "true" ]; then
        echo "" >&2
        echo "Raw response:" >&2
        echo "$response" | jq '.' 2>/dev/null >&2 || echo "$response" >&2
        echo "" >&2
    fi
    
    # Check if response is valid
    if [ -z "$response" ]; then
        echo -e "${RED}❌ No response from Alchemy RPC${NC}" >&2
        return 1
    fi
    
    # Check for JSON-RPC error
    local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [ -n "$error" ]; then
        echo -e "${RED}❌ RPC Error: $error${NC}" >&2
        if [ "$debug" = "true" ]; then
            echo "$response" | jq '.error' >&2
        fi
        return 1
    fi
    
    # Get the result
    local result=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$result" = "null" ] || [ -z "$result" ] || [ "$result" = "0x" ]; then
        echo -e "${RED}❌ Deposit index $deposit_index not found${NC}" >&2
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
    # Syntax: pokerchaind tx poker process-deposit [index] [flags]
    # The keeper will query the contract using the index to get recipient and amount
    local cmd="pokerchaind tx poker process-deposit \
  $nonce \
  --from=$from_address \
  --chain-id=$CHAIN_ID \
  --gas=$GAS \
  --gas-prices=$GAS_PRICES \
  --yes"
    
    if [ "$local_mode" = "true" ] && [ -n "$home_dir" ]; then
        cmd="$cmd --home=$home_dir --keyring-backend=test"
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

$cmd --keyring-backend=test

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

# Check if deposit was already processed by index
check_if_processed() {
    local deposit_index="$1"
    local local_mode="$2"
    local home_dir="$3"
    
    echo -e "${BLUE}Checking if deposit index $deposit_index already processed...${NC}"
    
    # Generate the same deterministic txHash that the keeper uses
    # Format: sha256(contractAddress-depositIndex)
    local tx_hash_input="${CONTRACT_ADDRESS}-${deposit_index}"
    local eth_tx_hash="0x$(echo -n "$tx_hash_input" | sha256sum | cut -d' ' -f1)"
    
    echo "  Generated txHash: ${eth_tx_hash:0:20}..." >&2
    
    # Query if this txHash has been processed
    local query_result=""
    if [ "$local_mode" = "true" ]; then
        local query_cmd="pokerchaind query poker is-tx-processed --eth-tx-hash='$eth_tx_hash' --output json"
        if [ -n "$home_dir" ]; then
            query_cmd="$query_cmd --home '$home_dir'"
        fi
        query_result=$(eval $query_cmd 2>&1)
    else
        query_result=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" "pokerchaind query poker is-tx-processed --eth-tx-hash='$eth_tx_hash' --output json 2>&1")
    fi
    
    # Parse the JSON response
    local processed=$(echo "$query_result" | grep -o '"processed":\s*\(true\|false\)' | grep -o 'true\|false')
    
    if [ "$processed" = "true" ]; then
        echo -e "${RED}❌ Deposit index $deposit_index has already been processed!${NC}" >&2
        echo "" >&2
        echo "This deposit cannot be processed again." >&2
        echo "Transaction hash: $eth_tx_hash" >&2
        echo "" >&2
        return 1
    else
        echo -e "${GREEN}✓ Deposit not yet processed - safe to continue${NC}" >&2
        return 0
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
        if ! check_if_processed "$DEPOSIT_INDEX" "$local_mode" "$home_dir"; then
            echo -e "${RED}❌ Cannot process deposit - already processed${NC}"
            return 1
        fi
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
    # Check for help and list-keys flags first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_usage
            exit 0
        fi
        if [[ "$arg" == "--list-keys" ]]; then
            # Process remaining args for validator/local options, then list keys
            shift  # Remove first arg (might be deposit_index or --list-keys itself)
            local local_mode="false"
            local home_dir="$HOME/.pokerchain"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --validator) VALIDATOR_HOST="$2"; shift 2 ;;
                    --user) VALIDATOR_USER="$2"; shift 2 ;;
                    --local) local_mode="true"; shift ;;
                    --home) home_dir="$2"; shift 2 ;;
                    --list-keys) shift ;;  # Skip if we hit it again
                    *) shift ;;  # Skip unknown args
                esac
            done
            print_header
            # If no validator specified, prompt for network selection
            if [ -z "$VALIDATOR_HOST" ]; then
                select_network
            fi
            list_keys "$local_mode" "$home_dir"
            exit 0
        fi
    done

    # Check if first arg is a number (deposit index) or an option
    local deposit_index=""
    local interactive_mode="false"

    if [[ "$1" =~ ^[0-9]+$ ]]; then
        deposit_index="$1"
        shift
    else
        interactive_mode="true"
    fi

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
    
    print_header

    # If no validator specified, prompt for network selection
    if [ -z "$VALIDATOR_HOST" ]; then
        select_network
    fi

    # Auto-enable local mode if validator is localhost
    if [[ "$VALIDATOR_HOST" == "localhost" ]] || [[ "$VALIDATOR_HOST" == "127.0.0.1" ]]; then
        local_mode="true"
        echo -e "${BLUE}ℹ️  Auto-enabling local mode (validator is localhost)${NC}"
    fi

    # If interactive mode, show deposit selector
    if [ "$interactive_mode" = "true" ]; then
        select_deposit "$local_mode" "$home_dir"
        deposit_index="$SELECTED_DEPOSIT_INDEX"
    fi

    # Validate deposit index
    if ! [[ "$deposit_index" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Invalid deposit index. Must be a positive integer.${NC}"
        exit 1
    fi
    
    # Get from address if not provided
    if [ -z "$from_address" ]; then
        echo ""
        echo -e "${BLUE}Getting available keys from validator...${NC}"

        local key_info=""
        if [ "$local_mode" = "true" ]; then
            key_info=$(pokerchaind keys list --keyring-backend=test --output=json ${home_dir:+--home=$home_dir} 2>/dev/null)
        else
            key_info=$(ssh "$VALIDATOR_USER@$VALIDATOR_HOST" "pokerchaind keys list --keyring-backend=test --output=json 2>/dev/null")
        fi

        if [ -n "$key_info" ] && [ "$key_info" != "[]" ] && [ "$key_info" != "null" ]; then
            # Get first key with name and address
            local key_name=$(echo "$key_info" | jq -r '.[0].name // empty')
            local key_address=$(echo "$key_info" | jq -r '.[0].address // empty')
            local key_count=$(echo "$key_info" | jq -r 'length')

            if [ -n "$key_name" ]; then
                from_address="$key_name"
                echo -e "${GREEN}✓ Auto-detected key: $key_name${NC}"
                echo -e "  Address: $key_address"
                [ "$key_count" -gt 1 ] && echo -e "  (${key_count} keys available, using first)"
            else
                echo -e "${RED}❌ No keys found in validator keyring${NC}"
                echo ""
                echo "Please either:"
                echo "  1. Add a key to the validator: pokerchaind keys add <name> --keyring-backend=test"
                echo "  2. Specify a key with --from: ./process-bridge.sh $deposit_index --from <keyname>"
                exit 1
            fi
        else
            echo -e "${RED}❌ Could not list keys from validator${NC}"
            echo ""
            echo "SSH command failed or returned empty. Check:"
            echo "  1. SSH access to $VALIDATOR_USER@$VALIDATOR_HOST"
            echo "  2. pokerchaind is installed on validator"
            echo "  3. Keyring has at least one key"
            echo ""
            echo "Or specify a key manually with --from:"
            echo "  ./process-bridge.sh $deposit_index --from <keyname>"
            exit 1
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