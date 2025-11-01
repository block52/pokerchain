# Deploy Remote Sync Node

This guide explains how to deploy a read-only sync node to a remote Linux server.

## Overview

The `deploy-sync-node.sh` script automates the deployment of a Pokerchain sync node to any remote Linux server. The sync node:

-   Downloads and syncs blockchain data from the network
-   Provides RPC and API endpoints for querying
-   Does NOT participate in consensus (read-only)
-   Connects to `node1.block52.xyz` as a persistent peer

## Prerequisites

1. **Local Requirements:**

    - Go 1.21 or later installed
    - SSH access configured to the remote server
    - Network access to the remote server

2. **Remote Server Requirements:**
    - Ubuntu/Debian Linux (or compatible)
    - Root or sudo access
    - SSH server running
    - Minimum 2GB RAM, 20GB disk space
    - Ports 26656 (P2P), 26657 (RPC), 1317 (API) available

## Quick Start

### Using the Setup Menu (Recommended)

```bash
./setup-network.sh
```

Then select option **3) Remote Sync Node**

### Direct Script Usage

```bash
./deploy-sync-node.sh <REMOTE_HOST> [REMOTE_USER]
```

**Examples:**

```bash
# Deploy to a server with domain name
./deploy-sync-node.sh node2.example.com root

# Deploy to a server with IP address
./deploy-sync-node.sh 192.168.1.100 ubuntu

# Deploy using default user (root)
./deploy-sync-node.sh node2.example.com
```

## What the Script Does

The deployment script performs the following steps:

1. **Builds Binary** - Compiles `pokerchaind` from source
2. **Checks Configuration** - Verifies required files exist
3. **Tests Connectivity** - Confirms SSH access to remote server
4. **Stops Services** - Cleanly stops any running pokerchaind processes
5. **Backs Up Data** - Creates backup of existing data (if any)
6. **Uploads Binary** - Copies compiled binary to remote server
7. **Initializes Node** - Sets up node configuration and data directories
8. **Configures Peers** - Connects to `node1.block52.xyz` as persistent peer
9. **Sets Up Systemd** - Creates and enables systemd service
10. **Starts Service** - Launches the sync node

## Configuration

The sync node is automatically configured with:

-   **Chain ID:** `pokerchain`
-   **Moniker:** `<hostname>-sync` (e.g., `node2-sync`)
-   **Persistent Peer:** `a429c82669d8932602ca43139733f98c42817464@node1.block52.xyz:26656`
-   **Home Directory:** `/root/.pokerchain`
-   **Genesis File:** Copied from local `genesis.json`

## Monitoring

### Check Service Status

```bash
ssh root@<remote-host> 'systemctl status pokerchaind'
```

### View Logs

```bash
ssh root@<remote-host> 'journalctl -u pokerchaind -f'
```

### Check Sync Status

```bash
ssh root@<remote-host> 'curl -s http://localhost:26657/status | jq .result.sync_info'
```

### Monitor Block Height

```bash
# Watch block height in real-time
watch -n 5 'ssh root@<remote-host> "curl -s http://localhost:26657/status | jq .result.sync_info.latest_block_height"'
```

## Service Management

### Start Service

```bash
ssh root@<remote-host> 'systemctl start pokerchaind'
```

### Stop Service

```bash
ssh root@<remote-host> 'systemctl stop pokerchaind'
```

### Restart Service

```bash
ssh root@<remote-host> 'systemctl restart pokerchaind'
```

### Enable on Boot

```bash
ssh root@<remote-host> 'systemctl enable pokerchaind'
```

## Accessing the Node

Once deployed, you can access the node's endpoints:

### RPC Endpoint

```bash
curl http://<remote-host>:26657/status
```

### API Endpoint

```bash
curl http://<remote-host>:1317/cosmos/base/tendermint/v1beta1/node_info
```

### Query Block Height

```bash
curl -s http://<remote-host>:26657/status | jq '.result.sync_info.latest_block_height'
```

## Syncing Process

After deployment, the node will:

1. Connect to `node1.block52.xyz`
2. Begin downloading blocks from the network
3. Sync until caught up with the latest block
4. Continue to receive new blocks as they're produced

**Note:** Initial sync may take time depending on:

-   Network bandwidth
-   Number of blocks to sync
-   Server performance

## Troubleshooting

### Node Not Connecting to Peers

Check the logs:

```bash
ssh root@<remote-host> 'journalctl -u pokerchaind -n 50'
```

Verify persistent peer configuration:

```bash
ssh root@<remote-host> 'grep persistent_peers /root/.pokerchain/config/config.toml'
```

### Service Won't Start

Check service status:

```bash
ssh root@<remote-host> 'systemctl status pokerchaind'
```

Verify binary is installed:

```bash
ssh root@<remote-host> 'which pokerchaind && pokerchaind version'
```

### Sync Is Slow or Stalled

Check if node is catching up:

```bash
ssh root@<remote-host> 'curl -s http://localhost:26657/status | jq .result.sync_info.catching_up'
```

Check peer connections:

```bash
ssh root@<remote-host> 'curl -s http://localhost:26657/net_info | jq .result.n_peers'
```

### Reset and Resync

If you need to reset the node and start syncing from scratch:

```bash
ssh root@<remote-host> << 'EOF'
systemctl stop pokerchaind
pokerchaind tendermint unsafe-reset-all --home /root/.pokerchain
systemctl start pokerchaind
EOF
```

## Security Considerations

1. **Firewall:** Consider restricting RPC/API access:

    ```bash
    # Allow only specific IPs to access RPC
    ufw allow from <your-ip> to any port 26657
    ```

2. **HTTPS:** For production, use a reverse proxy (nginx/caddy) with SSL

3. **SSH Keys:** Use SSH key authentication instead of passwords

4. **User Permissions:** Consider running as non-root user in production

## Updating the Node

To update the binary on a deployed sync node:

```bash
# Build new binary locally
go build -o ./build/pokerchaind ./cmd/pokerchaind

# Copy to remote server
scp ./build/pokerchaind root@<remote-host>:/tmp/

# Install and restart on remote server
ssh root@<remote-host> << 'EOF'
systemctl stop pokerchaind
mv /tmp/pokerchaind /usr/local/bin/pokerchaind
chmod +x /usr/local/bin/pokerchaind
systemctl start pokerchaind
EOF
```

## Multiple Sync Nodes

You can deploy multiple sync nodes to different servers for:

-   Geographic distribution
-   Load balancing
-   High availability
-   Development/staging environments

Simply run the deployment script for each server:

```bash
./deploy-sync-node.sh node2.example.com
./deploy-sync-node.sh node3.example.com
./deploy-sync-node.sh staging.example.com
```

## Support

For issues or questions:

-   Check logs: `journalctl -u pokerchaind -f`
-   Review configuration: `/root/.pokerchain/config/`
-   Verify genesis matches: `sha256sum /root/.pokerchain/config/genesis.json`
