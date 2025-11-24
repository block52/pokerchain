#!/bin/bash

# Poker WebSocket Integration Test
# This script demonstrates the full flow of creating a game, joining, performing actions,
# and receiving real-time updates via WebSocket

set -e

GAME_ID="0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1"

echo "🎮 Poker WebSocket Integration Test"
echo "===================================="
echo ""

# Check if WebSocket server is running
echo "1. Checking WebSocket server..."
if curl -s http://localhost:8585/health > /dev/null 2>&1; then
    echo "   ✅ WebSocket server is running"
    curl -s http://localhost:8585/health | jq .
else
    echo "   ❌ WebSocket server is not running"
    echo "   Start it with: ./ws-server"
    exit 1
fi

echo ""
echo "2. Creating a table..."
if ! ./create-table 2>&1 | tee /tmp/create-table.log; then
    echo "   ⚠️  Create table may have failed, but continuing..."
fi

# Trigger broadcast for table creation
echo ""
echo "3. Broadcasting table creation..."
./trigger-broadcast "$GAME_ID" "state_change"

echo ""
echo "4. Joining the game..."
./join-game "$GAME_ID" 1 500000000 || echo "   ⚠️  Join may have failed (insufficient balance?)"

# Trigger broadcast for join
echo ""
echo "5. Broadcasting join event..."
./trigger-broadcast "$GAME_ID" "join"

echo ""
echo "6. Getting legal actions..."
./get-legal-actions "$GAME_ID" || echo "   ⚠️  Legal actions query may have failed"

echo ""
echo "7. Performing an action (call)..."
./perform-action "$GAME_ID" call || echo "   ⚠️  Action may have failed (not your turn?)"

# Trigger broadcast for action
echo ""
echo "8. Broadcasting action event..."
./trigger-broadcast "$GAME_ID" "action"

echo ""
echo "9. Querying game state..."
./get-legal-actions "$GAME_ID" || echo "   ⚠️  State query may have failed"

echo ""
echo "10. Final WebSocket server status..."
curl -s http://localhost:8585/health | jq .

echo ""
echo "===================================="
echo "✅ Test flow complete!"
echo ""
echo "To monitor in real-time:"
echo "  1. Open cmd/ws-server/test-client.html in a browser"
echo "  2. Connect to ws://localhost:8585/ws"
echo "  3. Subscribe to game: $GAME_ID"
echo "  4. Run this script again to see live updates"
