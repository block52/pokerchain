#!/bin/bash

# Test Alchemy connectivity and verify contract

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "❌ ERROR: .env file not found!"
    echo "Please copy .env.example to .env and add your Alchemy API key"
    exit 1
fi

CONTRACT_ADDRESS="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
DEPOSITED_EVENT_TOPIC="0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2"

echo "Testing Alchemy Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Check if Alchemy is responding
echo "Test 1: Check Alchemy RPC connectivity..."
response=$(curl -s -X POST "$ALCHEMY_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')

if [ -z "$response" ]; then
    echo "❌ FAILED: No response from Alchemy"
    exit 1
fi

block=$(echo "$response" | jq -r '.result' 2>/dev/null)
if [ "$block" != "null" ] && [ -n "$block" ]; then
    block_dec=$((block))
    echo "✅ PASSED: Alchemy is responding (current block: $block_dec)"
else
    echo "❌ FAILED: Invalid response"
    echo "Response: $response"
    exit 1
fi

echo ""

# Test 2: Check contract code
echo "Test 2: Verify contract exists..."
response=$(curl -s -X POST "$ALCHEMY_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$CONTRACT_ADDRESS\",\"latest\"],\"id\":1}")

code=$(echo "$response" | jq -r '.result' 2>/dev/null)
if [ "$code" = "0x" ] || [ "$code" = "null" ]; then
    echo "❌ FAILED: No contract code at address $CONTRACT_ADDRESS"
    echo "   This address may not have a deployed contract"
    exit 1
else
    code_len=${#code}
    echo "✅ PASSED: Contract exists (code length: $code_len bytes)"
fi

echo ""

# Test 3: Query deposit events
echo "Test 3: Query deposit events..."
response=$(curl -s -X POST "$ALCHEMY_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"eth_getLogs\",
    \"params\": [{
      \"address\": \"$CONTRACT_ADDRESS\",
      \"topics\": [\"$DEPOSITED_EVENT_TOPIC\"],
      \"fromBlock\": \"0x0\",
      \"toBlock\": \"latest\"
    }],
    \"id\": 1
  }")

# Check for errors
error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
if [ -n "$error" ]; then
    echo "❌ FAILED: RPC Error: $error"
    echo "Full error:"
    echo "$response" | jq '.error'
    exit 1
fi

# Check result
result=$(echo "$response" | jq -r '.result' 2>/dev/null)
if [ "$result" = "null" ] || [ -z "$result" ]; then
    echo "❌ FAILED: No deposit events found"
    echo "Response: $response"
    echo ""
    echo "This could mean:"
    echo "  - No deposits have been made to this contract yet"
    echo "  - Wrong contract address"
    echo "  - Wrong event signature"
    echo ""
    echo "Verify on BaseScan:"
    echo "  https://basescan.org/address/$CONTRACT_ADDRESS#events"
    exit 1
fi

count=$(echo "$response" | jq -r '.result | length' 2>/dev/null)
echo "✅ PASSED: Found $count deposit event(s)"

echo ""
echo "Deposit Details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "$response" | jq -r '.result[] | @json' | while read -r event; do
    tx=$(echo "$event" | jq -r '.transactionHash')
    block=$(echo "$event" | jq -r '.blockNumber')
    data=$(echo "$event" | jq -r '.data')
    
    # Parse nonce from data
    data="${data#0x}"
    nonce_hex="0x${data:64:64}"
    nonce=$((nonce_hex))
    
    # Parse amount
    amount_hex="0x${data:0:64}"
    amount=$((amount_hex))
    
    echo "Nonce: $nonce | Amount: $amount | Block: $((block)) | TX: $tx"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All tests passed! Bridge contract is accessible and has deposits."
echo ""
echo "You can now run:"
echo "  ./process-bridge-deposit.sh <nonce>"