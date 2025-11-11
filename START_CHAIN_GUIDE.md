# Starting Pokerchain - Quick Reference

All chain startup methods automatically load bridge configuration from `.env` file.

## Prerequisites

**Required**: Create `.env` file with Alchemy API key

```bash
# Copy template
cp .env.example .env

# Edit .env and add your API key
# ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_KEY_HERE"
```

Get API key: https://dashboard.alchemy.com/

## Recommended: Use Wrapper Script

### Start Local Development Chain

```bash
./start-local-chain.sh
```

**Features:**
- ✅ Auto-loads `.env`
- ✅ Auto-updates bridge config after initialization
- ✅ Wraps `ignite chain serve` with all benefits
- ✅ Preserves existing state by default

**Options:**
```bash
./start-local-chain.sh --reset-once    # Reset state once
./start-local-chain.sh --verbose       # Verbose logging
./start-local-chain.sh --help          # Show help
```

## Alternative: Direct Ignite Command

If you prefer to run `ignite chain serve` directly:

```bash
# First time / fresh start
ignite chain serve --reset-once --verbose

# After first initialization, update bridge config
./update-bridge-config.sh

# Restart chain to apply bridge config
# Press Ctrl+C to stop, then:
ignite chain serve --verbose
```

**Note**: You must manually run `./update-bridge-config.sh` after initialization when using this method.

## Multi-Node Local Testnet

For testing with multiple validators:

```bash
./run-local-testnet.sh
```

**Features:**
- ✅ Auto-loads `.env`
- ✅ Runs 3 validator nodes on different ports
- ✅ Bridge config automatically injected for all nodes
- ✅ Good for consensus testing

**Ports:**
- Node 1: RPC 26657, API 1317
- Node 2: RPC 26667, API 1327
- Node 3: RPC 26677, API 1337

## Production / Remote Node

Start an existing production node:

```bash
./start-node.sh
```

**Features:**
- ✅ Auto-updates bridge config from `.env` before starting
- ✅ Works with systemd service or manual start
- ✅ Shows status if already running
- ✅ Checks RPC connectivity

## Configuration Flow

All methods follow this pattern:

```
1. Script starts
   ↓
2. Loads .env (if exists)
   ↓
3. Initializes chain (if needed)
   ↓
4. Updates ~/.pokerchain/config/app.toml
   (Injects ALCHEMY_URL from .env)
   ↓
5. Starts pokerchaind
   ↓
6. Bridge service reads app.toml
   ✅ Connected!
```

## Verifying Bridge Configuration

After starting, verify bridge is configured:

```bash
# Check running config
grep "ethereum_rpc_url" ~/.pokerchain/config/app.toml

# Test Alchemy connectivity
./test-bridge-connection.sh

# View bridge logs
journalctl -u pokerchaind -f | grep -i bridge
# OR (if running in foreground)
# Look for bridge startup messages in terminal
```

## Common Issues

### "ERROR: .env file not found"

**Solution:**
```bash
cp .env.example .env
# Edit .env and add your Alchemy API key
```

### Bridge not starting

**Check:**
1. `.env` file exists with ALCHEMY_URL set
2. Run `./update-bridge-config.sh` manually
3. Verify: `grep ethereum_rpc_url ~/.pokerchain/config/app.toml`
4. Restart chain

### Config keeps resetting

**If using `--reset-once`**: This wipes `~/.pokerchain/` directory

**Solution:** Don't use `--reset-once` after first initialization, or re-run `./update-bridge-config.sh` after each reset.

## Which Method Should I Use?

| Use Case | Recommended Method |
|----------|-------------------|
| **Local development** | `./start-local-chain.sh` |
| **Quick dev iteration** | `ignite chain serve` + manual `./update-bridge-config.sh` |
| **Testing consensus** | `./run-local-testnet.sh` |
| **Production node** | `./start-node.sh` (with systemd) |
| **CI/CD** | Custom script loading `.env` |

## Environment Variables Reference

### Required
- `ALCHEMY_URL` - Alchemy Base Chain RPC URL with API key

### Optional (for scripts)
- `VALIDATOR_HOST` - Remote validator hostname (default: node1.block52.xyz)
- `VALIDATOR_USER` - SSH user for remote validator (default: root)

## Next Steps

After starting the chain:

1. **Verify chain is running:**
   ```bash
   curl http://localhost:26657/status | jq
   ```

2. **Test bridge connectivity:**
   ```bash
   ./test-bridge-connection.sh
   ```

3. **Scan for deposits:**
   ```bash
   ./scan-bridge.sh
   ```

4. **Read full bridge docs:**
   - `BRIDGE_CONFIGURATION.md` - Setup and security
   - `BRIDGE_README.md` - Architecture and usage
   - `BRIDGE_TESTING_TRACKING.md` - Test logs

## Quick Commands Reference

```bash
# Start chain (recommended)
./start-local-chain.sh

# Stop chain
Ctrl+C (if foreground)
# OR
sudo systemctl stop pokerchaind (if systemd)

# Reset chain completely
rm -rf ~/.pokerchain
./start-local-chain.sh --reset-once

# Update bridge config
./update-bridge-config.sh

# Check status
curl http://localhost:26657/status

# View logs
tail -f ~/pokerchain-node.log
# OR
journalctl -u pokerchaind -f
```

## Help & Documentation

- **Setup**: `BRIDGE_CONFIGURATION.md`
- **Bridge Details**: `BRIDGE_README.md`
- **Test Tracking**: `BRIDGE_TESTING_TRACKING.md`
- **Validator Setup**: `VALIDATOR-SETUP.md`
- **General**: `readme.md`, `CLAUDE.md`
