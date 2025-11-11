#!/bin/bash

# Update Bridge Config in Running Chain
# Reads ALCHEMY_URL from .env and injects it into ~/.pokerchain/config/app.toml

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
APP_TOML="$HOME/.pokerchain/config/app.toml"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}         🔧 Updating Bridge Configuration${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ ERROR: .env file not found at $ENV_FILE${NC}"
    echo ""
    echo "Please create .env file from .env.example:"
    echo "  cp .env.example .env"
    echo ""
    echo "Then add your Alchemy API key to the .env file."
    echo "Get your API key from: https://dashboard.alchemy.com/"
    exit 1
fi

# Load .env
source "$ENV_FILE"

# Check if ALCHEMY_URL is set
if [ -z "$ALCHEMY_URL" ]; then
    echo -e "${RED}❌ ERROR: ALCHEMY_URL not set in .env file${NC}"
    echo ""
    echo "Please add ALCHEMY_URL to your .env file:"
    echo '  ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE"'
    exit 1
fi

# Check if app.toml exists
if [ ! -f "$APP_TOML" ]; then
    echo -e "${YELLOW}⚠️  Warning: $APP_TOML not found${NC}"
    echo ""
    echo "The chain may not be initialized yet. Run 'ignite chain serve' first."
    echo ""
    echo "After initializing the chain, run this script again to update the bridge config."
    exit 1
fi

# Backup app.toml
BACKUP_FILE="${APP_TOML}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$APP_TOML" "$BACKUP_FILE"
echo -e "${GREEN}✅ Created backup: $BACKUP_FILE${NC}"

# Update ethereum_rpc_url in app.toml
# Using sed to replace the entire ethereum_rpc_url line
if grep -q "ethereum_rpc_url" "$APP_TOML"; then
    # Update existing line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax
        sed -i '' "s|ethereum_rpc_url = .*|ethereum_rpc_url = \"$ALCHEMY_URL\"|" "$APP_TOML"
    else
        # Linux sed syntax
        sed -i "s|ethereum_rpc_url = .*|ethereum_rpc_url = \"$ALCHEMY_URL\"|" "$APP_TOML"
    fi
    echo -e "${GREEN}✅ Updated ethereum_rpc_url in $APP_TOML${NC}"
else
    # Add to [bridge] section if not exists
    echo -e "${YELLOW}⚠️  ethereum_rpc_url not found, adding it to [bridge] section${NC}"

    # Find the [bridge] section and add ethereum_rpc_url
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^\[bridge\]/a\\
ethereum_rpc_url = \"$ALCHEMY_URL\"
" "$APP_TOML"
    else
        sed -i "/^\[bridge\]/a ethereum_rpc_url = \"$ALCHEMY_URL\"" "$APP_TOML"
    fi
    echo -e "${GREEN}✅ Added ethereum_rpc_url to $APP_TOML${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Bridge configuration updated successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configured Alchemy URL:"
echo "  $ALCHEMY_URL"
echo ""
echo -e "${YELLOW}⚠️  NOTE: You need to restart pokerchaind for changes to take effect${NC}"
echo ""
