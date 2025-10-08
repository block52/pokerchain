#!/bin/bash

# Clean Genesis Setup Script for Pokerchain
# Uses the exact test actors from TEST_ACTORS.md
# Creates validators and gives them b52 tokens for staking

set -e

# Configuration
POKERCHAIND="/home/lucascullen/go/bin/pokerchaind"
CHAIN_ID="pokerchain-test"
HOME_DIR="/home/lucascullen/.pokerchain"
KEYRING_BACKEND="test"

# Ask who should be the primary validator
echo "🚀 Pokerchain Genesis Setup"
echo "=========================="
echo ""
echo "Available test actors:"
echo "1. alice    - Conservative player"
echo "2. bob      - Aggressive player" 
echo "3. charlie  - Strategic player"
echo "4. diana    - Unpredictable player"
echo "5. eve      - Balanced player"
echo "6. frank    - High-stakes player"
echo "7. grace    - Careful player"
echo "8. henry    - Lucky player"
echo "9. iris     - Passive player"
echo "10. jack    - Bluffer player"
echo ""
read -p "Who should be the primary validator? (default: alice): " PRIMARY_VALIDATOR
PRIMARY_VALIDATOR=${PRIMARY_VALIDATOR:-alice}

echo ""
echo "Setting up genesis with $PRIMARY_VALIDATOR as primary validator..."
echo ""

# Clean start
echo "🧹 Cleaning previous setup..."
rm -rf "$HOME_DIR"

# Initialize the chain
echo "🔧 Initializing chain..."
$POKERCHAIND init validator1 --chain-id "$CHAIN_ID" --home "$HOME_DIR"

# Test actors with their exact seed phrases from TEST_ACTORS.md
declare -A ACTORS
ACTORS[alice]="cement shadow leave crash crisp aisle model hip lend february library ten cereal soul bind boil bargain barely rookie odor panda artwork damage reason"
ACTORS[bob]="vanish legend pelican blush control spike useful usage into any remove wear flee short october naive swear wall spy cup sort avoid agent credit"
ACTORS[charlie]="video short denial minimum vague arm dose parrot poverty saddle kingdom life buyer globe fashion topic vicious theme voice keep try jacket fresh potato"
ACTORS[diana]="twice bacon whale space improve galaxy liberty trumpet outside sunny action reflect doll hill ugly torch ride gossip snack fork talk market proud nothing"
ACTORS[eve]="raven mix autumn dismiss degree husband street slender maple muscle inch radar winner agent claw permit autumn expose power minute master scrub asthma retreat"
ACTORS[frank]="alpha satoshi civil spider expand bread pitch keen define helmet tourist rib habit cereal impulse earn milk need obscure ski purchase question vocal author"
ACTORS[grace]="letter stumble apology garlic liquid loyal bid board silver web ghost jewel lift direct green silk urge guitar nest erase remind jaguar decrease skin"
ACTORS[henry]="access execute loyal tag grid demise cloth desk dolphin pelican trumpet frown note level sibling dumb upon unfold wedding party success hint need fruit"
ACTORS[iris]="any antenna globe forget neglect race advice admit market guilt clay tunnel anxiety aim morning scrap visit sibling royal during proud flee maid fiscal"
ACTORS[jack]="digital option before hawk alcohol uncover expire faint enact shield bike uncle kangaroo museum domain heart purchase under answer topple timber hole height glance"

# Add all test actors to keyring
echo "🔑 Adding test actors to keyring..."
for name in "${!ACTORS[@]}"; do
    echo "Adding $name..."
    echo "${ACTORS[$name]}" | $POKERCHAIND keys add "$name" --recover --keyring-backend "$KEYRING_BACKEND" --home "$HOME_DIR"
done

# Create temporary files for gentx operations
TEMP_DIR="/tmp/pokerchain-genesis"
mkdir -p "$TEMP_DIR"

# Create token denominations for the actors
echo "💰 Setting up token denominations..."

# Add genesis accounts with both stake and b52 tokens
for name in "${!ACTORS[@]}"; do
    echo "Adding genesis account for $name..."
    
    # Add account with stake tokens and b52 tokens
    $POKERCHAIND genesis add-genesis-account "$name" "1000000000000stake,1000000000000b52" \
        --keyring-backend "$KEYRING_BACKEND" \
        --home "$HOME_DIR"
done

# Create validators (gentx) for the first 5 actors
echo "🏛️ Creating validators..."
VALIDATORS=("$PRIMARY_VALIDATOR" "bob" "charlie" "diana" "eve")

# Remove primary validator from the list if it's already there
VALIDATORS=($(printf '%s\n' "${VALIDATORS[@]}" | sort -u))

# Ensure primary validator is first
if [[ "$PRIMARY_VALIDATOR" != "alice" ]]; then
    VALIDATORS=("$PRIMARY_VALIDATOR" $(printf '%s\n' "${VALIDATORS[@]}" | grep -v "^$PRIMARY_VALIDATOR$"))
fi

for validator in "${VALIDATORS[@]}"; do
    echo "Creating gentx for $validator..."
    
    $POKERCHAIND genesis gentx "$validator" "500000000000b52" \
        --chain-id "$CHAIN_ID" \
        --moniker "$validator-validator" \
        --commission-rate "0.10" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "1" \
        --keyring-backend "$KEYRING_BACKEND" \
        --home "$HOME_DIR"
done

# Collect gentxs
echo "📋 Collecting gentxs..."
$POKERCHAIND genesis collect-gentxs --home "$HOME_DIR"

# Validate genesis
echo "✅ Validating genesis..."
$POKERCHAIND genesis validate --home "$HOME_DIR"

# Clean up temp files
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Genesis Setup Complete!"
echo "========================="
echo ""
echo "✅ Chain ID: $CHAIN_ID"
echo "✅ Primary Validator: $PRIMARY_VALIDATOR"
echo "✅ Total Actors: ${#ACTORS[@]}"
echo "✅ Total Validators: ${#VALIDATORS[@]}"
echo ""
echo "All actors have:"
echo "  - 1,000,000,000,000 stake tokens"
echo "  - 1,000,000,000,000 b52 tokens"
echo ""
echo "Validators (with 500B b52 staked):"
for validator in "${VALIDATORS[@]}"; do
    echo "  - $validator"
done
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