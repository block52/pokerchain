#!/bin/bash

# Export Bridge State from Cosmos Chain
# Extracts bridge-related state (ProcessedEthTxs, withdrawal_requests, etc.) from genesis

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default paths
GENESIS_PATH="${1:-$HOME/.pokerchain/config/genesis.json}"
OUTPUT_PATH="${2:-/tmp/bridge-state.json}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}        💾 Export Bridge State from Genesis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Error: jq is required but not installed${NC}"
    echo ""
    echo "Install jq:"
    echo "  macOS:  brew install jq"
    echo "  Ubuntu: sudo apt-get install jq"
    echo ""
    exit 1
fi

# Check if genesis file exists
if [ ! -f "$GENESIS_PATH" ]; then
    echo -e "${RED}❌ Error: Genesis file not found: $GENESIS_PATH${NC}"
    echo ""
    echo "Usage: $0 [genesis_path] [output_path]"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 ~/.pokerchain/config/genesis.json /tmp/bridge-state.json"
    echo "  $0 ./genesis.json ./bridge-backup.json"
    echo ""
    exit 1
fi

echo "📖 Reading genesis from: $GENESIS_PATH"
echo "💾 Exporting bridge state to: $OUTPUT_PATH"
echo ""

# Validate genesis file is valid JSON
if ! jq empty "$GENESIS_PATH" 2>/dev/null; then
    echo -e "${RED}❌ Error: Genesis file is not valid JSON${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Genesis file is valid JSON${NC}"
echo ""

# Extract bridge state fields
echo "🔍 Extracting bridge state fields..."
echo ""

# Check if poker module exists in genesis
if ! jq -e '.app_state.poker' "$GENESIS_PATH" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning: Poker module not found in genesis${NC}"
    echo "Creating empty bridge state..."
    echo '{"processed_eth_txs": [], "withdrawal_requests": [], "params": {}}' > "$OUTPUT_PATH"
    echo ""
    echo -e "${GREEN}✅ Empty bridge state created${NC}"
    exit 0
fi

# Extract bridge-specific fields from poker module
jq '{
  processed_eth_txs: (.app_state.poker.processed_eth_txs // []),
  withdrawal_requests: (.app_state.poker.withdrawal_requests // []),
  withdrawal_nonce: (.app_state.poker.withdrawal_nonce // "0"),
  params: .app_state.poker.params
}' "$GENESIS_PATH" > "$OUTPUT_PATH"

# Validate output
if ! jq empty "$OUTPUT_PATH" 2>/dev/null; then
    echo -e "${RED}❌ Error: Failed to create valid bridge state JSON${NC}"
    exit 1
fi

# Display summary
echo -e "${GREEN}✅ Bridge state exported successfully!${NC}"
echo ""
echo "Bridge State Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count processed transactions
PROCESSED_TX_COUNT=$(jq '.processed_eth_txs | length' "$OUTPUT_PATH" 2>/dev/null || echo "0")
echo "  Processed Ethereum TXs: $PROCESSED_TX_COUNT"

# Count withdrawal requests
WITHDRAWAL_COUNT=$(jq '.withdrawal_requests | length' "$OUTPUT_PATH" 2>/dev/null || echo "0")
echo "  Withdrawal Requests: $WITHDRAWAL_COUNT"

# Show withdrawal nonce
WITHDRAWAL_NONCE=$(jq -r '.withdrawal_nonce // "0"' "$OUTPUT_PATH" 2>/dev/null)
echo "  Withdrawal Nonce: $WITHDRAWAL_NONCE"

echo ""
echo "📁 Bridge state saved to: $OUTPUT_PATH"
echo ""

# Show sample if data exists
if [ "$PROCESSED_TX_COUNT" -gt 0 ] || [ "$WITHDRAWAL_COUNT" -gt 0 ]; then
    echo "Sample data:"
    jq '.' "$OUTPUT_PATH" | head -20
    if [ $(wc -l < "$OUTPUT_PATH") -gt 20 ]; then
        echo "  ... (truncated)"
    fi
fi

echo ""
echo -e "${GREEN}✅ Export complete!${NC}"
echo ""
