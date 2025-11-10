#!/bin/bash

# Mint tokens by calling the MsgMint transaction
# Usage: ./mint-tokens.sh <eth-tx-hash> <amount>

set -e

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <eth-tx-hash> <amount>"
    echo "Example: $0 0x1234...abcd 1000000"
    exit 1
fi

ETH_TX_HASH=$1
AMOUNT=$2
NONCE=0
RECIPIENT="b52168ketml7jed9gl7t2quelfkktr0zuuescapgde"

# Get the creator address (first key in keyring)
CREATOR=$(./pokerchaind keys list --output json | jq -r '.[0].address')

if [ -z "$CREATOR" ]; then
    echo "Error: No keys found. Please create a key first with: pokerchaind keys add <name>"
    exit 1
fi

echo "==================================="
echo "Minting Tokens"
echo "==================================="
echo "Creator: $CREATOR"
echo "Recipient: $RECIPIENT"
echo "Amount: $AMOUNT"
echo "Eth Tx Hash: $ETH_TX_HASH"
echo "Nonce: $NONCE"
echo "==================================="
echo ""

# Execute the mint transaction
./pokerchaind tx poker mint \
  "$RECIPIENT" \
  "$AMOUNT" \
  "$ETH_TX_HASH" \
  "$NONCE" \
  --from "$CREATOR" \
  --chain-id localchain \
  --keyring-backend test \
  --yes

echo ""
echo "✅ Mint transaction submitted!"
echo ""
echo "Check the transaction with:"
echo "./pokerchaind query tx <TX_HASH>"
