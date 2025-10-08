#!/bin/bash

# Complete genesis setup script for pokerchain
# Creates genesis with all test actors as validators with b52 tokens

set -e

echo "🎮 Setting up Pokerchain Genesis with Test Actors"
echo "================================================"

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

# Validator seed phrases (from TEST_ACTORS.md)
declare -A SEED_PHRASES=(
    ["alice"]="skull giraffe august search gather leave pond step lock report scheme cheese answer kit upgrade someone pink nuclear hero carpet write reform weekend fruit"
    ["bob"]="thunder magic carpet whisper forest dream ocean sunrise mountain valley river lake crystal melody harmony peace friendship journey adventure discovery exploration wonder"
    ["charlie"]="camp quantum bread river social castle ocean filter delay gloom metal urban"
    ["diana"]="danger violin zebra rapid cloud simple task winter museum laugh paper bread"
    ["eve"]="energy wise master hunt ladder river cloud sweet paper basic advice"
    ["frank"]="frank honest deal with perfect golden sunset bright future hope dream"
    ["grace"]="grace elegant smooth dance ritual trust wisdom balance harmony gentle peace"
    ["henry"]="henry brave mountain climb strong wind freedom victory challenge spirit bold"
    ["iris"]="iris beautiful bloom flower garden bright color nature spring lovely fresh"
    ["jack"]="jack lucky card game winner prize fortune skill practice master talent"
)

# Clean start
echo "🧹 Cleaning previous setup..."
rm -rf "$HOME_DIR"
pkill $POKERCHAIND || true

# Initialize chain
echo "🚀 Initializing chain..."
$POKERCHAIND init validator --chain-id "$CHAIN_ID" --home "$HOME_DIR"

# Add test actors as validators
echo "👥 Adding test actors as validators..."

VALIDATOR_COUNT=0
for name in "${!TEST_ACTORS[@]}"; do
    address="${TEST_ACTORS[$name]}"
    seed="${SEED_PHRASES[$name]}"
    
    echo "Adding $name ($address)..."
    
    # Add key from seed phrase
    echo "$seed" | $POKERCHAIND keys add "$name" --recover --keyring-backend test --home "$HOME_DIR"
    
    # Add genesis account with b52 tokens and stake tokens
    $POKERCHAIND genesis add-genesis-account "$name" "${ACTOR_BALANCE}${DENOM},${STAKE_BALANCE}${STAKE_DENOM}" \
        --keyring-backend test --home "$HOME_DIR"
    
    # Create validator transaction for first 5 actors
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
echo "Test Actors Added:"
for name in "${!TEST_ACTORS[@]}"; do
    echo "  ✅ $name: ${TEST_ACTORS[$name]}"
done
echo ""
echo "💰 Each actor has:"
echo "  - $ACTOR_BALANCE $DENOM tokens"
echo "  - $STAKE_BALANCE $STAKE_DENOM tokens" 
echo ""
echo "🛡️  Validators created: 5 (alice, bob, charlie, diana, eve)"
echo ""
echo "📁 Files created:"
echo "  - ./genesis.json (project root)"
echo "  - ./app.toml (app configuration)"
echo "  - $HOME_DIR (full node setup)"
echo ""
echo "🚀 Ready to deploy to node1.block52.xyz!"