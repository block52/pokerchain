# Pokerchain Deployment Guide

## Master Node Deployment

### Overview

The master node (node1.block52.xyz) is deployed with the freshly built binary from the repository source code, not from developer's local go/bin directory.

### Deployment Script: `deploy-master-node.sh`

This script automates the complete deployment process:

1. **Builds Binary** - Compiles fresh binary into `./build/pokerchaind`
2. **Validates Configuration** - Checks all required files exist
3. **Stops Remote Services** - Gracefully stops existing pokerchaind
4. **Backs Up Old Data** - Creates timestamped backup
5. **Uploads Binary** - Copies to `/usr/local/bin/pokerchaind`
6. **Configures Node** - Installs genesis, configs, and validator keys
7. **Starts Service** - Launches via systemd
8. **Verifies Deployment** - Tests RPC endpoints

### Usage

```bash
./deploy-master-node.sh
```

### What Gets Deployed

#### Binary

-   **Source**: Built from repository source code
-   **Location**: `./build/pokerchaind` (locally), `/usr/local/bin/pokerchaind` (remote)
-   **Size**: ~159MB
-   **Built fresh** on each deployment

#### Configuration Files

-   **genesis.json** - Genesis state with accounts and initial setup
-   **app.toml** - Application configuration (API, gRPC, telemetry)
-   **config.toml** - Consensus and networking configuration
-   **priv_validator_key.json** - Validator private key (Alice/validator0)
-   **priv_validator_state.json** - Validator state tracking

#### Key Configuration Settings

**API Server (app.toml)**:

```toml
enable = true
swagger = true
address = "tcp://0.0.0.0:1317"
enabled-unsafe-cors = true
minimum-gas-prices = "0stake"
```

**RPC Server (config.toml)**:

```toml
laddr = "tcp://0.0.0.0:26657"
cors_allowed_origins = ["*"]
```

### Master Node Information

-   **Host**: node1.block52.xyz
-   **Chain ID**: pokerchain
-   **Moniker**: alice-validator
-   **Validator**: Alice (validator0 keys)

### Network Endpoints

| Service | URL                                    | Purpose                       |
| ------- | -------------------------------------- | ----------------------------- |
| P2P     | node1.block52.xyz:26656                | Peer-to-peer consensus        |
| RPC     | http://node1.block52.xyz:26657         | RPC queries and transactions  |
| API     | http://node1.block52.xyz:1317          | REST API for queries          |
| Swagger | http://node1.block52.xyz:1317/swagger/ | API documentation             |
| gRPC    | node1.block52.xyz:9090                 | gRPC queries (localhost only) |

### Monitoring

**Check service status**:

```bash
ssh root@node1.block52.xyz 'sudo systemctl status pokerchaind'
```

**View logs**:

```bash
ssh root@node1.block52.xyz 'sudo journalctl -u pokerchaind -f'
```

**Query node status**:

```bash
curl http://node1.block52.xyz:26657/status
```

**Query node info via API**:

```bash
curl http://node1.block52.xyz:1317/cosmos/base/tendermint/v1beta1/node_info
```

### Getting Node ID for Peers

To get the node ID for connecting other nodes:

```bash
ssh root@node1.block52.xyz 'pokerchaind tendermint show-node-id --home /root/.pokerchain'
```

Use this format for peers: `<node-id>@node1.block52.xyz:26656`

### Backup and Recovery

Each deployment creates a timestamped backup in `/root/pokerchain-backup-YYYYMMDD-HHMMSS/`

To restore from backup:

```bash
ssh root@node1.block52.xyz
sudo systemctl stop pokerchaind
rm -rf /root/.pokerchain
cp -r /root/pokerchain-backup-YYYYMMDD-HHMMSS /root/.pokerchain
sudo systemctl start pokerchaind
```

### Build Directory

The `./build/` directory contains deployment binaries and is excluded from git via `.gitignore`. This ensures:

-   No large binaries committed to repository
-   Fresh builds for each deployment
-   Developer test binaries in go/bin are not used

### Troubleshooting

**Service won't start**:

```bash
ssh root@node1.block52.xyz 'sudo journalctl -u pokerchaind -n 100'
```

**Genesis hash mismatch**:
Verify local and remote genesis files match:

```bash
sha256sum ./genesis.json
ssh root@node1.block52.xyz 'sha256sum /root/.pokerchain/config/genesis.json'
```

**API not responding**:
Check firewall allows ports 26657 and 1317, and verify API is enabled in app.toml.

**Clean restart**:

```bash
ssh root@node1.block52.xyz 'sudo systemctl stop pokerchaind && rm -rf /root/.pokerchain/data/* && sudo systemctl start pokerchaind'
```

### Security Notes

-   Validator keys are deployed from `.testnets/validator0/`
-   Private keys have 600 permissions
-   Public API is enabled with CORS for development
-   For production, restrict CORS and consider firewall rules

### Next Steps

1. Deploy additional validator nodes
2. Configure peer connections between nodes
3. Set up monitoring and alerting
4. Configure backup automation
5. Implement key management security
