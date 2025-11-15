# Bridge Configuration Guide

This document explains how to configure the Ethereum bridge service for Pokerchain.

## Overview

The bridge service monitors USDC deposits on Base Chain (Ethereum L2) and mints corresponding USDC tokens on Pokerchain. To protect sensitive API keys in this open-source repository, configuration uses environment variables.

## Quick Setup

### 1. Create Your `.env` File

```bash
cd /path/to/pokerchain
cp .env.example .env
```

### 2. Add Your Alchemy API Key

Edit `.env` and replace `YOUR_API_KEY_HERE` with your actual Alchemy API key:

```bash
ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_API_KEY"
```

**Get your API key from**: https://dashboard.alchemy.com/

### 3. Update Running Chain Configuration

If your chain is already initialized, run:

```bash
./update-bridge-config.sh
```

This will inject the Alchemy URL from `.env` into `~/.pokerchain/config/app.toml`.

### 4. Start/Restart Your Node

```bash
./start-node.sh
```

The start script will automatically update the bridge configuration from `.env` before starting.

## How It Works

### Configuration Flow

```
.env (your secret API key)
  ↓
update-bridge-config.sh (reads .env, updates app.toml)
  ↓
~/.pokerchain/config/app.toml (running chain config)
  ↓
pokerchaind bridge service (reads app.toml)
```

### Files Involved

| File | Purpose | Contains Secrets? | Committed? |
|------|---------|-------------------|------------|
| `.env` | Your actual API key | ✅ YES | ❌ NO (in .gitignore) |
| `.env.example` | Template showing format | ❌ NO | ✅ YES |
| `app.toml` (source) | Template config | ❌ NO (placeholder) | ✅ YES |
| `~/.pokerchain/config/app.toml` | Running chain config | ✅ YES (injected) | ❌ NO (local only) |

### Scripts

**Core Scripts:**
- `update-bridge-config.sh` - Injects Alchemy URL from `.env` into running chain's `app.toml`
- `start-node.sh` - Automatically calls `update-bridge-config.sh` before starting node

**Testing Utilities (also use `.env`):**
- `test-bridge-connection.sh` - Test Alchemy connectivity and verify bridge contract
- `scan-bridge.sh` - Scan for all deposit events on Base Chain
- `process-bridge.sh` - Process specific deposit by nonce

## Configuration Details

### Bridge Section in `app.toml`

The bridge service is configured in the `[bridge]` section of `app.toml`:

```toml
[bridge]
# Enable or disable the Ethereum bridge service
enabled = true

# Ethereum RPC URL (Base Chain)
# NOTE: This will be automatically populated from .env file
# Get your API key from: https://dashboard.alchemy.com/
ethereum_rpc_url = "https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE"

# CosmosBridge contract address on Base Chain
deposit_contract_address = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"

# USDC contract address on Base Chain
usdc_contract_address = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"

# Polling interval in seconds
polling_interval_seconds = 15

# Starting block number (block where CosmosBridge was deployed)
starting_block = 36469223
```

### Environment Variables

Only one environment variable is required in `.env`:

```bash
ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/<YOUR_API_KEY>"
```

## Alchemy API Tiers

### Free Tier
- ✅ Suitable for testing and development
- ⚠️ Limited to 10 block range for `eth_getLogs`
- ✅ Bridge service handles this automatically by querying incrementally

### Growth/Scale Tier (Recommended for Production)
- ✅ Larger block ranges
- ✅ Higher rate limits
- ✅ Better reliability

**Upgrade at**: https://dashboard.alchemy.com/

## Security Best Practices

### ✅ DO:
- Keep `.env` file local and never commit it
- Use separate API keys for development and production
- Rotate API keys periodically
- Monitor Alchemy usage dashboard for suspicious activity

### ❌ DON'T:
- Commit `.env` to git (it's in `.gitignore`)
- Share `.env` file in Slack/Discord/email
- Use production API keys on public testnets
- Hardcode API keys anywhere in the source code

## Troubleshooting

### "ERROR: .env file not found"

**Solution**: Create `.env` from template:
```bash
cp .env.example .env
# Then edit .env and add your API key
```

### "ERROR: ALCHEMY_URL not set in .env file"

**Solution**: Open `.env` and verify the format:
```bash
ALCHEMY_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
```

Make sure:
- Line is not commented out (no `#` at start)
- URL is in double quotes
- No extra spaces around `=`

### Bridge service not connecting

1. **Verify config was injected**:
   ```bash
   grep "ethereum_rpc_url" ~/.pokerchain/config/app.toml
   ```

2. **Test Alchemy connectivity**:
   ```bash
   ./test-bridge-connection.sh
   ```

3. **Check bridge service logs**:
   ```bash
   journalctl -u pokerchaind -f | grep -i bridge
   ```

4. **Manually update config**:
   ```bash
   ./update-bridge-config.sh
   ```

5. **Restart node**:
   ```bash
   sudo systemctl restart pokerchaind
   ```

### API key still in source code

If you see your API key hardcoded anywhere in committed files:

1. **Remove it immediately**:
   ```bash
   # Edit the file and replace with placeholder
   git add <file>
   git commit --amend
   ```

2. **Rotate the API key** (get new one from Alchemy dashboard)

3. **Update `.env`** with new key

4. **Report to team** if repository was already pushed

## Manual Configuration

If you prefer not to use `.env`, you can manually edit the config:

1. Open `~/.pokerchain/config/app.toml`
2. Find `[bridge]` section
3. Update `ethereum_rpc_url` with your Alchemy URL
4. Restart pokerchaind

**Note**: Manual changes to `~/.pokerchain/config/app.toml` may be overwritten when restarting the chain. Using `.env` + `update-bridge-config.sh` is recommended.

## Testing the Bridge

After configuration, test the bridge:

### 1. Test Alchemy Connectivity
```bash
./test-bridge-connection.sh
```

Expected output:
```
✅ PASSED: Alchemy is responding (current block: XXXXX)
✅ PASSED: Contract exists (code length: 18962 bytes)
```

### 2. Scan for Deposits
```bash
./scan-bridge.sh
```

This will show all deposits made to the bridge contract.

### 3. Check Bridge Service Status
```bash
curl http://localhost:26657/status | jq '.result.sync_info'
```

The bridge service will log its activity:
```bash
journalctl -u pokerchaind -f | grep bridge
```

## Production Deployment

For production validators:

1. **Use separate Alchemy API key** (not your dev key)
2. **Upgrade to paid Alchemy tier** for better reliability
3. **Set up monitoring** for bridge service logs
4. **Configure backups** of `.env` file (securely)
5. **Document API key location** for team members (use secret manager)

## Reference

**Bridge Contract Details:**
- Network: Base Chain (Chain ID: 8453)
- CosmosBridge: `0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B`
- USDC Token: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Deployment Block: `36469223`

**Links:**
- [View on Basescan](https://basescan.org/address/0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B)
- [Verified on Sourcify](https://repo.sourcify.dev/contracts/full_match/8453/0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B/)
- [Alchemy Dashboard](https://dashboard.alchemy.com/)
- [Bridge Documentation](./BRIDGE_README.md)

## Need Help?

- Review `BRIDGE_README.md` for bridge architecture details
- Check `BRIDGE_TESTING_TRACKING.md` for test logs
- Run `./test-bridge-connection.sh` for diagnostic information
