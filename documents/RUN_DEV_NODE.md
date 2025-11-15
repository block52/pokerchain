# Developer Node Setup Guide

## Overview

The `run-dev-node.sh` script sets up and runs a **local read-only node** for development purposes. This node syncs with the production network and allows you to:

-   Query blockchain data locally
-   Test queries and transactions
-   Develop applications against a live network
-   Debug without affecting production

## Quick Start

### Basic Usage

```bash
./run-dev-node.sh
```

That's it! The script will:

1. ✅ Check/build the binary
2. ✅ Initialize the node (if needed)
3. ✅ Download genesis from node1.block52.xyz
4. ✅ Configure sync settings
5. ✅ Start the node in your terminal

### First Time Setup

```bash
# Clone your project
cd your-project

# Run the dev node script
./run-dev-node.sh
```

**Output:**

```
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║           🎲 Pokerchain Developer Node Setup 🎲                   ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Checking Binary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠ Binary not found

The pokerchaind binary was not found.

Build now? (y/n): y

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Building Binary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Building pokerchaind...
✓ Build successful: ./build/pokerchaind

[...initialization and configuration...]

Your developer node is configured and ready!

Node Information:
  Type: Read-only (non-validator)
  Home: /home/user/.pokerchain-dev
  Moniker: dev-node-laptop
  Syncing from: node1.block52.xyz

Endpoints:
  RPC:  http://127.0.0.1:26657
  API:  http://127.0.0.1:1317
  gRPC: 127.0.0.1:9090

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting Node
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Starting pokerchaind...
Press Ctrl+C to stop

[Node logs stream here...]
```

## Command-Line Options

### Show Help

```bash
./run-dev-node.sh --help
```

### Reset Node Data

```bash
./run-dev-node.sh --reset
```

Removes all existing data and starts fresh. Useful when:

-   Genesis has been updated
-   Node state is corrupted
-   You want a clean sync

### Run with PVM (Execution Layer)

```bash
./run-dev-node.sh --pvm
```

Runs both the chain and the PVM (Poker Virtual Machine) execution layer using Docker. This option:

-   ✅ Downloads the required Docker configuration files from the poker-vm repository
-   ✅ Optionally clones the full poker-vm repository for building
-   ✅ Starts the PVM backend service on port 8545
-   ✅ Provides a complete development environment with both layers

**Requirements:**

-   Docker must be installed and running
-   Docker Compose must be available

**Interactive Prompt:**
If you don't use the `--pvm` flag, the script will ask:

```
Do you want to run the PVM (Poker Virtual Machine) execution layer?

  1) Chain only (default)
  2) Chain + PVM (requires Docker)

Choose option [1-2, default: 1]:
```

**PVM Endpoints:**
When running with PVM, you'll have access to:

-   **RPC:** http://localhost:8545
-   **Health Check:** http://localhost:8545/health

**Managing PVM:**

```bash
# View PVM logs
docker compose -f /tmp/poker-vm-dev/docker-compose.yaml logs -f pvm

# Stop PVM (will auto-stop when you stop the node)
cd /tmp/poker-vm-dev && docker compose down
```

-   Node state is corrupted
-   You want a clean sync

### Use Different Sync Node

```bash
./run-dev-node.sh --sync-node node2.example.com
```

### Custom Home Directory

```bash
./run-dev-node.sh --home ~/.my-custom-dev-node
```

### Custom Moniker

```bash
./run-dev-node.sh --moniker "alice-dev-machine"
```

### Combined Options

```bash
./run-dev-node.sh --reset --sync-node node2.example.com --moniker "dev-v2"
```

## Node Configuration

### Default Settings

-   **Home Directory:** `~/.pokerchain-dev`
-   **Moniker:** `dev-node-<hostname>`
-   **Chain ID:** `pokerchain`
-   **Sync Node:** `node1.block52.xyz`
-   **Type:** Read-only (non-validator)

### Endpoints

| Service | URL                    | Purpose              |
| ------- | ---------------------- | -------------------- |
| RPC     | http://127.0.0.1:26657 | Tendermint RPC       |
| API     | http://127.0.0.1:1317  | REST API             |
| gRPC    | 127.0.0.1:9090         | gRPC endpoint        |
| PVM RPC | http://localhost:8545  | PVM RPC (with --pvm) |

### Developer-Friendly Features

The script automatically enables:

-   ✅ REST API with Swagger docs
-   ✅ Relaxed address book strictness
-   ✅ Proper persistent peer configuration
-   ✅ Minimum gas prices configured

## Using Your Dev Node

### Check Node Status

In another terminal:

```bash
# Quick status
pokerchaind status --home ~/.pokerchain-dev

# Detailed sync status
curl http://127.0.0.1:26657/status | jq .result.sync_info
```

**Output:**

```json
{
	"latest_block_height": "12345",
	"latest_block_time": "2025-01-02T14:30:00Z",
	"catching_up": false
}
```

### Query Blockchain Data

```bash
# Check account balance
pokerchaind query bank balances <address> --home ~/.pokerchain-dev

# List validators
pokerchaind query staking validators --home ~/.pokerchain-dev

# Get block
pokerchaind query block 12345 --home ~/.pokerchain-dev
```

### Use REST API

```bash
# Get node info
curl http://127.0.0.1:26657/status

# Query account via API
curl http://127.0.0.1:1317/cosmos/bank/v1beta1/balances/<address>

# API documentation (Swagger)
open http://127.0.0.1:1317/swagger/
```

### Test Transactions (Query Only)

```bash
# Simulate a transaction (doesn't broadcast)
pokerchaind tx bank send <from> <to> 100stake \
  --dry-run \
  --home ~/.pokerchain-dev
```

**Note:** Your dev node is read-only - you cannot send transactions to the network from it directly.

## Development Workflows

### Workflow 1: Application Development

```bash
# Terminal 1: Run dev node
./run-dev-node.sh

# Terminal 2: Develop your app
cd my-app
npm run dev  # Your app queries http://127.0.0.1:26657
```

### Workflow 2: Testing Queries

```bash
# Terminal 1: Run dev node
./run-dev-node.sh

# Terminal 2: Test queries
pokerchaind query bank total --home ~/.pokerchain-dev
curl http://127.0.0.1:1317/cosmos/bank/v1beta1/supply
```

### Workflow 3: Chain Debugging

```bash
# Terminal 1: Run dev node with logs visible
./run-dev-node.sh

# Terminal 2: Monitor specific events
curl -s http://127.0.0.1:26657/status | jq .result.sync_info
watch -n 5 'curl -s http://127.0.0.1:26657/status | jq .result.sync_info'
```

## Stopping the Node

### Graceful Stop

Press `Ctrl+C` in the terminal running the node.

**Output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Node Stopped
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Developer node has been stopped.

To start again, run:
  ./run-dev-node.sh
```

### Resume Later

Your data is preserved in `~/.pokerchain-dev`. Just run the script again:

```bash
./run-dev-node.sh
```

It will detect existing data and ask:

```
⚠ Node directory already exists: /home/user/.pokerchain-dev

Options:
  1) Keep existing data and configuration
  2) Reset and start fresh (delete all data)
  3) Cancel

Choose option [1-3]:
```

## Troubleshooting

### Binary Not Building

**Issue:** Make fails to build

```bash
❌ Build failed
```

**Solution:**

```bash
# Check Go installation
go version

# Check dependencies
go mod tidy
go mod download

# Try manual build
make build
```

### Cannot Connect to Sync Node

**Issue:**

```
❌ Failed to download genesis
```

**Solution:**

```bash
# Check if sync node is accessible
curl https://node1.block52.xyz/rpc/status

# Try different sync node
./run-dev-node.sh --sync-node node2.example.com

# Check firewall/network
ping node1.block52.xyz
```

### Node Not Syncing

**Issue:** Node stays at block 0 or "catching_up: true" for too long

**Check:**

```bash
# In another terminal, check logs
tail -f ~/.pokerchain-dev/pokerchaind.log

# Check peer connections
curl http://127.0.0.1:26657/net_info | jq .result.n_peers
```

**Solutions:**

```bash
# If no peers, check persistent_peers config
cat ~/.pokerchain-dev/config/config.toml | grep persistent_peers

# Reset and try again
./run-dev-node.sh --reset

# Try different sync node
./run-dev-node.sh --reset --sync-node node2.example.com
```

### Port Already in Use

**Issue:**

```
Error: Failed to listen on 0.0.0.0:26657
```

**Solution:**

```bash
# Check what's using the port
lsof -i :26657
lsof -i :26656
lsof -i :1317

# Stop conflicting process
kill <PID>

# Or use different ports (edit config.toml)
```

### Corrupted State

**Issue:** Node crashes or behaves strangely

**Solution:**

```bash
# Reset everything
./run-dev-node.sh --reset
```

## Advanced Usage

### Manual Configuration

If you need to manually configure settings:

```bash
# Initialize without starting
./run-dev-node.sh
# Press Ctrl+C after "Ready to Start"

# Edit configuration
nano ~/.pokerchain-dev/config/config.toml
nano ~/.pokerchain-dev/config/app.toml

# Start manually
pokerchaind start --home ~/.pokerchain-dev
```

### Multiple Dev Nodes

Run multiple dev nodes for testing:

```bash
# Node 1 - mainnet
./run-dev-node.sh --home ~/.pokerchain-dev-main --sync-node node1.block52.xyz

# Node 2 - testnet (in another terminal)
./run-dev-node.sh --home ~/.pokerchain-dev-test --sync-node testnet.example.com
```

**Note:** Ensure ports don't conflict!

### Background Mode

To run in background (using screen or tmux):

```bash
# Using screen
screen -S dev-node
./run-dev-node.sh
# Press Ctrl+A, then D to detach

# Reattach later
screen -r dev-node

# Using tmux
tmux new -s dev-node
./run-dev-node.sh
# Press Ctrl+B, then D to detach

# Reattach later
tmux attach -t dev-node
```

## File Structure

```
~/.pokerchain-dev/
├── config/
│   ├── genesis.json          # Chain genesis
│   ├── config.toml           # Node configuration
│   ├── app.toml              # App configuration
│   ├── node_key.json         # P2P node key
│   └── priv_validator_key.json  # (Not used - read-only node)
└── data/
    └── ...                   # Blockchain data
```

## Comparison: Dev Node vs Production Node

| Feature        | Dev Node              | Production Node       |
| -------------- | --------------------- | --------------------- |
| **Purpose**    | Development/testing   | Production validator  |
| **Type**       | Read-only             | Validator             |
| **Run Mode**   | Terminal (foreground) | systemd service       |
| **Home Dir**   | `~/.pokerchain-dev`   | `~/.pokerchain`       |
| **Signing**    | No                    | Yes (validator key)   |
| **Endpoints**  | localhost only        | Public (0.0.0.0)      |
| **Setup**      | One script            | Multi-step deployment |
| **Data Reset** | Easy (`--reset`)      | Requires backup       |

## Best Practices

### ✅ Do's

-   ✅ Use dev node for local development
-   ✅ Keep dev node data separate from production
-   ✅ Reset when genesis updates
-   ✅ Use for query testing
-   ✅ Monitor sync status regularly

### ❌ Don'ts

-   ❌ Don't use for production
-   ❌ Don't expect to submit transactions
-   ❌ Don't share validator keys (none exist)
-   ❌ Don't expose to internet
-   ❌ Don't run multiple instances on same ports

## Quick Reference

```bash
# Start dev node
./run-dev-node.sh

# Start fresh
./run-dev-node.sh --reset

# Check status
curl http://127.0.0.1:26657/status | jq .result.sync_info

# Query data
pokerchaind query bank balances <addr> --home ~/.pokerchain-dev

# Stop node
Ctrl+C

# Resume node
./run-dev-node.sh
```

## Support

If you encounter issues:

1. Check this guide's troubleshooting section
2. Reset and try again: `./run-dev-node.sh --reset`
3. Check sync node is accessible: `curl https://node1.block52.xyz/rpc/status`
4. Verify binary builds: `make build`

Happy developing! 🚀
