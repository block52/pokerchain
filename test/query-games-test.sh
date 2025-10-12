#!/bin/bash

# query-games-test.sh
# Script to query and display poker games

set -e

# Configuration
NODE_URL="tcp://localhost:26657"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎲 Pokerchain Games Query${NC}"
echo "========================="

# Check if node is running
if ! curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo -e "${RED}❌ Local node is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Querying all games...${NC}"
echo ""

# List all games
GAMES_JSON=$(pokerchaind query poker list-games --node $NODE_URL --output json 2>/dev/null || echo '{"games":[]}')

if [ "$(echo $GAMES_JSON | jq -r '.games | length')" = "0" ]; then
    echo -e "${YELLOW}📭 No games found${NC}"
    exit 0
fi

echo -e "${GREEN}🎮 Found Games:${NC}"
echo "==============="

# Parse and display each game
echo $GAMES_JSON | jq -r '.games[] | @json' | while read game; do
    GAME_ID=$(echo $game | jq -r '.id')
    BUY_IN=$(echo $game | jq -r '.buy_in')
    MAX_PLAYERS=$(echo $game | jq -r '.max_players')
    CURRENT_PLAYERS=$(echo $game | jq -r '.players | length')
    STATUS=$(echo $game | jq -r '.status // "unknown"')
    CREATOR=$(echo $game | jq -r '.creator')
    
    echo ""
    echo -e "${BLUE}🎲 Game: $GAME_ID${NC}"
    echo -e "${YELLOW}   Creator: $CREATOR${NC}"
    echo -e "${YELLOW}   Status: $STATUS${NC}"
    echo -e "${YELLOW}   Buy-in: $BUY_IN stake${NC}"
    echo -e "${YELLOW}   Players: $CURRENT_PLAYERS/$MAX_PLAYERS${NC}"
    
    if [ "$CURRENT_PLAYERS" -gt "0" ]; then
        echo -e "${YELLOW}   Player List:${NC}"
        echo $game | jq -r '.players[]?' | while read player; do
            echo -e "${BLUE}     - $player${NC}"
        done
    fi
done

echo ""
echo -e "${GREEN}✅ Query completed${NC}"

# Show specific game if requested
if [ -n "$1" ]; then
    echo ""
    echo -e "${YELLOW}🔍 Detailed view of game: $1${NC}"
    echo "================================"
    pokerchaind query poker game $1 --node $NODE_URL --output json | jq '.'
fi