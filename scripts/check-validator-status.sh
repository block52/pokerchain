#!/bin/bash

# Check Validator Status in Vault Contract
# Quick script to check if an address is registered as a validator

set -e

echo ""
echo "🔍 Validator Status Checker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Contract addresses
VAULT_ADDRESS="0x893c26846d7cE76445230B2b6285a663BF4C3BF5"
USDC_ADDRESS="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
RPC_URL="https://mainnet.base.org"

# Check if address was provided as argument
if [ -n "$1" ]; then
    ADDRESS="$1"
else
    # Try to get from app.toml
    if [ -f ~/.pokerchain-testnet/node1/config/app.toml ]; then
        PRIVATE_KEY=$(grep "^bridge_eth_private_key" ~/.pokerchain-testnet/node1/config/app.toml | cut -d'"' -f2)
        if [ -n "$PRIVATE_KEY" ] && [ "$PRIVATE_KEY" != "PASTE_VALIDATOR_PRIVATE_KEY_HERE" ]; then
            if [[ ! $PRIVATE_KEY == 0x* ]]; then
                PRIVATE_KEY="0x$PRIVATE_KEY"
            fi
            ADDRESS=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null || echo "")
        fi
    fi

    # If still no address, prompt
    if [ -z "$ADDRESS" ]; then
        echo "Usage: $0 [address]"
        echo ""
        read -p "Enter address to check (0x...): " ADDRESS
    fi
fi

# Validate address format
if [[ ! $ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "❌ Invalid Ethereum address format"
    echo "   Expected: 0x followed by 40 hex characters"
    exit 1
fi

echo "📍 Address: $ADDRESS"
echo ""

# Check validator status
echo "🔍 Querying Vault contract..."
IS_VALIDATOR=$(cast call "$VAULT_ADDRESS" "isValidator(address)" "$ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "error")

if [ "$IS_VALIDATOR" == "error" ]; then
    echo "❌ Failed to query Vault contract"
    echo "   Make sure you have internet connection"
    echo "   Install foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

# Check stake balance
STAKE_BALANCE=$(cast call "$VAULT_ADDRESS" "balanceOf(address)" "$ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
STAKE_DEC=$((16#${STAKE_BALANCE:2}))

# Check USDC balance
USDC_BALANCE=$(cast call "$USDC_ADDRESS" "balanceOf(address)" "$ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
USDC_DEC=$((16#${USDC_BALANCE:2}))

# Get vault config
MIN_STAKE=$(cast call "$VAULT_ADDRESS" "minValidatorStake()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
MIN_STAKE_DEC=$((16#${MIN_STAKE:2}))

VALIDATOR_COUNT=$(cast call "$VAULT_ADDRESS" "validatorCount()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
VALIDATOR_COUNT_DEC=$((16#${VALIDATOR_COUNT:2}))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$IS_VALIDATOR" == "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "✅ IS VALIDATOR: Yes"
else
    echo "❌ IS VALIDATOR: No"
fi

echo ""
echo "💰 Balances:"
echo "   Staked in Vault: $(echo "scale=2; $STAKE_DEC / 1000000" | bc) USDC"
echo "   USDC in Wallet: $(echo "scale=2; $USDC_DEC / 1000000" | bc) USDC"
echo ""
echo "📊 Vault Info:"
echo "   Minimum Stake Required: $(echo "scale=2; $MIN_STAKE_DEC / 1000000" | bc) USDC"
echo "   Total Validators: $VALIDATOR_COUNT_DEC"
echo ""

if [ "$IS_VALIDATOR" != "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    if [ "$STAKE_DEC" -ge "$MIN_STAKE_DEC" ]; then
        echo "⚠️  You have enough stake but are NOT a validator!"
        echo "   This shouldn't happen - please check the contract"
    else
        NEEDED=$((MIN_STAKE_DEC - STAKE_DEC))
        echo "ℹ️  To become a validator:"
        echo "   Need to stake: $(echo "scale=2; $NEEDED / 1000000" | bc) more USDC"
        echo ""
        if [ "$USDC_DEC" -ge "$MIN_STAKE_DEC" ]; then
            echo "✅ You have enough USDC in your wallet!"
            echo "   Run: ./scripts/register-as-validator.sh"
        else
            echo "❌ Not enough USDC in wallet"
            echo "   Get USDC on Base: https://bridge.base.org"
        fi
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Contract Links:"
echo "  Vault: https://basescan.org/address/$VAULT_ADDRESS"
echo "  USDC: https://basescan.org/address/$USDC_ADDRESS"
echo "  Your Address: https://basescan.org/address/$ADDRESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
