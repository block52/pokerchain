#!/bin/bash

# Query stake balance on node1 for address: b52168ketml7jed9gl7t2quelfkktr0zuuescapgde

ADDRESS="b52168ketml7jed9gl7t2quelfkktr0zuuescapgde"

echo "🔍 Querying stake balance for address: $ADDRESS"
echo ""

# Method 1: Direct pokerchaind query (run this on node1)
echo "📋 Command to run on node1 via SSH:"
echo "pokerchaind query bank balances $ADDRESS --node tcp://localhost:26657"
echo ""

# Method 2: Using REST API (if node1 API is accessible)
echo "🌐 Alternative via REST API (if node1 API is public):"
echo "curl -s http://node1.block52.xyz:1317/cosmos/bank/v1beta1/balances/$ADDRESS"
echo ""

# Method 3: Using RPC (if node1 RPC is accessible) 
echo "⚡ Alternative via RPC (if node1 RPC is public):"
echo "curl -s http://node1.block52.xyz:26657/abci_query?path=%22/store/bank/key%22"
echo ""

echo "💡 Expected output format:"
echo '{"balances":[{"denom":"stake","amount":"1000000"}],"pagination":{"next_key":null,"total":"0"}}'