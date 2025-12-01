# Adding a Validator to a Running Network

This guide documents the step-by-step process for adding a new validator to the Pokerchain network after it's already running.

## Overview

When the Pokerchain network is already running with one or more validators, you can add additional validators without restarting the chain or modifying genesis. The process involves:

1. Setting up a synced full node
2. Creating/importing a validator account
3. Funding the account with stake tokens
4. Submitting a `create-validator` transaction

## Prerequisites

- A server with the `pokerchaind` binary installed
- The node must be **fully synced** with the network
- The account must have sufficient `b52Token` for staking
- SSH access to both the new validator node and an existing validator (for stake transfer)

## Method 1: Using the Script (Recommended)

The easiest way to add a validator is using the automated script:

```bash
# From the pokerchain directory
./setup-network.sh
# Select option 13: Add Validator to Running Network
```

Or run the script directly:

```bash
./add-validator.sh
```

The script will:
1. Verify the node is synced
2. Help create/import a validator account
3. Transfer stake from an existing validator if needed
4. Submit the `create-validator` transaction
5. Verify the validator joins the active set

## Method 2: Manual Process

### Step 1: Set Up Sync Node

First, deploy a sync node that connects to the existing network:

```bash
./setup-network.sh
# Select option 2: Remote Sync Node
# Enter: node1.block52.xyz
# Sync from: node.texashodl.net
```

Wait for the node to fully sync:

```bash
ssh root@node1.block52.xyz "curl -s http://localhost:26657/status | jq '.result.sync_info'"
```

The node is synced when `catching_up` is `false`.

### Step 2: Create Validator Account

On the new validator node, create or import a validator account:

```bash
# Option A: Generate new account
ssh root@node1.block52.xyz "pokerchaind keys add validator --keyring-backend test"

# Option B: Import from mnemonic
ssh root@node1.block52.xyz "echo 'your 24 word mnemonic here' | pokerchaind keys add validator --recover --keyring-backend test"
```

Get the account address:

```bash
ssh root@node1.block52.xyz "pokerchaind keys show validator -a --keyring-backend test"
# Example output: b521rgaelup3yzxt6puf593k5wq3mz8k0m2pvkfj9p
```

### Step 3: Fund the Account

The validator account needs `b52Token` for staking. Transfer from an existing validator:

```bash
# On the source validator (node.texashodl.net)
pokerchaind tx bank send alice b521rgaelup3yzxt6puf593k5wq3mz8k0m2pvkfj9p 100000000001b52Token \
    --chain-id=pokerchain \
    --gas=auto \
    --gas-adjustment=1.5 \
    --yes
```

Verify the balance on the new validator:

```bash
ssh root@node1.block52.xyz "pokerchaind query bank balances b521rgaelup3yzxt6puf593k5wq3mz8k0m2pvkfj9p"
```

### Step 4: Get Validator Pubkey

Get the tendermint validator public key from the new node:

```bash
ssh root@node1.block52.xyz "pokerchaind comet show-validator"
# Example output: {"@type":"/cosmos.crypto.ed25519.PubKey","key":"ABC123..."}
```

### Step 5: Create Validator

Submit the create-validator transaction:

```bash
ssh root@node1.block52.xyz "pokerchaind tx staking create-validator \
    --amount=100000000000b52Token \
    --pubkey='{\"@type\":\"/cosmos.crypto.ed25519.PubKey\",\"key\":\"ABC123...\"}' \
    --moniker='validator-node1' \
    --commission-rate='0.10' \
    --commission-max-rate='0.20' \
    --commission-max-change-rate='0.01' \
    --min-self-delegation='1' \
    --from=validator \
    --chain-id=pokerchain \
    --gas=auto \
    --gas-adjustment=1.5 \
    --yes"
```

### Step 6: Verify Validator

Check that the validator was created successfully:

```bash
# Get validator address
ssh root@node1.block52.xyz "pokerchaind keys show validator --bech val -a --keyring-backend test"
# Example: b52valoper1...

# Query validator status
pokerchaind query staking validator b52valoper1...
```

The validator status should show:
- `BOND_STATUS_BONDED` - Validator is active and producing blocks
- `BOND_STATUS_UNBONDED` - Validator exists but not in active set (may need more stake)

## Example: Adding node1.block52.xyz as Validator

Here's a complete example for adding `node1.block52.xyz` as a validator, syncing from `node.texashodl.net`:

### 1. Deploy Sync Node

```bash
cd ~/GitHub/block52/pokerchain
./setup-network.sh
# Select: 2 (Remote Sync Node)
# Remote host: node1.block52.xyz
# Remote user: root
# Sync from: node.texashodl.net
```

### 2. Wait for Sync

```bash
# Monitor sync progress
ssh root@node1.block52.xyz "watch -n5 'curl -s http://localhost:26657/status | jq .result.sync_info'"
```

### 3. Add Validator

```bash
./setup-network.sh
# Select: 13 (Add Validator to Running Network)
# New validator host: node1.block52.xyz
# SSH user: root
# Account name: validator (or create new)
# Stake amount: 100000000000 (100B b52Token)
```

### 4. Verify

```bash
# Check validator is producing blocks
ssh root@node1.block52.xyz "journalctl -u pokerchaind -f | grep 'committed state'"

# List all validators
pokerchaind query staking validators
```

## Stake Requirements

The minimum stake to become a validator depends on the current validator set. To enter the active set, a validator needs:

1. At least `min_self_delegation` tokens (default: 1)
2. More stake than the validator with the least stake (if validator set is full)

Current network parameters:
- **Denomination**: `b52Token`
- **Recommended stake**: `100000000000` (100 billion units = 100,000 tokens with 6 decimals)

## Troubleshooting

### Node not syncing
```bash
# Check peers
ssh root@node1.block52.xyz "curl -s http://localhost:26657/net_info | jq '.result.n_peers'"

# Check logs
ssh root@node1.block52.xyz "journalctl -u pokerchaind -f"
```

### Validator not appearing
- Wait a few blocks after create-validator transaction
- Verify transaction succeeded: `pokerchaind query tx <TXHASH>`
- Check validator has enough stake

### Insufficient funds
```bash
# Check balance
pokerchaind query bank balances <ADDRESS>

# Transfer more tokens
pokerchaind tx bank send <SOURCE> <DEST> <AMOUNT>b52Token --chain-id=pokerchain --yes
```

## Security Notes

- Keep validator keys secure (priv_validator_key.json)
- Use keyring-backend `file` or `os` in production (not `test`)
- Ensure firewall allows only necessary ports (26656 for P2P)
- Monitor validator uptime to avoid slashing
