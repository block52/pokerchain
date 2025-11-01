#!/bin/bash

# Testnet Verification Script
# This script provides detailed information about your running testnet

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           POKERCHAIN TESTNET - VERIFICATION                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if testnet directory exists
if [ ! -d "./test" ]; then
    echo "❌ No testnet found at ./test"
    exit 1
fi

NUM_NODES=$(ls -d ./test/node* 2>/dev/null | wc -l)
echo "📊 Testnet Configuration:"
echo "   Nodes: $NUM_NODES"
echo ""

# Check each node
echo "🔍 Node Status:"
echo ""
for i in $(seq 0 $((NUM_NODES - 1))); do
    RPC_PORT=$((26657 + i))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Node $i (RPC: $RPC_PORT)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if process is running
    if pgrep -f "pokerchaind start --home ./test/node$i" > /dev/null; then
        echo "✅ Process: RUNNING"
        
        # Get full status via RPC
        STATUS=$(curl -s http://localhost:$RPC_PORT/status 2>/dev/null)
        
        if [ -n "$STATUS" ]; then
            # Parse various fields
            HEIGHT=$(echo "$STATUS" | grep -oE '"latest_block_height":"[0-9]+"' | grep -oE '[0-9]+')
            TIME=$(echo "$STATUS" | grep -oE '"latest_block_time":"[^"]*"' | cut -d'"' -f4)
            CATCHING_UP=$(echo "$STATUS" | grep -oE '"catching_up":(true|false)' | cut -d':' -f2)
            
            echo "✅ RPC: Responding"
            echo "📦 Block Height: ${HEIGHT:-0}"
            echo "⏰ Latest Block: ${TIME:-N/A}"
            echo "🔄 Catching Up: ${CATCHING_UP:-unknown}"
            
            # Get peer count
            NET_INFO=$(curl -s http://localhost:$RPC_PORT/net_info 2>/dev/null)
            PEER_COUNT=$(echo "$NET_INFO" | grep -oE '"n_peers":"[0-9]+"' | grep -oE '[0-9]+')
            echo "🤝 Connected Peers: ${PEER_COUNT:-0}"
            
        else
            echo "⚠️  RPC: Not responding (starting up?)"
        fi
        
        # Check last log entry
        if [ -f "./test/node$i.log" ]; then
            LAST_LOG=$(tail -1 ./test/node$i.log)
            if echo "$LAST_LOG" | grep -q "committed state"; then
                echo "✅ Status: Actively committing blocks"
            elif echo "$LAST_LOG" | grep -q "ERR"; then
                echo "⚠️  Status: Error detected - check logs"
            else
                echo "ℹ️  Status: Running normally"
            fi
        fi
    else
        echo "❌ Process: STOPPED"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Overall health check
echo "🏥 Overall Health:"
echo ""

RUNNING_COUNT=$(pgrep -f "pokerchaind start" | wc -l)
if [ "$RUNNING_COUNT" -eq "$NUM_NODES" ]; then
    echo "✅ All $NUM_NODES nodes are running"
else
    echo "⚠️  Only $RUNNING_COUNT of $NUM_NODES nodes are running"
fi

# Check if blocks are being produced
HEIGHTS=()
for i in $(seq 0 $((NUM_NODES - 1))); do
    RPC_PORT=$((26657 + i))
    HEIGHT=$(curl -s http://localhost:$RPC_PORT/status 2>/dev/null | grep -oE '"latest_block_height":"[0-9]+"' | grep -oE '[0-9]+')
    if [ -n "$HEIGHT" ] && [ "$HEIGHT" -gt 0 ]; then
        HEIGHTS+=($HEIGHT)
    fi
done

if [ ${#HEIGHTS[@]} -gt 0 ]; then
    MAX_HEIGHT=$(printf '%s\n' "${HEIGHTS[@]}" | sort -rn | head -1)
    if [ "$MAX_HEIGHT" -gt 5 ]; then
        echo "✅ Blocks are being produced (height: $MAX_HEIGHT)"
        echo "✅ Consensus is working!"
    else
        echo "⚠️  Low block height ($MAX_HEIGHT) - testnet may be starting"
    fi
else
    echo "❌ No blocks detected - check node logs"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Quick Commands:"
echo ""
echo "  View logs:        ./manage-testnet.sh logs 0"
echo "  Check status:     ./manage-testnet.sh status"
echo "  Stop testnet:     ./manage-testnet.sh stop"
echo "  Restart testnet:  ./manage-testnet.sh restart"
echo ""
echo "  Query validators: ./build/pokerchaind query staking validators --node tcp://localhost:26657"
echo "  Check balance:    ./build/pokerchaind query bank balances <address> --node tcp://localhost:26657"
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Your testnet appears to be working correctly! 🎉               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"