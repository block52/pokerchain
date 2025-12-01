#!/bin/bash

# Add Validator to Running Network
# This script adds a new validator to an already running Pokerchain network
# It handles the create-validator transaction and stake transfer

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
CHAIN_ID="pokerchain"
DENOM="b52Token"
MIN_STAKE="100000000000"  # 100,000 b52Token (default minimum)

print_header() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "          🎲 Add Validator to Running Network 🎲"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Check if node is synced
check_node_sync() {
    local host=$1
    local user=$2

    echo "Checking if node is synced..."

    local catching_up=$(ssh "$user@$host" "curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up'" 2>/dev/null)

    if [ "$catching_up" = "true" ]; then
        echo -e "${YELLOW}⚠️  Node is still syncing. Wait for sync to complete before creating validator.${NC}"
        local latest_height=$(ssh "$user@$host" "curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'" 2>/dev/null)
        echo "   Current height: $latest_height"
        return 1
    elif [ "$catching_up" = "false" ]; then
        local latest_height=$(ssh "$user@$host" "curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'" 2>/dev/null)
        echo -e "${GREEN}✓${NC} Node is synced at height: $latest_height"
        return 0
    else
        echo -e "${YELLOW}⚠️  Could not determine sync status${NC}"
        return 1
    fi
}

# Get validator pubkey from node
get_validator_pubkey() {
    local host=$1
    local user=$2

    echo "Getting validator pubkey from node..."

    local pubkey=$(ssh "$user@$host" "pokerchaind comet show-validator" 2>/dev/null)

    if [ -z "$pubkey" ]; then
        echo -e "${RED}❌ Failed to get validator pubkey${NC}"
        return 1
    fi

    echo -e "${GREEN}✓${NC} Validator pubkey: $pubkey"
    echo "$pubkey"
}

# Check account balance
check_account_balance() {
    local host=$1
    local user=$2
    local address=$3

    echo "Checking account balance..."

    local balance=$(ssh "$user@$host" "pokerchaind query bank balances $address --output json 2>/dev/null | jq -r '.balances[] | select(.denom==\"$DENOM\") | .amount'" 2>/dev/null)

    if [ -z "$balance" ] || [ "$balance" = "null" ]; then
        balance="0"
    fi

    echo "   Account: $address"
    echo "   Balance: $balance $DENOM"

    echo "$balance"
}

# Transfer stake from existing validator
transfer_stake() {
    local source_host=$1
    local source_user=$2
    local source_account=$3
    local dest_address=$4
    local amount=$5

    echo ""
    echo -e "${BLUE}Transferring stake from existing validator...${NC}"
    echo "   From: $source_account on $source_host"
    echo "   To:   $dest_address"
    echo "   Amount: $amount $DENOM"
    echo ""

    # Execute transfer
    local result=$(ssh "$source_user@$source_host" "pokerchaind tx bank send $source_account $dest_address ${amount}${DENOM} \
        --chain-id=$CHAIN_ID \
        --gas=auto \
        --gas-adjustment=1.5 \
        --yes \
        --output json" 2>&1)

    local txhash=$(echo "$result" | jq -r '.txhash' 2>/dev/null)

    if [ -n "$txhash" ] && [ "$txhash" != "null" ]; then
        echo -e "${GREEN}✓${NC} Transfer submitted. TxHash: $txhash"
        echo "   Waiting for confirmation..."
        sleep 6

        # Verify the transfer
        local new_balance=$(ssh "$source_user@$source_host" "pokerchaind query bank balances $dest_address --output json 2>/dev/null | jq -r '.balances[] | select(.denom==\"$DENOM\") | .amount'" 2>/dev/null)
        echo "   New balance: ${new_balance:-0} $DENOM"
        return 0
    else
        echo -e "${RED}❌ Transfer failed${NC}"
        echo "$result"
        return 1
    fi
}

# Create validator transaction
create_validator() {
    local host=$1
    local user=$2
    local account_name=$3
    local moniker=$4
    local stake_amount=$5
    local commission_rate=$6
    local commission_max_rate=$7
    local commission_max_change=$8
    local min_self_delegation=$9
    local pubkey=${10}

    echo ""
    echo -e "${BLUE}Creating validator...${NC}"
    echo "   Moniker: $moniker"
    echo "   Account: $account_name"
    echo "   Stake:   $stake_amount $DENOM"
    echo "   Commission: $commission_rate (max: $commission_max_rate)"
    echo ""

    # Execute create-validator
    local result=$(ssh "$user@$host" "pokerchaind tx staking create-validator \
        --amount=${stake_amount}${DENOM} \
        --pubkey='$pubkey' \
        --moniker=\"$moniker\" \
        --commission-rate=\"$commission_rate\" \
        --commission-max-rate=\"$commission_max_rate\" \
        --commission-max-change-rate=\"$commission_max_change\" \
        --min-self-delegation=\"$min_self_delegation\" \
        --from=$account_name \
        --chain-id=$CHAIN_ID \
        --gas=auto \
        --gas-adjustment=1.5 \
        --yes \
        --output json" 2>&1)

    local txhash=$(echo "$result" | jq -r '.txhash' 2>/dev/null)

    if [ -n "$txhash" ] && [ "$txhash" != "null" ]; then
        echo -e "${GREEN}✓${NC} Validator creation submitted. TxHash: $txhash"
        echo "   Waiting for confirmation..."
        sleep 6
        return 0
    else
        echo -e "${RED}❌ Validator creation failed${NC}"
        echo "$result"
        return 1
    fi
}

# Verify validator is in active set
verify_validator() {
    local host=$1
    local user=$2
    local validator_address=$3

    echo ""
    echo "Verifying validator status..."

    local validator_info=$(ssh "$user@$host" "pokerchaind query staking validator $validator_address --output json 2>/dev/null" 2>/dev/null)

    if [ -n "$validator_info" ]; then
        local status=$(echo "$validator_info" | jq -r '.status')
        local tokens=$(echo "$validator_info" | jq -r '.tokens')
        local moniker=$(echo "$validator_info" | jq -r '.description.moniker')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}Validator Created Successfully!${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "   Moniker:  $moniker"
        echo "   Address:  $validator_address"
        echo "   Status:   $status"
        echo "   Tokens:   $tokens"
        echo ""

        if [ "$status" = "BOND_STATUS_BONDED" ]; then
            echo -e "${GREEN}✓ Validator is BONDED and actively producing blocks!${NC}"
        elif [ "$status" = "BOND_STATUS_UNBONDING" ]; then
            echo -e "${YELLOW}⚠️  Validator is UNBONDING${NC}"
        else
            echo -e "${YELLOW}⚠️  Validator status: $status${NC}"
            echo "   The validator may need more stake to enter the active set."
        fi

        return 0
    else
        echo -e "${YELLOW}⚠️  Could not query validator. It may take a moment to appear.${NC}"
        return 1
    fi
}

# Main interactive flow
main() {
    print_header

    echo "This script adds a new validator to a running Pokerchain network."
    echo ""
    echo "Prerequisites:"
    echo "  1. The new validator node must be synced to the network"
    echo "  2. The node must have a validator key (priv_validator_key.json)"
    echo "  3. An account key must exist on the node to sign transactions"
    echo "  4. The account must have sufficient stake tokens"
    echo ""

    # Step 1: Get new validator node details
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: New Validator Node Details${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "New validator host (e.g., node1.block52.xyz): " NEW_HOST
    if [ -z "$NEW_HOST" ]; then
        echo -e "${RED}❌ Host cannot be empty${NC}"
        exit 1
    fi

    read -p "SSH user (default: root): " NEW_USER
    NEW_USER=${NEW_USER:-root}

    # Test SSH connection
    echo ""
    echo "Testing SSH connection to $NEW_HOST..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$NEW_USER@$NEW_HOST" "echo 'SSH OK'" 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to $NEW_USER@$NEW_HOST${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} SSH connection successful"

    # Check sync status
    echo ""
    if ! check_node_sync "$NEW_HOST" "$NEW_USER"; then
        read -p "Node is not synced. Continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Exiting. Please wait for node to sync."
            exit 1
        fi
    fi

    # Get validator pubkey
    echo ""
    VALIDATOR_PUBKEY=$(ssh "$NEW_USER@$NEW_HOST" "pokerchaind comet show-validator" 2>/dev/null)
    if [ -z "$VALIDATOR_PUBKEY" ]; then
        echo -e "${RED}❌ Could not get validator pubkey${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Validator pubkey obtained"
    echo "   $VALIDATOR_PUBKEY"

    # Step 2: Account setup
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Account Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # List existing accounts
    echo "Existing accounts on $NEW_HOST:"
    ssh "$NEW_USER@$NEW_HOST" "pokerchaind keys list --output json 2>/dev/null | jq -r '.[] | \"  \" + .name + \" (\" + .address + \")\"'" 2>/dev/null || echo "  (none found)"
    echo ""

    read -p "Account name to use for validator (or 'new' to create): " ACCOUNT_NAME

    if [ "$ACCOUNT_NAME" = "new" ]; then
        read -p "Enter name for new account: " ACCOUNT_NAME

        echo ""
        echo "Choose key import method:"
        echo "  1) Generate new key"
        echo "  2) Import from mnemonic"
        read -p "Choice [1-2]: " key_method

        if [ "$key_method" = "2" ]; then
            read -p "Enter mnemonic phrase: " mnemonic
            echo "$mnemonic" | ssh "$NEW_USER@$NEW_HOST" "pokerchaind keys add $ACCOUNT_NAME --recover --keyring-backend test"
        else
            # Generate new key and show mnemonic
            ssh "$NEW_USER@$NEW_HOST" "pokerchaind keys add $ACCOUNT_NAME --keyring-backend test"
        fi
    fi

    # Get account address
    ACCOUNT_ADDRESS=$(ssh "$NEW_USER@$NEW_HOST" "pokerchaind keys show $ACCOUNT_NAME -a --keyring-backend test" 2>/dev/null)
    if [ -z "$ACCOUNT_ADDRESS" ]; then
        echo -e "${RED}❌ Could not get account address${NC}"
        exit 1
    fi
    echo ""
    echo -e "${GREEN}✓${NC} Using account: $ACCOUNT_NAME ($ACCOUNT_ADDRESS)"

    # Check balance
    echo ""
    CURRENT_BALANCE=$(ssh "$NEW_USER@$NEW_HOST" "pokerchaind query bank balances $ACCOUNT_ADDRESS --output json 2>/dev/null | jq -r '.balances[] | select(.denom==\"$DENOM\") | .amount'" 2>/dev/null)
    CURRENT_BALANCE=${CURRENT_BALANCE:-0}
    echo "Current balance: $CURRENT_BALANCE $DENOM"

    # Step 3: Stake tokens
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Stake Tokens${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "Amount to stake (default: $MIN_STAKE): " STAKE_AMOUNT
    STAKE_AMOUNT=${STAKE_AMOUNT:-$MIN_STAKE}

    # Check if we need to transfer stake
    if [ "$CURRENT_BALANCE" -lt "$STAKE_AMOUNT" ] 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}⚠️  Insufficient balance. Need ${STAKE_AMOUNT} but have ${CURRENT_BALANCE}${NC}"
        echo ""
        echo "Would you like to transfer stake from an existing validator?"
        echo "  1) Yes - Transfer from existing validator"
        echo "  2) No - I'll fund the account manually"
        read -p "Choice [1-2]: " transfer_choice

        if [ "$transfer_choice" = "1" ]; then
            echo ""
            read -p "Source validator host (e.g., node.texashodl.net): " SOURCE_HOST
            read -p "SSH user for source (default: root): " SOURCE_USER
            SOURCE_USER=${SOURCE_USER:-root}

            # List accounts on source
            echo ""
            echo "Available accounts on $SOURCE_HOST:"
            ssh "$SOURCE_USER@$SOURCE_HOST" "pokerchaind keys list --output json 2>/dev/null | jq -r '.[] | \"  \" + .name + \" (\" + .address + \")\"'" 2>/dev/null
            echo ""

            read -p "Source account name: " SOURCE_ACCOUNT

            TRANSFER_AMOUNT=$((STAKE_AMOUNT - CURRENT_BALANCE + 1000000))  # Add some for gas
            echo "Transferring $TRANSFER_AMOUNT $DENOM..."

            if transfer_stake "$SOURCE_HOST" "$SOURCE_USER" "$SOURCE_ACCOUNT" "$ACCOUNT_ADDRESS" "$TRANSFER_AMOUNT"; then
                echo -e "${GREEN}✓${NC} Transfer complete"
            else
                echo -e "${RED}❌ Transfer failed${NC}"
                exit 1
            fi
        else
            echo ""
            echo "Please fund the account with at least ${STAKE_AMOUNT} ${DENOM} and run this script again."
            echo "Account address: $ACCOUNT_ADDRESS"
            exit 0
        fi
    fi

    # Step 4: Validator configuration
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Validator Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "Validator moniker (default: validator-$(hostname)): " MONIKER
    MONIKER=${MONIKER:-"validator-$(hostname)"}

    read -p "Commission rate (default: 0.10): " COMMISSION_RATE
    COMMISSION_RATE=${COMMISSION_RATE:-0.10}

    read -p "Commission max rate (default: 0.20): " COMMISSION_MAX_RATE
    COMMISSION_MAX_RATE=${COMMISSION_MAX_RATE:-0.20}

    read -p "Commission max change rate (default: 0.01): " COMMISSION_MAX_CHANGE
    COMMISSION_MAX_CHANGE=${COMMISSION_MAX_CHANGE:-0.01}

    read -p "Minimum self-delegation (default: 1): " MIN_SELF_DELEGATION
    MIN_SELF_DELEGATION=${MIN_SELF_DELEGATION:-1}

    # Confirmation
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Review Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   New Validator Host: $NEW_HOST"
    echo "   Moniker:           $MONIKER"
    echo "   Account:           $ACCOUNT_NAME ($ACCOUNT_ADDRESS)"
    echo "   Stake Amount:      $STAKE_AMOUNT $DENOM"
    echo "   Commission:        $COMMISSION_RATE (max: $COMMISSION_MAX_RATE)"
    echo "   Min Self Delegation: $MIN_SELF_DELEGATION"
    echo ""
    read -p "Create validator with these settings? (y/n): " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # Step 5: Create validator
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Creating Validator${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if create_validator "$NEW_HOST" "$NEW_USER" "$ACCOUNT_NAME" "$MONIKER" "$STAKE_AMOUNT" \
        "$COMMISSION_RATE" "$COMMISSION_MAX_RATE" "$COMMISSION_MAX_CHANGE" "$MIN_SELF_DELEGATION" "$VALIDATOR_PUBKEY"; then

        # Get validator address and verify
        VALIDATOR_ADDR=$(ssh "$NEW_USER@$NEW_HOST" "pokerchaind keys show $ACCOUNT_NAME --bech val -a --keyring-backend test" 2>/dev/null)
        verify_validator "$NEW_HOST" "$NEW_USER" "$VALIDATOR_ADDR"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Useful Commands:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Check validator status:"
        echo "  ssh $NEW_USER@$NEW_HOST 'pokerchaind query staking validator $VALIDATOR_ADDR'"
        echo ""
        echo "View all validators:"
        echo "  pokerchaind query staking validators"
        echo ""
        echo "Monitor node logs:"
        echo "  ssh $NEW_USER@$NEW_HOST 'journalctl -u pokerchaind -f'"
        echo ""
    else
        echo -e "${RED}❌ Failed to create validator${NC}"
        exit 1
    fi
}

# Run main
main "$@"
