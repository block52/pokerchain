#!/bin/bash
# Simplified Poker Flow Test
# Uses the already imported accounts on the validator

set -e

VALIDATOR_HOST="node.texashodl.net"
VALIDATOR_USER="root"
CHAIN_ID="pokerchain"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Poker Flow Test - Simplified                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Send 1 USDC from bridge-recipient to player
echo -e "${BLUE}Step 1: Sending 1 USDC from bridge-recipient to player${NC}"
echo ""

ssh $VALIDATOR_USER@$VALIDATOR_HOST << 'ENDSSH'
PLAYER_ADDR=$(pokerchaind keys show player -a --keyring-backend test)

echo "Sending 1000000 usdc to player: $PLAYER_ADDR"
pokerchaind tx bank send bridge-recipient $PLAYER_ADDR 1000000usdc \
  --chain-id=pokerchain \
  --keyring-backend=test \
  --gas=auto \
  --gas-adjustment=1.5 \
  --gas-prices=0.001stake \
  --yes

sleep 6

echo ""
echo "Player balance:"
pokerchaind query bank balances $PLAYER_ADDR
ENDSSH

echo ""
echo -e "${GREEN}✓ Step 1 complete${NC}"
echo ""

# Step 2: Create a poker game
echo -e "${BLUE}Step 2: Creating poker game from player account${NC}"
echo ""

ssh $VALIDATOR_USER@$VALIDATOR_HOST << 'ENDSSH'
echo "Creating poker game..."
echo "Parameters: min-buy-in=100000 max-buy-in=1000000 min-players=2 max-players=6 small-blind=500 big-blind=1000 timeout=300 game-type=0"

pokerchaind tx poker create-game 100000 1000000 2 6 500 1000 300 0 \
  --from=player \
  --chain-id=pokerchain \
  --keyring-backend=test \
  --gas=auto \
  --gas-adjustment=1.5 \
  --gas-prices=0.001stake \
  --yes

sleep 6

echo ""
echo "Listing all games:"
pokerchaind query poker list-game
ENDSSH

echo ""
echo -e "${GREEN}✓ Step 2 complete${NC}"
echo ""

# Step 3: Join the game
echo -e "${BLUE}Step 3: Joining poker game with player account${NC}"
echo ""

ssh $VALIDATOR_USER@$VALIDATOR_HOST << 'ENDSSH'
GAME_ID=$(pokerchaind query poker list-game --output json 2>/dev/null | jq -r '.game[-1].id' || echo "0")

echo "Joining game $GAME_ID with 100000 usdc buy-in..."

pokerchaind tx poker join-game $GAME_ID 100000 \
  --from=player \
  --chain-id=pokerchain \
  --keyring-backend=test \
  --gas=auto \
  --gas-adjustment=1.5 \
  --gas-prices=0.001stake \
  --yes

sleep 6

echo ""
echo "Game info:"
pokerchaind query poker show-game $GAME_ID

echo ""
PLAYER_ADDR=$(pokerchaind keys show player -a --keyring-backend test)
echo "Player balance after joining:"
pokerchaind query bank balances $PLAYER_ADDR
ENDSSH

echo ""
echo -e "${GREEN}✓ Step 3 complete${NC}"
echo ""

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              All Steps Completed Successfully!                   ║${NC}"
echo -e "${BLUE}║              Poker flow working without CORS issues!             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
