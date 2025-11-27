#!/bin/bash

# Check Ethereum Deposits
# Queries the deposit contract to see available deposits

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load config
source .env 2>/dev/null || true

DEPOSIT_CONTRACT="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
ETH_RPC="${ALCHEMY_URL}"

if [ -z "$ETH_RPC" ]; then
    echo -e "${YELLOW}⚠️  ALCHEMY_URL not set in .env${NC}"
    echo "Using default RPC (may have rate limits)"
    ETH_RPC="https://base-mainnet.g.alchemy.com/v2/uwae8IxsUFGbRFh8fagTMrGz1w5iuvpc"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}         📊 Ethereum Deposit Contract Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Contract: $DEPOSIT_CONTRACT"
echo "Network:  Base Mainnet"
echo ""

# Get deposits count using deposits() function (returns array length)
# Function signature: deposits() returns (uint256)
# Try multiple possible function signatures
# deposits(): 0x8c7a63ae (depositsCount)
# deposits(): might be array length getter
COUNT_DATA="0x8c7a63ae"

echo -e "${BLUE}Querying depositsCount()...${NC}"
echo ""

RESULT=$(curl -s -X POST "$ETH_RPC" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"id\": 1,
    \"method\": \"eth_call\",
    \"params\": [{
      \"to\": \"$DEPOSIT_CONTRACT\",
      \"data\": \"$COUNT_DATA\"
    }, \"latest\"]
  }" | jq -r '.result')

if [ "$RESULT" = "null" ] || [ -z "$RESULT" ]; then
    echo -e "${YELLOW}⚠️  Could not query contract (may need different RPC or function signature)${NC}"
    echo ""
    echo "Raw result: $RESULT"
    exit 1
fi

# Convert hex to decimal
COUNT=$((16#${RESULT:2}))

echo -e "${GREEN}✅ Total Deposits: $COUNT${NC}"
echo ""

if [ "$COUNT" -gt 0 ]; then
    HIGHEST_INDEX=$((COUNT - 1))
    echo "Deposit Indices: 0 to $HIGHEST_INDEX"
    echo ""

    echo -e "${BLUE}Sample deposit (index 0):${NC}"

    # Get deposit by index using deposits(uint256) function
    # Function signature: deposits(uint256) returns (string, uint256)
    # Keccak256("deposits(uint256)") first 4 bytes
    DEPOSITS_SIG="0x8e15f473"
    # Index 0 padded to 32 bytes
    INDEX_0="0000000000000000000000000000000000000000000000000000000000000000"

    DEPOSIT_DATA=$(curl -s -X POST "$ETH_RPC" \
      -H "Content-Type: application/json" \
      -d "{
        \"jsonrpc\": \"2.0\",
        \"id\": 2,
        \"method\": \"eth_call\",
        \"params\": [{
          \"to\": \"$DEPOSIT_CONTRACT\",
          \"data\": \"${DEPOSITS_SIG}${INDEX_0}\"
        }, \"latest\"]
      }" | jq -r '.result')

    if [ "$DEPOSIT_DATA" != "null" ] && [ -n "$DEPOSIT_DATA" ]; then
        echo "  Raw data: ${DEPOSIT_DATA:0:66}..."
        echo ""
    fi

    echo -e "${YELLOW}ℹ️  To process these deposits automatically:${NC}"
    echo "  1. Run: ./test-auto-deposits.sh"
    echo "  2. Wait 10 minutes for first automatic check"
    echo "  3. Or manually process: ~/go/bin/pokerchaind tx poker process-deposit 0 --from <key>"
else
    echo -e "${YELLOW}ℹ️  No deposits found in contract${NC}"
    echo ""
    echo "To test automatic processing, you would need to:"
    echo "  1. Make a deposit to the Ethereum contract"
    echo "  2. Wait for it to be confirmed"
    echo "  3. Run ./test-auto-deposits.sh and wait 10 minutes"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
