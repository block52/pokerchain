#!/bin/bash

# Import Bridge State into Cosmos Genesis
# Merges bridge-related state back into genesis.json

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default paths
GENESIS_PATH="${1:-$HOME/.pokerchain/config/genesis.json}"
BRIDGE_STATE_PATH="${2:-/tmp/bridge-state.json}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}        📥 Import Bridge State into Genesis${NC}"
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

# Check if files exist
if [ ! -f "$GENESIS_PATH" ]; then
    echo -e "${RED}❌ Error: Genesis file not found: $GENESIS_PATH${NC}"
    exit 1
fi

if [ ! -f "$BRIDGE_STATE_PATH" ]; then
    echo -e "${RED}❌ Error: Bridge state file not found: $BRIDGE_STATE_PATH${NC}"
    exit 1
fi

echo "📖 Target genesis: $GENESIS_PATH"
echo "💾 Bridge state: $BRIDGE_STATE_PATH"
echo ""

# Validate both files are valid JSON
if ! jq empty "$GENESIS_PATH" 2>/dev/null; then
    echo -e "${RED}❌ Error: Genesis file is not valid JSON${NC}"
    exit 1
fi

if ! jq empty "$BRIDGE_STATE_PATH" 2>/dev/null; then
    echo -e "${RED}❌ Error: Bridge state file is not valid JSON${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Both files are valid JSON${NC}"
echo ""

# Backup original genesis
BACKUP_PATH="${GENESIS_PATH}.pre-import-backup"
echo "📋 Creating backup: $BACKUP_PATH"
cp "$GENESIS_PATH" "$BACKUP_PATH"
echo -e "${GREEN}✅ Backup created${NC}"
echo ""

# Display what will be imported
echo "Bridge State to Import:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROCESSED_TX_COUNT=$(jq '.processed_eth_txs | length' "$BRIDGE_STATE_PATH" 2>/dev/null || echo "0")
echo "  Processed Ethereum TXs: $PROCESSED_TX_COUNT"

WITHDRAWAL_COUNT=$(jq '.withdrawal_requests | length' "$BRIDGE_STATE_PATH" 2>/dev/null || echo "0")
echo "  Withdrawal Requests: $WITHDRAWAL_COUNT"

WITHDRAWAL_NONCE=$(jq -r '.withdrawal_nonce // "0"' "$BRIDGE_STATE_PATH" 2>/dev/null)
echo "  Withdrawal Nonce: $WITHDRAWAL_NONCE"

echo ""

# Confirm import
echo -e "${YELLOW}⚠️  This will modify genesis.json${NC}"
read -p "Continue with import? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Import cancelled."
    rm "$BACKUP_PATH"
    exit 0
fi

echo ""
echo "🔄 Merging bridge state into genesis..."

# Merge bridge state into poker module
jq --argfile bridge "$BRIDGE_STATE_PATH" '
  .app_state.poker.processed_eth_txs = $bridge.processed_eth_txs |
  .app_state.poker.withdrawal_requests = ($bridge.withdrawal_requests // []) |
  .app_state.poker.withdrawal_nonce = ($bridge.withdrawal_nonce // "0") |
  .app_state.poker.params = $bridge.params
' "$BACKUP_PATH" > "${GENESIS_PATH}.tmp"

# Validate merged genesis
if ! jq empty "${GENESIS_PATH}.tmp" 2>/dev/null; then
    echo -e "${RED}❌ Error: Merged genesis is not valid JSON${NC}"
    echo "Restoring backup..."
    mv "$BACKUP_PATH" "$GENESIS_PATH"
    rm -f "${GENESIS_PATH}.tmp"
    exit 1
fi

# Replace genesis with merged version
mv "${GENESIS_PATH}.tmp" "$GENESIS_PATH"

echo -e "${GREEN}✅ Bridge state imported successfully!${NC}"
echo ""

# Verify import
echo "Verifying import..."
NEW_PROCESSED_TX_COUNT=$(jq '.app_state.poker.processed_eth_txs | length' "$GENESIS_PATH" 2>/dev/null || echo "0")
NEW_WITHDRAWAL_COUNT=$(jq '.app_state.poker.withdrawal_requests | length' "$GENESIS_PATH" 2>/dev/null || echo "0")
NEW_WITHDRAWAL_NONCE=$(jq -r '.app_state.poker.withdrawal_nonce // "0"' "$GENESIS_PATH" 2>/dev/null)

echo ""
echo "Verification Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Processed Ethereum TXs: $NEW_PROCESSED_TX_COUNT (expected: $PROCESSED_TX_COUNT)"
echo "  Withdrawal Requests: $NEW_WITHDRAWAL_COUNT (expected: $WITHDRAWAL_COUNT)"
echo "  Withdrawal Nonce: $NEW_WITHDRAWAL_NONCE (expected: $WITHDRAWAL_NONCE)"
echo ""

if [ "$NEW_PROCESSED_TX_COUNT" = "$PROCESSED_TX_COUNT" ] && \
   [ "$NEW_WITHDRAWAL_COUNT" = "$WITHDRAWAL_COUNT" ] && \
   [ "$NEW_WITHDRAWAL_NONCE" = "$WITHDRAWAL_NONCE" ]; then
    echo -e "${GREEN}✅ Import verified successfully!${NC}"
    echo ""
    echo "Backup kept at: $BACKUP_PATH"
    echo "You can delete it manually if everything works correctly."
else
    echo -e "${RED}❌ Verification failed! Counts don't match.${NC}"
    echo ""
    echo "Restoring backup..."
    mv "$BACKUP_PATH" "$GENESIS_PATH"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Import complete!${NC}"
echo ""
