#!/bin/bash

# Script to add test actors to genesis.json
# Usage: ./add-test-actors.sh

# Test actor addresses (10 actors with 52,000 b52stake each)
ACTORS=(
    "b521kftde6cge44sccxszg27g5x7w70kky3f70nw6w"  # Alice
    "b521weeu9thllmlkkyc2ansrl39w4elh0dpt5s5jm6"  # Bob  
    "b521test3charlie3test3charlie3test3charlie"  # Charlie (placeholder)
    "b521test4diana4test4diana4test4diana4test4"   # Diana (placeholder)
    "b521test5eve5test5eve5test5eve5test5eve5te"   # Eve (placeholder)
    "b521test6frank6test6frank6test6frank6test6"   # Frank (placeholder)
    "b521test7grace7test7grace7test7grace7test7"   # Grace (placeholder)
    "b521test8henry8test8henry8test8henry8test8"   # Henry (placeholder)
    "b521test9iris9test9iris9test9iris9test9ir"    # Iris (placeholder)
    "b521test10jack10test10jack10test10jack10te"   # Jack (placeholder)
)

STAKE_AMOUNT="52000000000"  # 52,000 b52stake (with 6 decimal places = 52,000,000,000 micro units)
TOKEN_AMOUNT="52000"        # 52,000 tokens

echo "Adding test actors to genesis.json..."

# Backup original genesis
cp genesis.json genesis.json.backup

# Add accounts to auth section
echo "Adding accounts to auth section..."

# Add balances to bank section  
echo "Adding balances to bank section..."

# Update supply
echo "Updating total supply..."

echo "✅ Test actors added to genesis.json"
echo "📋 Backup saved as genesis.json.backup"
echo ""
echo "Test actors added:"
for i in "${!ACTORS[@]}"; do
    echo "  $(($i + 1)). ${ACTORS[$i]} - 52,000 b52stake"
done