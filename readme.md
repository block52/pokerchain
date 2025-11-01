# 🚀 Pokerchain Quick Start

Get your Pokerchain node up and running in minutes!

## 📦 Available Scripts

### Setup & Deployment

```bash
./setup-network.sh            # 🎛️  Interactive menu for network setup (master, sync, validator)
./deploy-master-node.sh       # 🌐 Deploy genesis/master node to remote server
./deploy-sync-node.sh         # 🔄 Deploy sync node to remote server
./setup-local-sync-node.sh    # �️  Setup a local sync node (dev/test)
./setup-validator-node.sh     # 👑 Setup validator node (interactive)
```

### Node Control

```bash
./start-node.sh               # ▶️  Start your local node
./stop-node.sh                # ⏹️  Stop your local node
```

### Network & Utility

```bash
./check-block-production.sh   # 🔍 Check if master node is producing blocks
./connect-to-network.sh       # 🔗 Connect your node to the network
./get-node-info.sh            # ℹ️  Fetch node status and info
./install-binary.sh           # 🛠️  Install pokerchaind binary to system
./install-from-source.sh      # 🛠️  Install pokerchaind from source
./test-build.sh               # ✅ Run build and script checks
```

### Documentation

```bash
QUICK_START.md                    # This file - quick reference
NETWORK_SETUP.md                  # Complete network setup guide
VALIDATOR_GUIDE.md                # Comprehensive validator guide
TEST_ACTORS.md                    # Test accounts with seed phrases
BLOCK-PRODUCTION-TESTING.md       # Guide for testing block production
```

## 🎯 Common Scenarios

### Scenario 1: First Time Setup (Developer)

**Goal**: Set up a local node for development

```bash
# Option A: Use the menu (easiest)
./setup-network.sh
# Choose option 2: Sync Node

# Option B: Direct setup
./setup-sync-node.sh
```

**What happens**:

1. Builds pokerchaind from source
2. Fetches genesis from node1.block52.xyz
3. Configures sync-only mode
4. Sets up systemd service (optional)
5. Ready to start!

---

### Scenario 2: Daily Development

**Goal**: Start node, develop, stop node

```bash
# Morning: Start your node
./start-node.sh

# Work on your code...
# Node is running on localhost:26657 (RPC) and localhost:1317 (API)

# Evening: Stop your node
./stop-node.sh
```

---

### Scenario 3: Deploy Genesis Node

**Goal**: Set up the main network node

```bash
./setup-network.sh
# Choose option 1: Genesis Node
# Choose option 2: Deploy to node1.block52.xyz
# Enter SSH username when prompted
```

**What happens**:

1. Builds pokerchaind locally
2. Copies binary to remote server
3. Deploys genesis and configs
4. Sets up UFW firewall
5. Starts systemd service
6. Verifies public endpoints

---

### Scenario 4: Set Up Validator Node

**Goal**: Become a validator and participate in consensus

**Prerequisites**:

-   Network is already running
-   You have tokens for staking
-   You understand validator responsibilities

```bash
./setup-validator-node.sh
```

**Interactive Setup**:

1. Choose validator profile (Bob, Charlie, Diana, Eve, or custom)
2. Select key management:
    - Generate new validator keys
    - Import existing keys
    - Use pre-configured test keys
3. Create or import validator account
4. Review validator creation parameters
5. Wait for node to sync
6. Broadcast create-validator transaction

**After Setup**:

```bash
# Start your validator node
./start-node.sh

# Wait for full sync (may take time)
curl http://localhost:26657/status | jq '.result.sync_info.catching_up'
# Wait until catching_up: false

# Check your validator status
pokerchaind query staking validator \
  $(pokerchaind keys show <validator-name> --bech val -a --keyring-backend=test)

# Monitor signing
pokerchaind query slashing signing-info \
  $(pokerchaind tendermint show-address)
```

**⚠️ Validator Responsibilities**:

-   Maintain high uptime (>95% recommended)
-   Keep node synced and updated
-   Monitor for slashing events
-   Secure your validator keys
-   Have backup/redundancy strategy

---

## 📊 Quick Commands

### Check if Node is Running

```bash
# Quick check
pgrep pokerchaind && echo "Running" || echo "Not running"

# Detailed status
curl -s http://localhost:26657/status | jq '.result.sync_info'
```

### View Sync Progress

```bash
# Current block height
curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'

# Are we syncing?
curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up'
```

### Check Logs

```bash
# If using systemd
journalctl -u pokerchaind -f

# Last 100 lines
journalctl -u pokerchaind -n 100

# Logs from last hour
journalctl -u pokerchaind --since "1 hour ago"
```

### Test Endpoints

```bash
# RPC endpoint
curl http://localhost:26657/status

# API endpoint
curl http://localhost:1317/cosmos/base/tendermint/v1beta1/node_info

# Check peers
curl http://localhost:26657/net_info | jq '.result.n_peers'
```

### Validator Commands

```bash
# Show your validator info
pokerchaind query staking validator \
  $(pokerchaind keys show <name> --bech val -a --keyring-backend=test)

# Check if you're in active validator set
pokerchaind query staking validators | jq '.validators[].operator_address' | grep $(pokerchaind keys show <name> --bech val -a --keyring-backend=test)

# Check signing status
pokerchaind query slashing signing-info $(pokerchaind tendermint show-address)

# Unjail if jailed
pokerchaind tx slashing unjail \
  --from=<name> \
  --keyring-backend=test \
  --chain-id=pokerchain \
  --fees=1000stake \
  --yes

# Delegate more stake
pokerchaind tx staking delegate \
  $(pokerchaind keys show <name> --bech val -a --keyring-backend=test) \
  1000000stake \
  --from=<name> \
  --keyring-backend=test \
  --chain-id=pokerchain \
  --fees=1000stake \
  --yes
```

---

## 🔧 Troubleshooting

### pokerchaind: command not found

```bash
# Add to PATH
export PATH="$HOME/go/bin:$PATH"
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc

# Rebuild
make install
```

### Node won't start

```bash
# Check logs
journalctl -u pokerchaind -n 50

# Verify initialization
ls -la ~/.pokerchain/config/

# Check if port is already in use
lsof -i :26657
```

### Not syncing / No peers

```bash
# Check persistent_peers
cat ~/.pokerchain/config/config.toml | grep persistent_peers

# Verify remote node is accessible
curl http://node1.block52.xyz:26657/status

# Re-run setup to fix config
./setup-sync-node.sh
```

### Permission errors

```bash
# Fix ownership
sudo chown -R $USER:$USER ~/.pokerchain

# Fix permissions
chmod 755 ~/.pokerchain/config
chmod 600 ~/.pokerchain/config/*.toml
chmod 644 ~/.pokerchain/config/genesis.json
```

---

## 📁 File Locations

```
~/.pokerchain/              # Node home directory
├── config/
│   ├── genesis.json        # Chain genesis state
│   ├── config.toml         # Node configuration
│   ├── app.toml            # App configuration
│   └── node_key.json       # Node identity
└── data/
    └── ...                 # Blockchain data
```

---

## 🌐 Network Information

### Genesis Node (node1.block52.xyz)

-   **RPC**: http://node1.block52.xyz:26657
-   **API**: http://node1.block52.xyz:1317
-   **Chain ID**: pokerchain
-   **Role**: Primary validator

### Local Sync Node

-   **RPC**: http://localhost:26657
-   **API**: http://localhost:1317
-   **Role**: Read-only sync node
-   **Purpose**: Local development & testing

---

## 💡 Tips

1. **Always use start-node.sh**: Don't manually run `pokerchaind start` unless needed
2. **Check sync status regularly**: Use `curl localhost:26657/status | jq`
3. **Logs are your friend**: When in doubt, check `journalctl -u pokerchaind -f`
4. **Systemd is better**: Let the system manage your node automatically
5. **Keep it running**: Sync nodes need to stay online to stay synced

---

## 🆘 Getting Help

### Quick Checks

```bash
# 1. Is pokerchaind installed?
which pokerchaind
pokerchaind version

# 2. Is node initialized?
ls ~/.pokerchain/config/genesis.json

# 3. Is node running?
./start-node.sh  # Will tell you current status

# 4. Can we reach the network?
curl http://node1.block52.xyz:26657/status
```

### Still stuck?

1. Check [NETWORK_SETUP.md](./NETWORK_SETUP.md) for detailed guide
2. Review logs: `journalctl -u pokerchaind -n 100`
3. Verify configs are correct
4. Re-run setup script

---

## 📚 Next Steps

Once your node is running:

1. **Test the poker module**

    ```bash
    # Import test accounts
    pokerchaind keys add alice --recover --keyring-backend test

    # Create a game
    pokerchaind tx poker create-game 1000 10000 2 6 50 100 30 "texas-holdem" \
      --from alice --keyring-backend test --chain-id pokerchain --fees 1000stake --yes
    ```

2. **Query blockchain data**

    ```bash
    # Get node info
    curl http://localhost:26657/status

    # Query accounts
    curl http://localhost:1317/cosmos/auth/v1beta1/accounts
    ```

3. **Build your application**
    - Use localhost:26657 for RPC calls
    - Use localhost:1317 for REST API
    - All standard Cosmos SDK queries work

---

## 🐳 Docker & Docker Compose

### Build and Run with Docker

```bash
# Build the Docker image
make docker-build

# Run a single node container
make docker-run
```

### Multi-Node with Docker Compose

```bash
# Start all services (node, validator, etc.)
make docker-compose-up

# Stop all services
make docker-compose-down
```

-   The main node exposes ports 26656 (P2P), 26657 (RPC), 1317 (REST API), 9090 (gRPC)
-   Config and genesis files are mounted from your repo into the container
-   Data is persisted in Docker volumes (`pokerchain-data`, `pokerchain-validator-data`)

#### Notes

-   You can customize the config and genesis files before running Docker Compose.
-   The default chain ID is `pokerchain` (set in docker-compose.yml and Makefile).
-   For multi-node/validator setups, use the `validator` profile in Docker Compose.
-   Healthchecks are included for the main node.

---

**Made with ❤️ by Block52**

For detailed documentation, see [NETWORK_SETUP.md](./NETWORK_SETUP.md)
