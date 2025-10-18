#!/bin/bash

# demo-create-game-rest.sh
# Demonstration script showing the interactive node selection

echo "🎲 Pokerchain Game Creation Demo"
echo "==============================="
echo ""
echo "This script demonstrates the interactive node selection feature:"
echo ""

echo "Option 1 - Local node:"
echo "1" | ./create-game-rest-test.sh 2>/dev/null | head -10
echo ""

echo "Option 2 - Remote node (node1.block52.xyz):"
echo "2" | ./create-game-rest-test.sh 2>/dev/null | head -10
echo ""

echo "Option 3 - Custom URL:"
echo -e "3\nexample.com" | ./create-game-rest-test.sh 2>/dev/null | head -12
echo ""

echo "The script will:"
echo "✅ Ask for node configuration (localhost/remote/custom)"
echo "✅ Validate node and REST API connectivity"
echo "✅ Create transaction JSON locally"
echo "✅ Sign transaction with local keys"
echo "✅ Broadcast via REST API to selected node"
echo "✅ Verify game creation"
echo ""
echo "Usage: ./create-game-rest-test.sh"