#!/bin/bash

# Simple genesis setup for pokerchain with alice as primary validator and all test actors with tokens

set -e

# Configuration
CHAIN_ID="pokerchain-test"
KEYRING_BACKEND="test"
HOME_DIR="$HOME/.pokerchain"
GOBIN=$(go env GOBIN)
if [ -z "$GOBIN" ]; then
    GOBIN=$(go env GOPATH)/bin
fi
POKERCHAIND="$GOBIN/pokerchaind"

# Check if pokerchaind exists
if [ ! -f "$POKERCHAIND" ]; then
    echo "❌ Error: pokerchaind not found at $POKERCHAIND"
    echo "Please install pokerchaind first with: make install"
    exit 1
fi

# Test actors from TEST_ACTORS.md (using exact names)
declare -A ACTORS=(
    ["alice"]="Conservative player"
    ["bob"]="Aggressive player"
    ["charlie"]="Strategic player"
    ["diana"]="Unpredictable player"
    ["eve"]="Balanced player"
    ["frank"]="High-stakes player"
    ["grace"]="Careful player"
    ["henry"]="Lucky player"
    ["iris"]="Passive player"
    ["jack"]="Bluffer player"
)

# Primary validator (alice)
PRIMARY_VALIDATOR="alice"

echo "🚀 Simple Pokerchain Genesis Setup"
echo "=================================="
echo ""
echo "🔧 Chain ID: $CHAIN_ID"
echo "🔑 Primary Validator: $PRIMARY_VALIDATOR"
echo "📁 Home Directory: $HOME_DIR"
echo ""

# Clean previous setup
echo "🧹 Cleaning previous setup..."
rm -rf "$HOME_DIR"

# Initialize chain with primary validator
echo "🔧 Initializing chain..."
$POKERCHAIND init "validator1" --chain-id "$CHAIN_ID" --home "$HOME_DIR" --default-denom stake

# Add all test actors to keyring
echo "🔑 Adding test actors to keyring..."

# Add primary validator key with correct test seed
echo "🔑 Adding alice key with correct test seed..."
echo "cement shadow leave crash crisp aisle model hip lend february library ten cereal soul bind boil bargain barely rookie odor panda artwork damage reason" | \
    $POKERCHAIND keys add alice --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding bob..."
echo "vanish legend pelican blush control spike useful usage into any remove wear flee short october naive swear wall spy cup sort avoid agent credit" | \
$POKERCHAIND keys add bob --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding charlie..."
echo "video short denial minimum vague arm dose parrot poverty saddle kingdom life buyer globe fashion topic vicious theme voice keep try jacket fresh potato" | \
$POKERCHAIND keys add charlie --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding diana..."
echo "twice bacon whale space improve galaxy liberty trumpet outside sunny action reflect doll hill ugly torch ride gossip snack fork talk market proud nothing" | \
$POKERCHAIND keys add diana --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding eve..."
echo "raven mix autumn dismiss degree husband street slender maple muscle inch radar winner agent claw permit autumn expose power minute master scrub asthma retreat" | \
$POKERCHAIND keys add eve --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding frank..."
echo "alpha satoshi civil spider expand bread pitch keen define helmet tourist rib habit cereal impulse earn milk need obscure ski purchase question vocal author" | \
$POKERCHAIND keys add frank --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding grace..."
echo "letter stumble apology garlic liquid loyal bid board silver web ghost jewel lift direct green silk urge guitar nest erase remind jaguar decrease skin" | \
$POKERCHAIND keys add grace --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding henry..."
echo "access execute loyal tag grid demise cloth desk dolphin pelican trumpet frown note level sibling dumb upon unfold wedding party success hint need fruit" | \
$POKERCHAIND keys add henry --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding iris..."
echo "any antenna globe forget neglect race advice admit market guilt clay tunnel anxiety aim morning scrap visit sibling royal during proud flee maid fiscal" | \
$POKERCHAIND keys add iris --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

echo "Adding jack..."
echo "digital option before hawk alcohol uncover expire faint enact shield bike uncle kangaroo museum domain heart purchase under answer topple timber hole height glance" | \
$POKERCHAIND keys add jack --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"

# Add genesis accounts with both stake and b52 tokens (1 trillion each)
echo "💰 Adding genesis accounts..."
for name in "${!ACTORS[@]}"; do
    echo "Adding genesis account for $name..."
    $POKERCHAIND genesis add-genesis-account "$name" "1000000000000stake,1000000000000b52" \
        --keyring-backend "$KEYRING_BACKEND" \
        --home "$HOME_DIR"
done

# Create validator gentx for alice only (500 billion b52 staked)
echo "🏛️ Creating validator (gentx)..."
$POKERCHAIND genesis gentx alice "500000000000b52" \
    --chain-id "$CHAIN_ID" \
    --moniker "alice-validator" \
    --commission-rate "0.10" \
    --commission-max-rate "0.20" \
    --commission-max-change-rate "0.01" \
    --min-self-delegation "1" \
    --keyring-backend "$KEYRING_BACKEND" \
    --home "$HOME_DIR"

# Collect gentxs
echo "📋 Collecting gentxs..."
$POKERCHAIND genesis collect-gentxs --home "$HOME_DIR"

# Validate genesis
echo "✅ Validating genesis..."
$POKERCHAIND genesis validate --home "$HOME_DIR"

echo ""
echo "🎉 Simple Genesis Setup Complete!"
echo "=================================="
echo ""
echo "✅ Chain ID: $CHAIN_ID"
echo "✅ Primary Validator: alice"
echo "✅ Total Actors: ${#ACTORS[@]}"
echo ""
echo "All actors have:"
echo "  - 1,000,000,000,000 stake tokens (1 trillion)"
echo "  - 1,000,000,000,000 b52 tokens (1 trillion)"
echo ""
echo "Alice is the primary validator with 500,000,000,000 b52 staked (500 billion)"
echo ""
echo "📁 Genesis file: $HOME_DIR/config/genesis.json"
echo "🔑 Keyring location: $HOME_DIR/keyring-$KEYRING_BACKEND/"
echo ""
echo "🚀 Ready to start the chain with:"
echo "   $POKERCHAIND start --home $HOME_DIR"
echo ""
echo "💡 To reset node1.block52.xyz:"
echo "   ./deploy-node.sh node1.block52.xyz root"
echo ""