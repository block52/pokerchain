#!/bin/bash

# Reset Cosmos Chain While Preserving Bridge State
# Main orchestrator script that exports bridge state, resets chain, and re-imports state

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default paths
POKERCHAIN_HOME="${POKERCHAIN_HOME:-$HOME/.pokerchain}"
BRIDGE_STATE_BACKUP="/tmp/bridge-state-$(date +%Y%m%d-%H%M%S).json"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}    🌉 Reset Chain with Bridge State Preservation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This script will:"
echo "  1. ✅ Export current bridge state (ProcessedEthTxs, withdrawal_requests)"
echo "  2. 🔥 Reset blockchain to genesis (delete all blocks and state)"
echo "  3. 💾 Re-import bridge state into fresh genesis"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will DELETE all blocks and transaction history!${NC}"
echo ""
echo "Preserved data:"
echo "  • ProcessedEthTxs (prevents double-minting)"
echo "  • Withdrawal requests and nonces"
echo "  • Bridge parameters"
echo "  • Validator keys and node configuration"
echo ""
echo "Deleted data:"
echo "  • All blocks"
echo "  • Game states"
echo "  • Transaction history"
echo "  • Address book (will rebuild from seeds)"
echo ""

# Confirm operation
read -p "Type 'RESET' (in capitals) to confirm: " confirmation

if [ "$confirmation" != "RESET" ]; then
    echo ""
    echo "Reset cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1/5: Export Current Bridge State${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if chain is running
if pgrep -x "pokerchaind" > /dev/null; then
    echo -e "${YELLOW}⚠️  pokerchaind is currently running${NC}"
    echo "The chain should be stopped before resetting."
    echo ""
    read -p "Stop pokerchaind now? (y/n): " stop_chain

    if [[ "$stop_chain" =~ ^[Yy]$ ]]; then
        echo "Stopping pokerchaind..."
        pkill -SIGTERM pokerchaind || true
        sleep 3

        if pgrep -x "pokerchaind" > /dev/null; then
            echo -e "${YELLOW}⚠️  pokerchaind still running, force killing...${NC}"
            pkill -9 pokerchaind || true
            sleep 2
        fi

        echo -e "${GREEN}✅ pokerchaind stopped${NC}"
    else
        echo ""
        echo "Please stop pokerchaind manually and run this script again."
        exit 1
    fi
fi

# Export current genesis for state extraction
GENESIS_PATH="$POKERCHAIN_HOME/config/genesis.json"

if [ ! -f "$GENESIS_PATH" ]; then
    echo -e "${RED}❌ Error: Genesis file not found at $GENESIS_PATH${NC}"
    echo "Is pokerchain initialized?"
    exit 1
fi

# Run export script
if [ -f "$SCRIPT_DIR/export-bridge-state.sh" ]; then
    bash "$SCRIPT_DIR/export-bridge-state.sh" "$GENESIS_PATH" "$BRIDGE_STATE_BACKUP"
else
    echo -e "${RED}❌ Error: export-bridge-state.sh not found${NC}"
    exit 1
fi

# Verify export succeeded
if [ ! -f "$BRIDGE_STATE_BACKUP" ]; then
    echo -e "${RED}❌ Error: Bridge state export failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2/5: Backup Current Genesis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

GENESIS_BACKUP="$POKERCHAIN_HOME/config/genesis-backup-$(date +%Y%m%d-%H%M%S).json"
cp "$GENESIS_PATH" "$GENESIS_BACKUP"
echo "📋 Genesis backed up to: $GENESIS_BACKUP"
echo -e "${GREEN}✅ Backup created${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3/5: Reset Blockchain State${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Running: pokerchaind tendermint unsafe-reset-all"
echo ""

if ! pokerchaind tendermint unsafe-reset-all; then
    echo -e "${RED}❌ Error: Failed to reset chain${NC}"
    echo ""
    echo "Your bridge state is safely backed up at: $BRIDGE_STATE_BACKUP"
    echo "Your genesis is backed up at: $GENESIS_BACKUP"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Blockchain state reset successfully${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4/5: Import Bridge State${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Run import script
if [ -f "$SCRIPT_DIR/import-bridge-state.sh" ]; then
    # Import script will ask for confirmation
    bash "$SCRIPT_DIR/import-bridge-state.sh" "$GENESIS_PATH" "$BRIDGE_STATE_BACKUP"
else
    echo -e "${RED}❌ Error: import-bridge-state.sh not found${NC}"
    echo ""
    echo "Your bridge state is safely backed up at: $BRIDGE_STATE_BACKUP"
    echo "You can manually import it later."
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 5/5: Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verify critical files still exist
echo "Verifying preserved files:"
echo ""

CRITICAL_FILES=(
    "$POKERCHAIN_HOME/config/priv_validator_key.json"
    "$POKERCHAIN_HOME/config/node_key.json"
    "$POKERCHAIN_HOME/config/genesis.json"
)

ALL_GOOD=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✅${NC} $(basename $file)"
    else
        echo -e "  ${RED}❌${NC} $(basename $file) - MISSING!"
        ALL_GOOD=false
    fi
done

echo ""

if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✅ All critical files verified${NC}"
else
    echo -e "${RED}❌ Some files are missing!${NC}"
    echo "You may need to restore from backups."
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Reset Complete with Bridge State Preserved!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Summary:"
echo "  • Chain reset to block 0"
echo "  • Bridge state preserved (ProcessedEthTxs, withdrawal_requests)"
echo "  • Validator keys intact"
echo "  • Genesis file updated"
echo ""
echo "Backups saved:"
echo "  • Bridge state: $BRIDGE_STATE_BACKUP"
echo "  • Genesis: $GENESIS_BACKUP"
echo ""
echo "Next steps:"
echo "  1. Start the chain: pokerchaind start"
echo "  2. Or use systemd: sudo systemctl start pokerchaind"
echo "  3. Verify bridge state by querying processed transactions"
echo ""
echo "Monitor logs:"
echo "  tail -f $POKERCHAIN_HOME/pokerchaind.log"
echo "  journalctl -u pokerchaind -f"
echo ""
