#!/bin/bash

# create-game-rest-test.sh
# Script to test creating a poker game on the pokerchain using REST API

set -e

# Configuration
NODE_HOME="${HOME}/.pokerchain"
KEYRING_BACKEND="test"
CHAIN_ID="pokerchain"

# Ask user for node configuration
echo -e "${BLUE}🎲 Pokerchain Remote Game Creation Test (REST API)${NC}"
echo "=================================================="
echo ""
echo "Please choose your node configuration:"
echo "1) Local node (localhost)"
echo "2) Remote node (node1.block52.xyz)"
echo "3) Custom URL"
echo ""
read -p "Enter your choice (1-3): " NODE_CHOICE

case $NODE_CHOICE in
    1)
        NODE_URL="tcp://localhost:26657"
        REST_API_URL="http://localhost:1317"
        NODE_TYPE="Local"
        ;;
    2)
        NODE_URL="tcp://node1.block52.xyz:26657"
        REST_API_URL="http://node1.block52.xyz:1317"
        NODE_TYPE="Remote (node1.block52.xyz)"
        ;;
    3)
        echo ""
        read -p "Enter custom node URL (e.g., your-node.com): " CUSTOM_URL
        NODE_URL="tcp://${CUSTOM_URL}:26657"
        # Check if we should use https or http
        if [[ $CUSTOM_URL == *"localhost"* ]] || [[ $CUSTOM_URL == *"127.0.0.1"* ]]; then
            REST_API_URL="http://${CUSTOM_URL}:1317"
        else
            REST_API_URL="https://${CUSTOM_URL}:1317"
        fi
        NODE_TYPE="Custom ($CUSTOM_URL)"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Defaulting to localhost.${NC}"
        NODE_URL="tcp://localhost:26657"
        REST_API_URL="http://localhost:1317"
        NODE_TYPE="Local (default)"
        ;;
esac

echo ""
echo -e "${GREEN}✅ Using $NODE_TYPE node${NC}"
echo -e "${BLUE}📡 Node URL: $NODE_URL${NC}"
echo -e "${BLUE}🌐 REST API URL: $REST_API_URL${NC}"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎲 Pokerchain Remote Game Creation Test (REST API)${NC}"
echo "=================================================="

# Check if node is running
echo -e "${YELLOW}📡 Checking if node is running at $NODE_URL...${NC}"

# Convert TCP URL to HTTP for status check
STATUS_URL=${NODE_URL/tcp:\/\//http://}
if [[ $NODE_URL == *"node1.block52.xyz"* ]]; then
    STATUS_URL="http://node1.block52.xyz:26657"
fi

if ! curl -s -k $STATUS_URL/status > /dev/null 2>&1; then
    echo -e "${RED}❌ Node is not running at $NODE_URL${NC}"
    echo -e "${YELLOW}💡 Please start the node first or check the URL${NC}"
    if [[ $NODE_TYPE == *"Local"* ]]; then
        echo "   pokerchaind start --home ~/.pokerchain"
    fi
    exit 1
fi

# Check if REST API is running
echo -e "${YELLOW}📡 Checking if REST API is running at $REST_API_URL...${NC}"
if ! curl -s -k $REST_API_URL/cosmos/base/tendermint/v1beta1/node_info > /dev/null 2>&1; then
    echo -e "${RED}❌ REST API is not running at $REST_API_URL${NC}"
    echo -e "${YELLOW}💡 Please ensure the API is enabled and accessible${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node and REST API are running${NC}"

# Check available keys
echo -e "${YELLOW}🔑 Checking available keys...${NC}"
pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME

# Get the first available key
PLAYER_KEY=$(pokerchaind keys list --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --output json | jq -r '.[0].name' 2>/dev/null || echo "")

if [ -z "$PLAYER_KEY" ] || [ "$PLAYER_KEY" = "null" ]; then
    echo -e "${RED}❌ No keys found. Creating a test key...${NC}"
    PLAYER_KEY="test-player"
    pokerchaind keys add $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME
    echo -e "${GREEN}✅ Created test key: $PLAYER_KEY${NC}"
fi

# Get player address
PLAYER_ADDRESS=$(pokerchaind keys show $PLAYER_KEY --keyring-backend $KEYRING_BACKEND --home $NODE_HOME --address)
echo -e "${BLUE}👤 Using player: $PLAYER_KEY${NC}"
echo -e "${BLUE}📍 Address: $PLAYER_ADDRESS${NC}"

# Check balance via REST API
echo -e "${YELLOW}💰 Checking balance via REST API...${NC}"
BALANCE_RESPONSE=$(curl -s "$REST_API_URL/cosmos/bank/v1beta1/balances/$PLAYER_ADDRESS")
BALANCE=$(echo $BALANCE_RESPONSE | jq -r '.balances[0].amount // "0"' 2>/dev/null || echo "0")
echo -e "${BLUE}💵 Balance: $BALANCE stake${NC}"

if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
    echo -e "${RED}❌ Insufficient balance. Need stake tokens to create games.${NC}"
    echo -e "${YELLOW}💡 You may need to mint tokens first.${NC}"
    exit 1
fi

# Game parameters
GAME_ID="rest-game-$(date +%s)"
BUY_IN="1000"
MAX_PLAYERS="6"
SMALL_BLIND="10"
BIG_BLIND="20"

echo ""
echo -e "${YELLOW}🎮 Creating poker game with parameters:${NC}"
echo -e "${BLUE}   Game ID: $GAME_ID${NC}"
echo -e "${BLUE}   Buy-in: $BUY_IN stake${NC}"
echo -e "${BLUE}   Max Players: $MAX_PLAYERS${NC}"
echo -e "${BLUE}   Small Blind: $SMALL_BLIND${NC}"
echo -e "${BLUE}   Big Blind: $BIG_BLIND${NC}"
echo ""

# Get account information for sequence and account number
echo -e "${YELLOW}🔍 Getting account information...${NC}"
ACCOUNT_INFO=$(curl -s "$REST_API_URL/cosmos/auth/v1beta1/accounts/$PLAYER_ADDRESS")
ACCOUNT_NUMBER=$(echo $ACCOUNT_INFO | jq -r '.account.account_number // "0"')
SEQUENCE=$(echo $ACCOUNT_INFO | jq -r '.account.sequence // "0"')

echo -e "${BLUE}📊 Account Number: $ACCOUNT_NUMBER${NC}"
echo -e "${BLUE}📊 Sequence: $SEQUENCE${NC}"

# Create the transaction message JSON
echo -e "${YELLOW}📝 Creating transaction message...${NC}"

# Create temporary file for the transaction
TX_FILE=$(mktemp)

# Create the unsigned transaction JSON
cat > $TX_FILE << EOF
{
  "body": {
    "messages": [
      {
        "@type": "/pokerchain.poker.MsgCreateGame",
        "creator": "$PLAYER_ADDRESS",
        "gameId": "$GAME_ID",
        "buyIn": "$BUY_IN",
        "maxPlayers": "$MAX_PLAYERS",
        "smallBlind": "$SMALL_BLIND",
        "bigBlind": "$BIG_BLIND"
      }
    ],
    "memo": "Creating game via REST API",
    "timeout_height": "0",
    "extension_options": [],
    "non_critical_extension_options": []
  },
  "auth_info": {
    "signer_infos": [],
    "fee": {
      "amount": [
        {
          "denom": "stake",
          "amount": "100"
        }
      ],
      "gas_limit": "200000",
      "payer": "",
      "granter": ""
    }
  },
  "signatures": []
}
EOF

echo -e "${GREEN}✅ Transaction message created${NC}"

# Generate the transaction using pokerchaind to get proper encoding
echo -e "${YELLOW}🔧 Generating transaction for signing...${NC}"

UNSIGNED_TX_FILE=$(mktemp)

# Use pokerchaind to generate the unsigned transaction
pokerchaind tx poker create-game \
    $GAME_ID \
    $BUY_IN \
    $MAX_PLAYERS \
    $SMALL_BLIND \
    $BIG_BLIND \
    --from $PLAYER_KEY \
    --keyring-backend $KEYRING_BACKEND \
    --home $NODE_HOME \
    --chain-id $CHAIN_ID \
    --node $NODE_URL \
    --fees 100stake \
    --gas 200000 \
    --generate-only \
    --output json > $UNSIGNED_TX_FILE

echo -e "${GREEN}✅ Unsigned transaction generated${NC}"

# Sign the transaction
echo -e "${YELLOW}✍️  Signing transaction...${NC}"

SIGNED_TX_FILE=$(mktemp)

pokerchaind tx sign $UNSIGNED_TX_FILE \
    --from $PLAYER_KEY \
    --keyring-backend $KEYRING_BACKEND \
    --home $NODE_HOME \
    --chain-id $CHAIN_ID \
    --node $NODE_URL \
    --output json > $SIGNED_TX_FILE

echo -e "${GREEN}✅ Transaction signed${NC}"

# Prepare the broadcast payload
echo -e "${YELLOW}📡 Preparing broadcast payload...${NC}"

BROADCAST_PAYLOAD=$(mktemp)

# Create the broadcast request JSON
cat > $BROADCAST_PAYLOAD << EOF
{
  "tx_bytes": "$(cat $SIGNED_TX_FILE | jq -r '.body, .auth_info, .signatures' | base64 -w 0)",
  "mode": "BROADCAST_MODE_SYNC"
}
EOF

# Actually, let's use the proper way to get tx_bytes
SIGNED_TX_CONTENT=$(cat $SIGNED_TX_FILE)

# Encode the signed transaction to get tx_bytes
TX_BYTES=$(echo "$SIGNED_TX_CONTENT" | pokerchaind tx encode --output json | jq -r '.tx')

# Create proper broadcast payload
cat > $BROADCAST_PAYLOAD << EOF
{
  "tx_bytes": "$TX_BYTES",
  "mode": "BROADCAST_MODE_SYNC"
}
EOF

# Broadcast the transaction via REST API
echo -e "${YELLOW}🚀 Broadcasting transaction via REST API...${NC}"

BROADCAST_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @$BROADCAST_PAYLOAD \
    "$REST_API_URL/cosmos/tx/v1beta1/txs")

echo -e "${BLUE}📤 Broadcast Response:${NC}"
echo "$BROADCAST_RESPONSE" | jq '.'

# Check if the transaction was successful
TX_HASH=$(echo "$BROADCAST_RESPONSE" | jq -r '.tx_response.txhash // empty')
TX_CODE=$(echo "$BROADCAST_RESPONSE" | jq -r '.tx_response.code // 1')

if [ -n "$TX_HASH" ] && [ "$TX_CODE" = "0" ]; then
    echo ""
    echo -e "${GREEN}🎉 Transaction broadcast successful!${NC}"
    echo -e "${BLUE}📋 Transaction Hash: $TX_HASH${NC}"
    
    # Wait for transaction to be processed
    echo -e "${YELLOW}⏳ Waiting for transaction to be processed...${NC}"
    sleep 3
    
    # Query the game via REST API to verify it was created
    echo -e "${YELLOW}🔍 Querying game details via REST API...${NC}"
    GAME_RESPONSE=$(curl -s "$REST_API_URL/pokerchain/poker/game/$GAME_ID")
    
    if echo "$GAME_RESPONSE" | jq -e '.game' > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}✅ Game created successfully!${NC}"
        echo -e "${BLUE}🎲 Game Details:${NC}"
        echo "$GAME_RESPONSE" | jq '.game'
        echo ""
        echo -e "${YELLOW}🎮 Next steps:${NC}"
        echo "   1. Join the game via CLI: pokerchaind tx poker join-game $GAME_ID --from $PLAYER_KEY"
        echo "   2. List all games via REST: curl $REST_API_URL/pokerchain/poker/games"
        echo "   3. Check game status via REST: curl $REST_API_URL/pokerchain/poker/game/$GAME_ID"
    else
        echo -e "${RED}❌ Game query failed. Game may not have been created properly.${NC}"
        echo "Response: $GAME_RESPONSE"
    fi
else
    echo ""
    echo -e "${RED}❌ Transaction broadcast failed!${NC}"
    if [ -n "$TX_HASH" ]; then
        echo -e "${BLUE}📋 Transaction Hash: $TX_HASH${NC}"
    fi
    ERROR_MSG=$(echo "$BROADCAST_RESPONSE" | jq -r '.tx_response.raw_log // .message // "Unknown error"')
    echo -e "${RED}❌ Error: $ERROR_MSG${NC}"
fi

# Cleanup temporary files
rm -f $TX_FILE $UNSIGNED_TX_FILE $SIGNED_TX_FILE $BROADCAST_PAYLOAD

echo ""
echo -e "${GREEN}🎉 REST API test completed!${NC}"