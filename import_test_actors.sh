#!/bin/bash

# Import Test Actors Script
# This script imports all 10 test actors with their real BIP39 seed phrases

set -e

echo "🎭 Importing Test Actors for Pokerchain Development"
echo "=================================================="

# Test actor data with real seed phrases
declare -A ACTORS_SEEDS=(
    ["alice"]="gather dirt tobacco middle december ramp brand invest cinnamon toilet genius small"
    ["bob"]="betray warfare kiwi finish victory fix assist credit dirt slam quick exit"
    ["charlie"]="submit damage swing tank comic car below differ glimpse screen husband edit"
    ["diana"]="erupt engage average middle blouse rotate ready inch citizen boy leader phone"
    ["eve"]="rapid fluid guess layer shy profit fish bus exclude canal soccer vast"
    ["frank"]="artwork follow adapt naive guard bench piece disagree ride prefer lonely stick"
    ["grace"]="hurdle pretty orchard advance town spatial barely cherry front perfect zone color"
    ["henry"]="hill prosper trial crazy apple night manage unhappy script envelope jar shadow"
    ["iris"]="museum accuse wage table rose claim shop frog area stem indoor hawk"
    ["jack"]="they brave obtain acquire mass pause jazz accident retreat save pistol inflict"
)

declare -A ACTORS_DESC=(
    ["alice"]="Conservative player, good for testing basic gameplay"
    ["bob"]="Aggressive player, good for testing betting strategies"
    ["charlie"]="Strategic player, good for testing complex scenarios"
    ["diana"]="Unpredictable player, good for testing edge cases"
    ["eve"]="Balanced player, good for testing standard gameplay"
    ["frank"]="High-stakes player, good for testing large bets"
    ["grace"]="Careful player, good for testing fold scenarios"
    ["henry"]="Lucky player, good for testing winning scenarios"
    ["iris"]="Passive player, good for testing check/call patterns"
    ["jack"]="Bluffer player, good for testing deception strategies"
)

# Check if pokerchaind is available
if ! command -v pokerchaind &> /dev/null; then
    echo "❌ Error: pokerchaind not found in PATH"
    echo "Please install pokerchaind first or add it to your PATH"
    exit 1
fi

echo "🔑 Importing test actors..."
echo ""

# Import each actor
for actor in "${!ACTORS_SEEDS[@]}"; do
    echo "Importing $actor (${ACTORS_DESC[$actor]})..."
    
    # Check if account already exists
    if pokerchaind keys show "$actor" --keyring-backend test &> /dev/null; then
        echo "⚠️  Account '$actor' already exists, skipping..."
    else
        # Import the account with the seed phrase
        echo "${ACTORS_SEEDS[$actor]}" | pokerchaind keys add "$actor" --recover --keyring-backend test
        echo "✅ Imported $actor"
    fi
    echo ""
done

echo "🎉 Test Actor Import Complete!"
echo ""
echo "📋 Summary:"
echo "----------"
pokerchaind keys list --keyring-backend test

echo ""
echo "💡 Usage Tips:"
echo "- Use --keyring-backend test for all development commands"
echo "- Add genesis accounts: pokerchaind genesis add-genesis-account <name> 1000000000000stake"
echo "- These accounts are for TESTING ONLY - never use on mainnet!"
echo ""
echo "🃏 Ready to test poker games!"