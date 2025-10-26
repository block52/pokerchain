#!/bin/bash
# Test script for querying the next player to act

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Check if game ID is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <game_id>"
    echo "Example: $0 game-123"
    exit 1
fi

GAME_ID=$1

print_info "Querying next player to act for game: $GAME_ID"
echo ""

# Query using CLI
pokerchaind query poker next-player-to-act "$GAME_ID" --output json | jq .

echo ""
print_success "Query completed"

# Also show REST API endpoint
print_info "REST API endpoint:"
echo "  http://localhost:1317/block52/pokerchain/poker/v1/next_player_to_act/$GAME_ID"
echo ""
echo "Try: curl http://localhost:1317/block52/pokerchain/poker/v1/next_player_to_act/$GAME_ID | jq ."
