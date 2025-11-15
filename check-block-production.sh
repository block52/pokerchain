#!/bin/bash

# Quick Block Production Check
# Tests if node1.block52.xyz is actively producing blocks

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
REMOTE_NODE="${1:-node1.block52.xyz}"
# Default to HTTPS RPC endpoint via NGINX
RPC_URL="${2:-https://node1.block52.xyz/rpc}"
WAIT_TIME="${3:-10}"

# If second argument looks like a port number, construct old-style URL for backward compatibility
if [[ "$2" =~ ^[0-9]+$ ]]; then
    RPC_URL="http://$REMOTE_NODE:$2"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}          Block Production Test for $REMOTE_NODE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if node is accessible
echo -n "Checking RPC accessibility... "
if ! curl -s --max-time 5 "$RPC_URL/status" > /dev/null 2>&1; then
    echo -e "${RED}❌ FAILED${NC}"
    echo ""
    echo "Cannot connect to $RPC_URL"
    echo ""
    echo "Please ensure:"
    echo "  1. Node is running"
    echo "  2. RPC endpoint is accessible"
    echo "  3. Firewall allows connections"
    exit 1
fi
echo -e "${GREEN}✅ OK${NC}"
echo ""

# Get initial status
echo "Fetching initial block height..."
STATUS1=$(curl -s "$RPC_URL/status")

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not installed - using grep method${NC}"
    BLOCK1=$(echo "$STATUS1" | grep -o '"latest_block_height":"[0-9]*"' | cut -d'"' -f4)
else
    BLOCK1=$(echo "$STATUS1" | jq -r '.result.sync_info.latest_block_height')
    CHAIN_ID=$(echo "$STATUS1" | jq -r '.result.node_info.network')
    CATCHING_UP=$(echo "$STATUS1" | jq -r '.result.sync_info.catching_up')
    BLOCK_TIME1=$(echo "$STATUS1" | jq -r '.result.sync_info.latest_block_time')
    
    echo ""
    echo "Network Status:"
    echo "  Chain ID:      $CHAIN_ID"
    echo "  Current Block: $BLOCK1"
    echo "  Block Time:    $BLOCK_TIME1"
    echo "  Catching Up:   $CATCHING_UP"
fi

if [ -z "$BLOCK1" ] || [ "$BLOCK1" == "null" ]; then
    echo -e "${RED}❌ Could not get block height${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Waiting $WAIT_TIME seconds for new blocks...${NC}"

# Progress bar
for i in $(seq $WAIT_TIME -1 1); do
    printf "\r  Time remaining: %2d seconds" $i
    sleep 1
done
echo ""
echo ""

# Get new status
echo "Fetching new block height..."
STATUS2=$(curl -s "$RPC_URL/status")

if ! command -v jq &> /dev/null; then
    BLOCK2=$(echo "$STATUS2" | grep -o '"latest_block_height":"[0-9]*"' | cut -d'"' -f4)
else
    BLOCK2=$(echo "$STATUS2" | jq -r '.result.sync_info.latest_block_height')
    BLOCK_TIME2=$(echo "$STATUS2" | jq -r '.result.sync_info.latest_block_time')
fi

if [ -z "$BLOCK2" ] || [ "$BLOCK2" == "null" ]; then
    echo -e "${RED}❌ Could not get updated block height${NC}"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Calculate blocks produced
BLOCKS_PRODUCED=$((BLOCK2 - BLOCK1))

echo "Results:"
echo "  Initial Block:  $BLOCK1"
echo "  Current Block:  $BLOCK2"
echo "  Blocks Created: $BLOCKS_PRODUCED"
echo ""

if [ $BLOCKS_PRODUCED -gt 0 ]; then
    echo -e "${GREEN}✅ BLOCK PRODUCTION ACTIVE!${NC}"
    echo ""
    
    # Calculate rate
    BLOCKS_PER_MIN=$(echo "scale=2; $BLOCKS_PRODUCED * 60 / $WAIT_TIME" | bc 2>/dev/null || echo "~$((BLOCKS_PRODUCED * 6))")
    BLOCK_TIME=$(echo "scale=2; $WAIT_TIME / $BLOCKS_PRODUCED" | bc 2>/dev/null || echo "~$((WAIT_TIME / BLOCKS_PRODUCED))")
    
    echo "  Production Rate: ~$BLOCKS_PER_MIN blocks/minute"
    echo "  Average Time:    ~$BLOCK_TIME seconds/block"
    echo ""
    echo -e "${GREEN}✅ Node is healthy and producing blocks!${NC}"
    
elif [ $BLOCKS_PRODUCED -eq 0 ]; then
    echo -e "${RED}❌ NO BLOCKS PRODUCED${NC}"
    echo ""
    echo "Possible issues:"
    echo "  1. Validator is not active"
    echo "  2. Node is stalled"
    echo "  3. Not enough voting power"
    echo "  4. Network consensus issues"
    echo ""
    echo "Troubleshooting commands:"
    echo "  # Check node status"
    echo "  ssh $REMOTE_NODE 'systemctl status pokerchaind'"
    echo ""
    echo "  # Check recent logs"
    echo "  ssh $REMOTE_NODE 'journalctl -u pokerchaind -n 100 --no-pager'"
    echo ""
    echo "  # Check validators"
    echo "  curl http://$REMOTE_NODE:$RPC_PORT/validators | jq"
    echo ""
    echo "  # Check consensus state"
    echo "  curl http://$REMOTE_NODE:$RPC_PORT/dump_consensus_state | jq"
    
else
    echo -e "${YELLOW}⚠️  WARNING: Block height decreased${NC}"
    echo ""
    echo "This may indicate:"
    echo "  - Chain was restarted"
    echo "  - Node was reset"
    echo "  - Different chain/network"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Additional checks
if command -v jq &> /dev/null; then
    echo "Additional Information:"
    echo ""
    
    # Get validator info
    echo "Checking validator set..."
    VALIDATORS=$(curl -s "http://$REMOTE_NODE:$RPC_PORT/validators" | jq -r '.result.total' 2>/dev/null || echo "unknown")
    echo "  Active Validators: $VALIDATORS"
    
    # Get peer info
    echo ""
    echo "Checking network peers..."
    NET_INFO=$(curl -s "http://$REMOTE_NODE:$RPC_PORT/net_info")
    PEER_COUNT=$(echo "$NET_INFO" | jq -r '.result.n_peers' 2>/dev/null || echo "unknown")
    echo "  Connected Peers: $PEER_COUNT"
    
    if [ "$PEER_COUNT" != "unknown" ] && [ "$PEER_COUNT" -gt 0 ]; then
        echo ""
        echo "  Peer details:"
        echo "$NET_INFO" | jq -r '.result.peers[] | "    - " + .node_info.moniker + " (" + .remote_ip + ")"' 2>/dev/null || true
    fi
    
    echo ""
fi

echo "Quick check commands:"
echo "  curl http://$REMOTE_NODE:$RPC_PORT/status | jq"
echo "  curl http://$REMOTE_NODE:$RPC_PORT/validators | jq"
echo "  curl http://$REMOTE_NODE:$RPC_PORT/net_info | jq"
echo ""

exit 0
