#!/bin/bash

# create-game-test.sh
# Script to test creating a poker game on the pokerchain

set -e

# Configuration
NODE_HOME="${HOME}/.pokerchain"
KEYRING_BACKEND="test"
CHAIN_ID="pokerchain"
NODE_URL="tcp://localhost:26657"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎲 Pokerchain Game Creation Test${NC}"
echo "================================="

# Check if node is running
echo -e "${YELLOW}📡 Checking if local node is running...${NC}"
if ! curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo -e "${RED}❌ Local node is not running on port 26657${NC}"
    echo -e "${YELLOW}💡 Please start the node first:${NC}"
    echo "   pokerchaind start --home ~/.pokerchain"
    exit 1
fi

echo -e "${GREEN}✅ Node is running${NC}"

# Check available keys
echo -e "${YELLOW}🔑 Checking available keys...${NC}"
pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME

# Get the first available key
PLAYER_KEY=$(pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --output json | jq -r '.[0].name' 2>/dev/null || echo "")

if [ -z "$PLAYER_KEY" ] || [ "$PLAYER_KEY" = "null" ]; then
    echo -e "${RED}❌ No keys found. Creating a test key...${NC}"
    PLAYER_KEY="test-player"
    pokerchaind keys add $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME
    echo -e "${GREEN}✅ Created test key: $PLAYER_KEY${NC}"
fi

# Get player address
PLAYER_ADDRESS=$(pokerchaind keys show $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --address)
echo -e "${BLUE}👤 Using player: $PLAYER_KEY${NC}"
echo -e "${BLUE}📍 Address: $PLAYER_ADDRESS${NC}"

# Check balance
echo -e "${YELLOW}💰 Checking balance...${NC}"
BALANCE=$(pokerchaind query bank balances $PLAYER_ADDRESS --node $NODE_URL --output json | jq -r '.balances[0].amount' 2>/dev/null || echo "0")
echo -e "${BLUE}💵 Balance: $BALANCE stake${NC}"

if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
    echo -e "${RED}❌ Insufficient balance. Need stake tokens to create games.${NC}"
    echo -e "${YELLOW}💡 You may need to:${NC}"
    echo "   1. Mint tokens: pokerchaind tx poker mint 1000000 --from $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --chain-id $CHAIN_ID --node $NODE_URL"
    echo "   2. Or transfer from another account"
    exit 1
fi

# Game parameters
GAME_ID="test-game-$(date +%s)"
BUY_IN="1000"
MAX_PLAYERS="6"
SMALL_BLIND="10"
BIG_BLIND="20"

echo ""
echo -e "${YELLOW}🎮 Creating poker game with parameters:${NC}"
echo -e "${BLUE}   Game ID: $GAME_ID${NC}"
echo -e "${BLUE}   Buy-in: $BUY_IN stake${NC}"
echo -e "${BLUE}   Max Players: $MAX_PLAYERS${NC}"
echo -e "${BLUE}   Small Blind: $SMALL_BLIND${NC}"
echo -e "${BLUE}   Big Blind: $BIG_BLIND${NC}"
echo ""

# Create the game
echo -e "${YELLOW}🚀 Submitting create-game transaction...${NC}"

CREATE_GAME_CMD="pokerchaind tx poker create-game \
    $GAME_ID \
    $BUY_IN \
    $MAX_PLAYERS \
    $SMALL_BLIND \
    $BIG_BLIND \
    --from $PLAYER_KEY \
    --keyring-backend $KEYRING_BACKEND \
    --home $NODE_HOME \
    --chain-id $CHAIN_ID \
    --node $NODE_URL \
    --gas auto \
    --gas-adjustment 1.3 \
    --fees 100stake \
    --yes"

echo -e "${BLUE}Command: $CREATE_GAME_CMD${NC}"
echo ""

if eval $CREATE_GAME_CMD; then
    echo ""
    echo -e "${GREEN}🎉 Game creation transaction submitted!${NC}"
    
    # Wait a moment for the transaction to be processed
    echo -e "${YELLOW}⏳ Waiting for transaction to be processed...${NC}"
    sleep 3
    
    # Query the game to verify it was created
    echo -e "${YELLOW}🔍 Querying game details...${NC}"
    if pokerchaind query poker game $GAME_ID --node $NODE_URL --output json; then
        echo ""
        echo -e "${GREEN}✅ Game created successfully!${NC}"
        echo -e "${BLUE}🎲 Game ID: $GAME_ID${NC}"
        echo ""
        echo -e "${YELLOW}🎮 Next steps:${NC}"
        echo "   1. Join the game: pokerchaind tx poker join-game $GAME_ID --from $PLAYER_KEY"
        echo "   2. List all games: pokerchaind query poker list-games"
        echo "   3. Check game status: pokerchaind query poker game $GAME_ID"
    else
        echo -e "${RED}❌ Game query failed. Game may not have been created properly.${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Game creation failed!${NC}"
    echo -e "${YELLOW}💡 Check the error message above for details.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Test completed!${NC}"