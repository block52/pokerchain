#!/bin/bash

# join-game-test.sh
# Script to test joining a poker game

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

echo -e "${BLUE}🎲 Pokerchain Join Game Test${NC}"
echo "============================="

# Check if game ID is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}📋 Usage: $0 <game-id> [player-key]${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Available games:${NC}"
    pokerchaind query poker list-games --node $NODE_URL --output json | jq -r '.games[].id' 2>/dev/null || echo "No games found"
    exit 1
fi

GAME_ID="$1"
PLAYER_KEY="${2:-$(pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --output json | jq -r '.[0].name' 2>/dev/null)}"

if [ -z "$PLAYER_KEY" ] || [ "$PLAYER_KEY" = "null" ]; then
    echo -e "${RED}❌ No player key available${NC}"
    exit 1
fi

PLAYER_ADDRESS=$(pokerchaind keys show $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --address)
echo -e "${BLUE}👤 Player: $PLAYER_KEY ($PLAYER_ADDRESS)${NC}"
echo -e "${BLUE}🎮 Game ID: $GAME_ID${NC}"

# Check game exists
echo -e "${YELLOW}🔍 Checking game status...${NC}"
if ! pokerchaind query poker game $GAME_ID --node $NODE_URL > /dev/null 2>&1; then
    echo -e "${RED}❌ Game $GAME_ID not found${NC}"
    exit 1
fi

# Join the game
echo -e "${YELLOW}🚀 Joining game...${NC}"
pokerchaind tx poker join-game $GAME_ID \
    --from $PLAYER_KEY \
    --keyring-backend $KEYRING_BACKEND \
    --home $NODE_HOME \
    --chain-id $CHAIN_ID \
    --node $NODE_URL \
    --gas auto \
    --gas-adjustment 1.3 \
    --fees 100stake \
    --yes

echo -e "${GREEN}✅ Join game transaction submitted!${NC}"