#!/bin/bash

# Fix existing testnet for localhost multi-node operation
# This adds the necessary settings to allow multiple nodes on the same machine

OUTPUT_DIR="./test"

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: No testnet directory found at $OUTPUT_DIR"
    exit 1
fi

echo "Fixing localhost configuration for existing testnet..."
echo ""

NUM_NODES=$(ls -d $OUTPUT_DIR/node* 2>/dev/null | wc -l)

for i in $(seq 0 $((NUM_NODES - 1))); do
    CONFIG_FILE="$OUTPUT_DIR/node$i/config/config.toml"
    P2P_PORT=$((26656 + i))
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Fixing node$i..."
        
        # Enable duplicate IP (required for localhost)
        if grep -q "allow_duplicate_ip = false" "$CONFIG_FILE"; then
            sed -i.bak 's/allow_duplicate_ip = false/allow_duplicate_ip = true/g' "$CONFIG_FILE"
            echo "  ✓ Enabled allow_duplicate_ip"
        fi
        
        # Disable strict address book
        if grep -q "addr_book_strict = true" "$CONFIG_FILE"; then
            sed -i.bak 's/addr_book_strict = true/addr_book_strict = false/g' "$CONFIG_FILE"
            echo "  ✓ Disabled addr_book_strict"
        fi
        
        # Set external address
        if grep -q 'external_address = ""' "$CONFIG_FILE"; then
            sed -i.bak "s/external_address = \"\"/external_address = \"127.0.0.1:$P2P_PORT\"/g" "$CONFIG_FILE"
            echo "  ✓ Set external_address to 127.0.0.1:$P2P_PORT"
        fi
        
        echo ""
    else
        echo "Warning: Config file not found for node$i"
    fi
done

echo "✓ Fixed all node configurations"
echo ""
echo "Now restart your testnet:"
echo "  ./manage-testnet.sh stop"
echo "  ./manage-testnet.sh start"
echo "  ./manage-testnet.sh status"