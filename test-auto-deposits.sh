#!/bin/bash

# Test Automatic Deposit Processing
# Starts a local node and monitors for automatic deposit checks

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}         🧪 Testing Automatic Deposit Processing${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if pokerchaind is already running
if pgrep -x pokerchaind > /dev/null; then
    echo -e "${YELLOW}⚠️  pokerchaind is already running${NC}"
    echo ""
    echo "Please stop it first:"
    echo "  kill \$(pgrep pokerchaind)"
    echo "  OR"
    echo "  sudo systemctl stop pokerchaind"
    echo ""
    exit 1
fi

# Verify binary exists
if [ ! -f ~/go/bin/pokerchaind ]; then
    echo -e "${RED}❌ pokerchaind not found in ~/go/bin/${NC}"
    echo ""
    echo "Please build first:"
    echo "  make install"
    exit 1
fi

# Show version
VERSION=$(~/go/bin/pokerchaind version 2>&1)
echo -e "${GREEN}✅ Using pokerchaind: $VERSION${NC}"
echo ""

# Check bridge configuration
echo -e "${BLUE}📋 Bridge Configuration:${NC}"
DEPOSIT_CONTRACT=$(grep "deposit_contract_address" ~/.pokerchain/config/app.toml | cut -d'"' -f2)
ETH_RPC=$(grep "ethereum_rpc_url" ~/.pokerchain/config/app.toml | cut -d'"' -f2 | sed 's/.*v2\//.../')

echo "  Deposit Contract: $DEPOSIT_CONTRACT"
echo "  Ethereum RPC: .../$ETH_RPC"
echo ""

echo -e "${YELLOW}ℹ️  The automatic deposit processor will:${NC}"
echo "  1. Check every 10 minutes (not every block)"
echo "  2. Query Ethereum for highest deposit index"
echo "  3. Find missing deposit indices (gaps)"
echo "  4. Process up to 10 missing deposits per batch"
echo "  5. Store L1 block number with each deposit"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Starting pokerchaind...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Look for these log messages:"
echo "  🔍 Checking for pending deposits"
echo "  📊 Current Ethereum block"
echo "  📈 Highest deposit index on Ethereum"
echo "  🔄 Found missing deposit indices"
echo "  ✅ Automatic deposit processing completed"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start pokerchaind with filtered logs for deposit processing
~/go/bin/pokerchaind start \
  --home ~/.pokerchain \
  --minimum-gas-prices="0.01stake" 2>&1 | \
  grep --line-buffered -E "(auto_deposit|Checking for pending|deposit index|Ethereum block|missing deposit|processing completed|ERR|WARN)" || true
