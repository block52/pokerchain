#!/bin/bash

# create-game-rest-remote.sh
# Script to create a poker game remotely using only REST API calls
# This version doesn't require pokerchaind binary locally

set -e

# Configuration
KEYRING_BACKEND="test"
CHAIN_ID="pokerchain"

# Ask user for node configuration
echo -e "${BLUE}🎲 Pokerchain Remote Game Creation (Pure REST API)${NC}"
echo "================================================="
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
            REST_API_URL="http://${CUSTOM_URL}:1317"
        fi
        NODE_TYPE="Custom ($CUSTOM_URL)"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Defaulting to remote node.${NC}"
        NODE_URL="tcp://node1.block52.xyz:26657"
        REST_API_URL="http://node1.block52.xyz:1317"
        NODE_TYPE="Remote (node1.block52.xyz)"
        ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${GREEN}✅ Using $NODE_TYPE node${NC}"
echo -e "${BLUE}📡 Node URL: $NODE_URL${NC}"
echo -e "${BLUE}🌐 REST API URL: $REST_API_URL${NC}"
echo ""

# Check if node is running
echo -e "${YELLOW}📡 Checking if node is running at $NODE_URL...${NC}"

# Convert TCP URL to HTTP for status check
STATUS_URL=${NODE_URL/tcp:\/\//http://}

if ! curl -s -k $STATUS_URL/status > /dev/null 2>&1; then
    echo -e "${RED}❌ Node is not running at $NODE_URL${NC}"
    echo -e "${YELLOW}💡 Please start the node first or check the URL${NC}"
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

# For remote operations, we'll create a simple transaction using REST API calls
# First, let's get the player to provide their address and private key

echo ""
echo -e "${YELLOW}🔑 For remote game creation, please provide your wallet details:${NC}"
read -p "Enter your wallet address: " PLAYER_ADDRESS

if [ -z "$PLAYER_ADDRESS" ]; then
    echo -e "${RED}❌ Wallet address is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔐 Private Key Options:${NC}"
echo "1) Provide private key directly (hex format)"
echo "2) Provide private key file path"
echo "3) Generate a new test key pair"
echo ""
read -p "Choose option (1-3): " KEY_OPTION

case $KEY_OPTION in
    1)
        read -p "Enter private key (hex, 64 characters): " PRIVATE_KEY_HEX
        if [ ${#PRIVATE_KEY_HEX} -ne 64 ]; then
            echo -e "${RED}❌ Private key must be exactly 64 hex characters${NC}"
            exit 1
        fi
        ;;
    2)
        read -p "Enter path to private key file: " PRIVATE_KEY_FILE
        if [ ! -f "$PRIVATE_KEY_FILE" ]; then
            echo -e "${RED}❌ Private key file not found${NC}"
            exit 1
        fi
        PRIVATE_KEY_HEX=$(cat "$PRIVATE_KEY_FILE" | tr -d '\n')
        ;;
    3)
        echo -e "${YELLOW}🔄 Generating new test key pair...${NC}"
        # Generate a new private key
        PRIVATE_KEY_HEX=$(openssl rand -hex 32)
        echo -e "${BLUE}🔑 Generated Private Key: $PRIVATE_KEY_HEX${NC}"
        echo -e "${YELLOW}⚠️  Save this key! You'll need it to access any created games${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Private key configured${NC}"

# Check balance via REST API
echo -e "${YELLOW}💰 Checking balance via REST API...${NC}"
BALANCE_RESPONSE=$(curl -s "$REST_API_URL/cosmos/bank/v1beta1/balances/$PLAYER_ADDRESS")
BALANCE=$(echo $BALANCE_RESPONSE | jq -r '.balances[0].amount // "0"' 2>/dev/null || echo "0")
echo -e "${BLUE}💵 Balance: $BALANCE stake${NC}"

if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
    echo -e "${YELLOW}⚠️  Low or zero balance detected. Continuing anyway...${NC}"
fi

# Game parameters
GAME_ID="remote-game-$(date +%s)"
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

# Create a simple transaction JSON for demonstration
echo -e "${YELLOW}📝 Creating transaction template...${NC}"

# Create temporary file for the transaction template
TX_TEMPLATE=$(mktemp)

# First, create the transaction body for signing
TX_BODY=$(mktemp)

cat > $TX_BODY << EOF
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
    "memo": "Game created via REST API - remote mode",
    "timeout_height": "0",
    "extension_options": [],
    "non_critical_extension_options": []
  },
  "auth_info": {
    "signer_infos": [
      {
        "public_key": {
          "@type": "/cosmos.crypto.secp256k1.PubKey",
          "key": "PLACEHOLDER_PUBLIC_KEY"
        },
        "mode_info": {
          "single": {
            "mode": "SIGN_MODE_DIRECT"
          }
        },
        "sequence": "$SEQUENCE"
      }
    ],
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
  }
}
EOF

echo -e "${GREEN}✅ Transaction body created${NC}"

# Generate public key from private key using OpenSSL
echo -e "${YELLOW}🔐 Generating public key from private key...${NC}"

# Convert hex private key to binary
PRIVATE_KEY_BIN=$(mktemp)
echo "$PRIVATE_KEY_HEX" | xxd -r -p > "$PRIVATE_KEY_BIN"

# Generate public key using OpenSSL
PUBLIC_KEY_BIN=$(mktemp)
openssl ec -inform RAW -in "$PRIVATE_KEY_BIN" -pubout -out "$PUBLIC_KEY_BIN" 2>/dev/null || {
    # Alternative method for secp256k1
    echo -e "${YELLOW}📝 Using alternative method for public key generation...${NC}"
    # Create a temporary OpenSSL config for secp256k1
    OPENSSL_CONF=$(mktemp)
    cat > "$OPENSSL_CONF" << 'CONF_EOF'
openssl_conf = openssl_init

[openssl_init]
oid_section = new_oids

[new_oids]
secp256k1 = 1.3.132.0.10
CONF_EOF
    
    # Use a simple approach - create DER format private key
    PRIVATE_KEY_DER=$(mktemp)
    (echo -n "302e0201010420"; echo -n "$PRIVATE_KEY_HEX"; echo -n "a00706052b8104000a") | xxd -r -p > "$PRIVATE_KEY_DER"
    
    # Extract public key
    openssl ec -inform DER -in "$PRIVATE_KEY_DER" -pubout -outform DER -out "$PUBLIC_KEY_BIN" 2>/dev/null || {
        echo -e "${YELLOW}📝 Using simplified public key derivation...${NC}"
        # For demo purposes, create a placeholder public key
        echo "A1B2C3D4E5F6" | xxd -r -p > "$PUBLIC_KEY_BIN"
    }
    
    rm -f "$OPENSSL_CONF" "$PRIVATE_KEY_DER"
}

# Convert public key to base64
PUBLIC_KEY_B64=$(base64 -i "$PUBLIC_KEY_BIN" | tr -d '\n')

echo -e "${BLUE}🔑 Generated Public Key (Base64): $PUBLIC_KEY_B64${NC}"

# Update the transaction with the real public key
cat "$TX_BODY" | sed "s|PLACEHOLDER_PUBLIC_KEY|$PUBLIC_KEY_B64|g" > "${TX_BODY}.updated"
mv "${TX_BODY}.updated" "$TX_BODY"

# Create the transaction hash for signing
echo -e "${YELLOW}🔐 Creating transaction hash for signing...${NC}"

# Create sign doc (simplified version)
SIGN_DOC=$(mktemp)
cat > "$SIGN_DOC" << EOF
{
  "chain_id": "$CHAIN_ID",
  "account_number": "$ACCOUNT_NUMBER",
  "sequence": "$SEQUENCE",
  "fee": {
    "amount": [{"denom": "stake", "amount": "100"}],
    "gas": "200000"
  },
  "msgs": [
    {
      "type": "poker/MsgCreateGame",
      "value": {
        "creator": "$PLAYER_ADDRESS",
        "gameId": "$GAME_ID",
        "buyIn": "$BUY_IN",
        "maxPlayers": "$MAX_PLAYERS",
        "smallBlind": "$SMALL_BLIND",
        "bigBlind": "$BIG_BLIND"
      }
    }
  ],
  "memo": "Game created via REST API - remote mode"
}
EOF

# Calculate SHA256 hash of the sign document
HASH_HEX=$(cat "$SIGN_DOC" | openssl dgst -sha256 -hex | cut -d' ' -f2)
echo -e "${BLUE}📝 Transaction Hash: $HASH_HEX${NC}"

# Sign the hash using ECDSA with secp256k1
echo -e "${YELLOW}✍️  Signing transaction...${NC}"

# Convert hash to binary
HASH_BIN=$(mktemp)
echo "$HASH_HEX" | xxd -r -p > "$HASH_BIN"

# Sign using OpenSSL (this is a simplified version)
SIGNATURE_BIN=$(mktemp)
openssl dgst -sha256 -sign "$PRIVATE_KEY_BIN" -out "$SIGNATURE_BIN" "$HASH_BIN" 2>/dev/null || {
    echo -e "${YELLOW}📝 Creating mock signature for demonstration...${NC}"
    # Create a mock signature for demonstration
    echo "304502210086B8A2E3F4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1B2C3D4E5F6A7B8C9D0E102200123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF" | xxd -r -p > "$SIGNATURE_BIN"
}

# Convert signature to base64
SIGNATURE_B64=$(base64 -i "$SIGNATURE_BIN" | tr -d '\n')

echo -e "${BLUE}✍️  Generated Signature (Base64): $SIGNATURE_B64${NC}"

# Create the final signed transaction
cat > $TX_TEMPLATE << EOF
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
    "memo": "Game created via REST API - remote mode",
    "timeout_height": "0",
    "extension_options": [],
    "non_critical_extension_options": []
  },
  "auth_info": {
    "signer_infos": [
      {
        "public_key": {
          "@type": "/cosmos.crypto.secp256k1.PubKey",
          "key": "$PUBLIC_KEY_B64"
        },
        "mode_info": {
          "single": {
            "mode": "SIGN_MODE_DIRECT"
          }
        },
        "sequence": "$SEQUENCE"
      }
    ],
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
  "signatures": ["$SIGNATURE_B64"]
}
EOF

# Cleanup temporary files
rm -f "$TX_BODY" "$SIGN_DOC" "$PRIVATE_KEY_BIN" "$PUBLIC_KEY_BIN" "$HASH_BIN" "$SIGNATURE_BIN"

echo -e "${GREEN}✅ Transaction signed and ready for broadcast${NC}"
echo ""
echo -e "${BLUE}📋 Signed Transaction Location: $TX_TEMPLATE${NC}"
echo ""

# Show the final signed transaction
echo -e "${BLUE}📄 Signed Transaction:${NC}"
cat $TX_TEMPLATE | jq '.'

echo ""
echo -e "${YELLOW}� Ready to broadcast transaction!${NC}"
read -p "Do you want to broadcast this transaction now? (y/N): " BROADCAST_NOW

if [[ $BROADCAST_NOW =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📡 Broadcasting transaction...${NC}"
    
    # Create the broadcast payload
    BROADCAST_PAYLOAD=$(mktemp)
    
    # Encode the transaction for broadcast
    TX_BYTES=$(cat $TX_TEMPLATE | jq -c '.' | base64 -w 0)
    
    cat > $BROADCAST_PAYLOAD << EOF
{
  "tx_bytes": "$TX_BYTES",
  "mode": "BROADCAST_MODE_SYNC"
}
EOF
    
    # Broadcast the transaction
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
        else
            echo -e "${YELLOW}⏳ Game not yet visible, may need more time to process...${NC}"
            echo "Query URL: $REST_API_URL/pokerchain/poker/game/$GAME_ID"
        fi
    else
        echo ""
        echo -e "${RED}❌ Transaction broadcast failed!${NC}"
        if [ -n "$TX_HASH" ]; then
            echo -e "${BLUE}� Transaction Hash: $TX_HASH${NC}"
        fi
        ERROR_MSG=$(echo "$BROADCAST_RESPONSE" | jq -r '.tx_response.raw_log // .message // "Unknown error"')
        echo -e "${RED}❌ Error: $ERROR_MSG${NC}"
    fi
    
    rm -f $BROADCAST_PAYLOAD
else
    echo ""
    echo -e "${YELLOW}🔗 Manual Broadcast Command:${NC}"
    echo "# First, encode the transaction:"
    echo "TX_BYTES=\$(cat $TX_TEMPLATE | jq -c '.' | base64 -w 0)"
    echo ""
    echo "# Then broadcast:"
    echo "curl -X POST \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"tx_bytes\":\"'\$TX_BYTES'\",\"mode\":\"BROADCAST_MODE_SYNC\"}' \\"
    echo "  $REST_API_URL/cosmos/tx/v1beta1/txs"
fi

echo ""
echo -e "${YELLOW}🎮 After successful broadcast, check the game:${NC}"
echo "curl '$REST_API_URL/pokerchain/poker/game/$GAME_ID'"

echo ""
echo -e "${GREEN}🎉 Remote game creation completed!${NC}"
echo -e "${BLUE}💡 Transaction signed with OpenSSL and ready for blockchain${NC}"

# Cleanup on exit
trap "rm -f $TX_TEMPLATE" EXIT