# Node1 Public API Configuration Guide

## Problem Identified

Node1.block52.xyz is only accessible on P2P port 26656, but RPC (26657) and API (1317) ports are not accessible from external connections.

## Root Cause

1. **RPC Server** - Listening only on localhost (127.0.0.1:26657)
2. **API Server** - Disabled and listening only on localhost (localhost:1317)
3. **Swagger** - Disabled
4. **CORS** - May not be configured for external access

## Required Configuration Changes for Node1

### 1. config.toml Changes

```toml
[rpc]
# Change from: laddr = "tcp://127.0.0.1:26657"
laddr = "tcp://0.0.0.0:26657"

# Enable CORS for external access
cors_allowed_origins = ["*"]
cors_allowed_methods = ["HEAD", "GET", "POST"]
cors_allowed_headers = ["Origin", "Accept", "Content-Type", "X-Requested-With", "X-Server-Time"]
```

### 2. app.toml Changes

```toml
[api]
# Change from: enable = false
enable = true

# Change from: swagger = false
swagger = true

# Change from: address = "tcp://localhost:1317"
address = "tcp://0.0.0.0:1317"

# Ensure these are set for external access
max-open-connections = 1000
rpc-read-timeout = 10
rpc-write-timeout = 0

# Enable CORS
enabled-unsafe-cors = true
```

### 3. Optional: gRPC Configuration

```toml
[grpc]
# Enable gRPC if needed
enable = true
address = "0.0.0.0:9090"
```

## Firewall/Security Considerations

Ensure the server firewall allows:

-   Port 26657 (RPC)
-   Port 1317 (API/REST)
-   Port 9090 (gRPC, if enabled)

## Testing After Configuration

```bash
# Test RPC
curl http://node1.block52.xyz:26657/status

# Test API
curl http://node1.block52.xyz:1317/cosmos/base/tendermint/v1beta1/node_info

# Test Swagger UI
open http://node1.block52.xyz:1317/swagger/
```

## Current Status

-   ✅ P2P port 26656: Accessible
-   ❌ RPC port 26657: Connection refused
-   ❌ API port 1317: Connection refused
-   ❌ gRPC port 9090: Connection timeout

## Impact on Applications

Without these ports accessible:

-   No REST API queries possible
-   No RPC calls for blockchain data
-   No Swagger documentation access
-   Applications cannot interact with the blockchain via HTTP
-   Only P2P synchronization works
