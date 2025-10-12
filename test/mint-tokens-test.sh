#!/bin/bash

# mint-tokens-test.sh
# Script to mint tokens for testing

set -e

# Configuration
NODE_HOME="${HOME}/.pokerchain"
KEYRING_BACKEND="test"
CHAIN_ID="pokerchain"
NODE_URL="tcp://localhost:26657"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}💰 Pokerchain Token Minting Test${NC}"
echo "================================="

# Get parameters
AMOUNT="${1:-1000000}"
PLAYER_KEY="${2:-$(pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --output json | jq -r '.[0].name' 2>/dev/null)}"

if [ -z "$PLAYER_KEY" ] || [ "$PLAYER_KEY" = "null" ]; then
    echo -e "${RED}❌ No player key available${NC}"
    echo -e "${YELLOW}💡 Usage: $0 [amount] [player-key]${NC}"
    exit 1
fi

PLAYER_ADDRESS=$(pokerchaind keys show $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --address)

echo -e "${BLUE}👤 Player: $PLAYER_KEY${NC}"
echo -e "${BLUE}📍 Address: $PLAYER_ADDRESS${NC}"
echo -e "${BLUE}💰 Amount to mint: $AMOUNT stake${NC}"

# Check current balance
echo -e "${YELLOW}💵 Current balance:${NC}"
pokerchaind query bank balances $PLAYER_ADDRESS --node $NODE_URL

echo ""
echo -e "${YELLOW}🚀 Minting tokens...${NC}"

# Mint tokens
pokerchaind tx poker mint $AMOUNT \
    --from $PLAYER_KEY \
    --keyring-backend $KEYRING_BACKEND \
    --home $NODE_HOME \
    --chain-id $CHAIN_ID \
    --node $NODE_URL \
    --gas auto \
    --gas-adjustment 1.3 \
    --fees 100stake \
    --yes

echo ""
echo -e "${GREEN}✅ Mint transaction submitted!${NC}"
echo -e "${YELLOW}⏳ Waiting for transaction to process...${NC}"

sleep 3

echo -e "${YELLOW}💵 New balance:${NC}"
pokerchaind query bank balances $PLAYER_ADDRESS --node $NODE_URL