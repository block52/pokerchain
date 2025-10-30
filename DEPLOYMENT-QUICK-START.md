# Pokerchain Deployment - Quick Start

## 🚀 Deploy Master Node to node1.block52.xyz

### Single Command Deployment

```bash
./deploy-master-node.sh
```

This will:

-   ✅ Build fresh binary from source (→ `./build/pokerchaind`)
-   ✅ Stop existing service on node1
-   ✅ Backup old data
-   ✅ Upload new binary and configs
-   ✅ Initialize node with genesis and validator keys
-   ✅ Start pokerchaind service
-   ✅ Verify deployment

### Prerequisites

-   SSH access to root@node1.block52.xyz
-   Go installed locally for building
-   All config files in repo (genesis.json, app.toml, config.toml)
-   Validator keys in `.testnets/validator0/`

## 📊 Quick Status Check

```bash
# RPC Status
curl -s http://node1.block52.xyz:26657/status | jq '.result.sync_info'

# API Test
curl http://node1.block52.xyz:1317/cosmos/base/tendermint/v1beta1/node_info

# Swagger UI
open http://node1.block52.xyz:1317/swagger/
```

## 🔍 Monitor Node

```bash
# Service status
ssh root@node1.block52.xyz 'sudo systemctl status pokerchaind'

# Live logs
ssh root@node1.block52.xyz 'sudo journalctl -u pokerchaind -f'

# Get node ID for peers
ssh root@node1.block52.xyz 'pokerchaind tendermint show-node-id --home /root/.pokerchain'
```

## 🌐 Endpoints

| Endpoint | URL                                    |
| -------- | -------------------------------------- |
| P2P      | node1.block52.xyz:26656                |
| RPC      | http://node1.block52.xyz:26657         |
| API      | http://node1.block52.xyz:1317          |
| Swagger  | http://node1.block52.xyz:1317/swagger/ |

## 🎮 Node Details

-   **Chain ID**: pokerchain
-   **Moniker**: alice-validator
-   **Validator**: Alice (validator0)
-   **Genesis Hash**: f5ba780f55bd16f01c9c16ef70f6607ed92d9296512cc8f56f3d2eaab92c36f1

## 🔧 Common Tasks

### Restart Service

```bash
ssh root@node1.block52.xyz 'sudo systemctl restart pokerchaind'
```

### View Logs (last 100 lines)

```bash
ssh root@node1.block52.xyz 'sudo journalctl -u pokerchaind -n 100'
```

### Clean Restart (wipe data)

```bash
ssh root@node1.block52.xyz 'sudo systemctl stop pokerchaind && rm -rf /root/.pokerchain/data/* && sudo systemctl start pokerchaind'
```

## 💾 Build Directory

-   Location: `./build/`
-   Contains: Fresh binary built from source
-   Not committed to git (in .gitignore)
-   Created automatically on first deployment

## ⚠️ Important Notes

1. **Binary Source**: Always built from repository source, never from go/bin
2. **Backups**: Auto-created at `/root/pokerchain-backup-YYYYMMDD-HHMMSS/`
3. **Genesis**: Must match across all nodes (hash verification included)
4. **Validator Keys**: From `.testnets/validator0/` (Alice)

## 📚 Full Documentation

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete details.
