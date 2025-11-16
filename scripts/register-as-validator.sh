#!/bin/bash

# Register as Validator in Vault Contract
# This script helps stake USDC in the Vault contract to become a validator for withdrawal signing

set -e

echo ""
echo "🏛️  Vault Validator Registration Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Contract addresses
VAULT_ADDRESS="0x893c26846d7cE76445230B2b6285a663BF4C3BF5"
USDC_ADDRESS="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
RPC_URL="https://mainnet.base.org"
MIN_STAKE="100000000"  # 100 USDC with 6 decimals

# Get private key from app.toml or prompt
if [ -f ~/.pokerchain-testnet/node1/config/app.toml ]; then
    PRIVATE_KEY=$(grep "^bridge_eth_private_key" ~/.pokerchain-testnet/node1/config/app.toml | cut -d'"' -f2)
    if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" == "PASTE_VALIDATOR_PRIVATE_KEY_HERE" ]; then
        echo "⚠️  No private key found in app.toml"
        read -sp "Enter your private key (without 0x prefix): " PRIVATE_KEY
        echo ""
    fi
else
    read -sp "Enter your private key (without 0x prefix): " PRIVATE_KEY
    echo ""
fi

# Add 0x prefix if not present
if [[ ! $PRIVATE_KEY == 0x* ]]; then
    PRIVATE_KEY="0x$PRIVATE_KEY"
fi

# Derive address
echo "🔑 Deriving address from private key..."
ADDRESS=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null || echo "")

if [ -z "$ADDRESS" ]; then
    echo "❌ Failed to derive address from private key"
    echo "   Make sure you have 'foundry' installed (cast command)"
    echo "   Install: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

echo "   Address: $ADDRESS"
echo ""

# Check current validator status
echo "📊 Checking current status..."
IS_VALIDATOR=$(cast call "$VAULT_ADDRESS" "isValidator(address)" "$ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "error")

if [ "$IS_VALIDATOR" == "error" ]; then
    echo "❌ Failed to query Vault contract"
    echo "   Make sure you have internet connection and RPC URL is correct"
    exit 1
fi

if [ "$IS_VALIDATOR" == "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "✅ Address is ALREADY a validator!"
    echo "   You can use this address for withdrawal signing"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

echo "   Status: NOT a validator"
echo ""

# Check USDC balance
echo "💰 Checking USDC balance..."
BALANCE=$(cast call "$USDC_ADDRESS" "balanceOf(address)" "$ADDRESS" --rpc-url "$RPC_URL")
BALANCE_DEC=$((16#${BALANCE:2}))  # Convert hex to decimal

echo "   USDC Balance: $(echo "scale=2; $BALANCE_DEC / 1000000" | bc) USDC"
echo "   Required: 100 USDC"
echo ""

if [ "$BALANCE_DEC" -lt "$MIN_STAKE" ]; then
    echo "❌ Insufficient USDC balance!"
    echo "   You need at least 100 USDC to become a validator"
    echo "   Current balance: $(echo "scale=2; $BALANCE_DEC / 1000000" | bc) USDC"
    echo ""
    echo "Get USDC on Base:"
    echo "  - Bridge from Ethereum: https://bridge.base.org"
    echo "  - Buy on exchange: Coinbase, Binance, etc."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi

echo "⚠️  IMPORTANT WARNINGS:"
echo "   1. You are about to stake 100 USDC on Base MAINNET"
echo "   2. Your USDC will be LOCKED for 365 days"
echo "   3. This is a REAL transaction with REAL money"
echo "   4. Make sure you understand the Vault contract before proceeding"
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Aborted by user"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/2: Approving Vault to spend USDC..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

APPROVE_TX=$(cast send "$USDC_ADDRESS" \
    "approve(address,uint256)" \
    "$VAULT_ADDRESS" \
    "$MIN_STAKE" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json)

APPROVE_HASH=$(echo "$APPROVE_TX" | jq -r '.transactionHash')
echo "✅ Approval transaction sent: $APPROVE_HASH"
echo "   Waiting for confirmation..."

cast receipt "$APPROVE_HASH" --rpc-url "$RPC_URL" > /dev/null
echo "✅ Approval confirmed!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/2: Staking 100 USDC in Vault..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

STAKE_TX=$(cast send "$VAULT_ADDRESS" \
    "stake(uint256)" \
    "$MIN_STAKE" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json)

STAKE_HASH=$(echo "$STAKE_TX" | jq -r '.transactionHash')
echo "✅ Stake transaction sent: $STAKE_HASH"
echo "   Waiting for confirmation..."

cast receipt "$STAKE_HASH" --rpc-url "$RPC_URL" > /dev/null
echo "✅ Stake confirmed!"
echo ""

# Verify validator status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Verifying validator status..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

IS_VALIDATOR_FINAL=$(cast call "$VAULT_ADDRESS" "isValidator(address)" "$ADDRESS" --rpc-url "$RPC_URL")

if [ "$IS_VALIDATOR_FINAL" == "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "🎉 SUCCESS! Address is now a validator!"
    echo ""
    echo "   Address: $ADDRESS"
    echo "   Staked: 100 USDC"
    echo "   Lock expires: $(date -d "+365 days" "+%Y-%m-%d")"
    echo ""
    echo "✅ You can now sign withdrawals with this address!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Make sure this private key is in app.toml as 'bridge_eth_private_key'"
    echo "   2. Restart pokerchaind if it's running"
    echo "   3. Test withdrawal flow in UI"
    echo ""
else
    echo "❌ Something went wrong - address is NOT a validator"
    echo "   Please check the transaction receipts and try again"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "View on Basescan:"
echo "  Approval: https://basescan.org/tx/$APPROVE_HASH"
echo "  Stake: https://basescan.org/tx/$STAKE_HASH"
echo "  Vault: https://basescan.org/address/$VAULT_ADDRESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
