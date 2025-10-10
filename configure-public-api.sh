#!/bin/bash

# configure-public-api.sh
# Script to configure a pokerchain node for public API/RPC access

set -e

NODE_HOME="${HOME}/.pokerchain"
CONFIG_DIR="${NODE_HOME}/config"

echo "🔧 Configuring node for public API/RPC access..."

# Backup original configurations
echo "📋 Creating configuration backups..."
cp "${CONFIG_DIR}/config.toml" "${CONFIG_DIR}/config.toml.backup.$(date +%s)"
cp "${CONFIG_DIR}/app.toml" "${CONFIG_DIR}/app.toml.backup.$(date +%s)"

# Configure RPC server for external access
echo "🌐 Configuring RPC server (port 26657)..."
sed -i 's/laddr = "tcp:\/\/127\.0\.0\.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "${CONFIG_DIR}/config.toml"
sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/' "${CONFIG_DIR}/config.toml"

# Configure API server for external access  
echo "🚀 Configuring API server (port 1317)..."
sed -i 's/enable = false/enable = true/' "${CONFIG_DIR}/app.toml"
sed -i 's/swagger = false/swagger = true/' "${CONFIG_DIR}/app.toml"
sed -i 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/' "${CONFIG_DIR}/app.toml"

# Add CORS configuration to API if not present
if ! grep -q "enabled-unsafe-cors" "${CONFIG_DIR}/app.toml"; then
    echo "🔐 Adding CORS configuration..."
    sed -i '/\[api\]/a\\n# Enable CORS for external access\nenabled-unsafe-cors = true' "${CONFIG_DIR}/app.toml"
fi

echo "✅ Configuration completed!"
echo ""
echo "📝 Changes made:"
echo "  • RPC server: 127.0.0.1:26657 → 0.0.0.0:26657"
echo "  • API server: enabled and localhost:1317 → 0.0.0.0:1317"  
echo "  • Swagger UI: enabled"
echo "  • CORS: enabled for external access"
echo ""
echo "🔥 Restart your node to apply changes:"
echo "  pkill pokerchaind"
echo "  pokerchaind start --home ~/.pokerchain"
echo ""
echo "🧪 Test endpoints after restart:"
echo "  RPC:     curl http://localhost:26657/status"
echo "  API:     curl http://localhost:1317/cosmos/base/tendermint/v1beta1/node_info"
echo "  Swagger: http://localhost:1317/swagger/"