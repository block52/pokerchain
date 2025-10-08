#!/bin/bash

# Complete genesis setup script for pokerchain
# Creates genesis with all test actors as validators with b52 tokens

set -e

echo "🎮 Setting up Pokerchain Genesis with Test Actors"
echo "================================================"

# Ask which user should be the primary validator
echo "Which test actor should run the primary validator node?"
echo "Available actors: alice, bob, charlie, diana, eve, frank, grace, henry, iris, jack"
read -p "Enter the primary validator name [alice]: " PRIMARY_VALIDATOR
PRIMARY_VALIDATOR=${PRIMARY_VALIDATOR:-alice}

echo "Primary validator will be: $PRIMARY_VALIDATOR"
echo ""

# Configuration
CHAIN_ID="pokerchain"
DENOM="b52"
STAKE_DENOM="${DENOM}stake"
ACTOR_BALANCE="52000000000000"  # 52,000 tokens (with 6 decimals = 52,000,000,000 micro)
STAKE_BALANCE="100000000000"    # 100,000 stake tokens for validators
HOME_DIR="$HOME/.pokerchain"
POKERCHAIND="$(go env GOPATH)/bin/pokerchaind"

# Test actor definitions (from TEST_ACTORS.md)
declare -A TEST_ACTORS=(
    ["alice"]="b521kftde6cge44sccxszg27g5x7w70kky3f70nw6w"
    ["bob"]="b521weeu9thllmlkkyc2ansrl39w4elh0dpt5s5jm6"
    ["charlie"]="b52109jl3nsfnf9lgpyvhr7p6z8swpevc4cw9q3ukl"
    ["diana"]="b521hg26mxaky3du8kwh2cc964jt6tsq35uqtntymf"
    ["eve"]="b521m87p5zjfqqkmpff37vrcvf6747yafdcc3elax0"
    ["frank"]="b521e20y2emrk4h9nhmn4ds70cjx3egwjv2td0v5sw"
    ["grace"]="b521x2cy3zk5cenmqp4s32ndpvvclkhzze2p5q7tjk"
    ["henry"]="b521597pw47uhvtm0rsruanvgt020kuqsjzad436cl"
    ["iris"]="b52188g856trpzqjt9w0wedelztu4xdk3yyk2mppwu"
    ["jack"]="b521eqxvhe73l9h2k3fnr6sch9mywx6uv8h6zwvmca"
)

# Validator seed phrases (Simple 12-word BIP39 mnemonics for testing)
declare -A SEED_PHRASES=(
    ["alice"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    ["bob"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon above"
    ["charlie"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon absent"
    ["diana"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon absorb"
    ["eve"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abstract"
    ["frank"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abuse"
    ["grace"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon access"
    ["henry"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon accident"
    ["iris"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon account"
    ["jack"]="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon accuse"
)

# Clean start
echo "🧹 Cleaning previous setup..."
rm -rf "$HOME_DIR"
pkill $POKERCHAIND || true

# Initialize chain with primary validator
echo "🚀 Initializing chain as $PRIMARY_VALIDATOR..."
$POKERCHAIND init "$PRIMARY_VALIDATOR" --chain-id "$CHAIN_ID" --home "$HOME_DIR"

# Add test actors as validators
echo "👥 Adding test actors as validators..."

# First add the primary validator
name=$PRIMARY_VALIDATOR
address="${TEST_ACTORS[$name]}"
seed="${SEED_PHRASES[$name]}"

echo "Adding primary validator: $name ($address)..."

# Add key from seed phrase using temporary file
echo "$seed" > /tmp/seed_$name.txt
$POKERCHAIND keys add "$name" --recover --keyring-backend test --home "$HOME_DIR" --source /tmp/seed_$name.txt
rm /tmp/seed_$name.txt

# Add genesis account with b52 tokens and stake tokens
$POKERCHAIND genesis add-genesis-account "$name" "${ACTOR_BALANCE}${DENOM},${STAKE_BALANCE}${STAKE_DENOM}" \
    --keyring-backend test --home "$HOME_DIR"

# Create primary validator transaction
echo "Creating primary validator gentx for $name..."
$POKERCHAIND genesis gentx "$name" "50000000000${STAKE_DENOM}" \
    --chain-id "$CHAIN_ID" \
    --moniker "$name-validator" \
    --commission-max-change-rate "0.1" \
    --commission-max-rate "0.2" \
    --commission-rate "0.1" \
    --keyring-backend test \
    --home "$HOME_DIR"

VALIDATOR_COUNT=1

# Add remaining test actors
for name in "${!TEST_ACTORS[@]}"; do
    # Skip if this is the primary validator (already added)
    if [ "$name" = "$PRIMARY_VALIDATOR" ]; then
        continue
    fi
    
    address="${TEST_ACTORS[$name]}"
    seed="${SEED_PHRASES[$name]}"
    
    echo "Adding $name ($address)..."
    
    # Add key from seed phrase using temporary file
    echo "$seed" > /tmp/seed_$name.txt
    $POKERCHAIND keys add "$name" --recover --keyring-backend test --home "$HOME_DIR" --source /tmp/seed_$name.txt
    rm /tmp/seed_$name.txt
    
    # Add genesis account with b52 tokens and stake tokens
    $POKERCHAIND genesis add-genesis-account "$name" "${ACTOR_BALANCE}${DENOM},${STAKE_BALANCE}${STAKE_DENOM}" \
        --keyring-backend test --home "$HOME_DIR"
    
    # Create validator transaction for first 5 actors total
    if [ $VALIDATOR_COUNT -lt 5 ]; then
        echo "Creating validator gentx for $name..."
        $POKERCHAIND genesis gentx "$name" "50000000000${STAKE_DENOM}" \
            --chain-id "$CHAIN_ID" \
            --moniker "$name-validator" \
            --commission-max-change-rate "0.1" \
            --commission-max-rate "0.2" \
            --commission-rate "0.1" \
            --keyring-backend test \
            --home "$HOME_DIR"
        VALIDATOR_COUNT=$((VALIDATOR_COUNT + 1))
    fi
done

# Collect genesis transactions
echo "📝 Collecting genesis transactions..."
$POKERCHAIND genesis collect-gentxs --home "$HOME_DIR"

# Validate genesis
echo "✅ Validating genesis..."
$POKERCHAIND genesis validate --home "$HOME_DIR"

# Copy final genesis to project root
echo "📋 Copying genesis to project root..."
cp "$HOME_DIR/config/genesis.json" ./genesis.json

# Copy app.toml for reference
cp "$HOME_DIR/config/app.toml" ./app.toml || echo "⚠️  app.toml not found"

echo ""
echo "🎉 Genesis setup complete!"
echo "========================="
echo ""
echo "🛡️  Primary Validator: $PRIMARY_VALIDATOR"
echo ""
echo "Test Actors Added:"
for name in "${!TEST_ACTORS[@]}"; do
    if [ "$name" = "$PRIMARY_VALIDATOR" ]; then
        echo "  ⭐ $name: ${TEST_ACTORS[$name]} (PRIMARY VALIDATOR)"
    else
        echo "  ✅ $name: ${TEST_ACTORS[$name]}"
    fi
done
echo ""
echo "💰 Each actor has:"
echo "  - $ACTOR_BALANCE $DENOM tokens"
echo "  - $STAKE_BALANCE $STAKE_DENOM tokens" 
echo ""
echo "🛡️  Total Validators: $VALIDATOR_COUNT"
echo ""
echo "📁 Files created:"
echo "  - ./genesis.json (project root)"
echo "  - ./app.toml (app configuration)"
echo "  - $HOME_DIR (full node setup)"
echo ""
echo "🚀 Ready to deploy to node1.block52.xyz!"
echo "   Run: ./deploy-node.sh node1.block52.xyz root"