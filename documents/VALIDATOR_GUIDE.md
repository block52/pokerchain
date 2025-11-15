# Pokerchain Validator Guide

Complete guide for running and maintaining a validator node on the Pokerchain network.

## 📋 Table of Contents

1. [Validator Responsibilities](#validator-responsibilities)
2. [Prerequisites](#prerequisites)
3. [Setup](#setup)
4. [Creating Your Validator](#creating-your-validator)
5. [Daily Operations](#daily-operations)
6. [Monitoring](#monitoring)
7. [Common Issues](#common-issues)
8. [Security Best Practices](#security-best-practices)
9. [Slashing Conditions](#slashing-conditions)

---

## Validator Responsibilities

As a validator, you are responsible for:

### ✅ Technical Requirements
- **Uptime**: Maintain >95% uptime to avoid slashing
- **Synced Node**: Keep your node fully synced with the network
- **Signing Blocks**: Actively participate in block signing
- **Software Updates**: Apply upgrades promptly
- **Monitoring**: Monitor node health 24/7

### ✅ Economic Requirements
- **Self-Delegation**: Maintain minimum self-delegation
- **Commission**: Set and maintain fair commission rates
- **Slashing Risk**: Understand and mitigate slashing risks

### ✅ Security Requirements
- **Key Management**: Secure validator keys (never share!)
- **Infrastructure**: Secure servers and network
- **Backups**: Maintain secure backups (except validator state!)
- **Access Control**: Limit access to validator systems

---

## Prerequisites

### Hardware Requirements

**Minimum**:
- CPU: 4 cores
- RAM: 8 GB
- Storage: 200 GB SSD
- Network: 100 Mbps

**Recommended**:
- CPU: 8 cores
- RAM: 16 GB
- Storage: 500 GB NVMe SSD
- Network: 1 Gbps

### Software Requirements
- Ubuntu 20.04+ or similar Linux distribution
- Go 1.24.7+
- pokerchaind built from source
- systemd for service management

### Network Requirements
- Static IP address (recommended)
- Open ports: 26656 (P2P), 26657 (RPC)
- Firewall configured (UFW recommended)
- DDoS protection (recommended for production)

### Financial Requirements
- Sufficient tokens for self-delegation
- Transaction fees for operations
- Buffer for potential slashing events

---

## Setup

### Quick Setup

```bash
# Run the validator setup script
./setup-validator-node.sh
```

The script will guide you through:
1. Selecting a validator profile
2. Generating or importing keys
3. Creating validator account
4. Configuring the node
5. Preparing create-validator transaction

### Manual Setup Steps

If you prefer manual setup:

```bash
# 1. Build pokerchaind
make install

# 2. Initialize node
pokerchaind init <moniker> --chain-id pokerchain

# 3. Copy genesis
cp genesis.json ~/.pokerchain/config/

# 4. Configure peers in config.toml
# Edit: ~/.pokerchain/config/config.toml
# Set: persistent_peers = "<node-id>@node1.block52.xyz:26656"

# 5. Create validator account
pokerchaind keys add <name> --keyring-backend test

# 6. Start node and wait for sync
pokerchaind start --minimum-gas-prices="0.01stake"
```

---

## Creating Your Validator

### Step 1: Ensure Node is Synced

```bash
# Check sync status
curl http://localhost:26657/status | jq '.result.sync_info'

# Wait until catching_up: false
# This may take several hours for a new node
```

### Step 2: Get Tokens

You need tokens for:
- Initial self-delegation (e.g., 100000000000stake)
- Transaction fees (e.g., 1000stake)

### Step 3: Create Validator Transaction

```bash
pokerchaind tx staking create-validator \
  --amount=100000000000stake \
  --pubkey=$(pokerchaind tendermint show-validator) \
  --moniker="your-validator-name" \
  --chain-id=pokerchain \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --from=<your-key-name> \
  --keyring-backend=test \
  --fees=1000stake \
  --yes
```

### Step 4: Verify Creation

```bash
# Get your validator address
VAL_ADDR=$(pokerchaind keys show <name> --bech val -a --keyring-backend=test)

# Query your validator
pokerchaind query staking validator $VAL_ADDR

# Check if in active set
pokerchaind query staking validators | grep $VAL_ADDR
```

---

## Daily Operations

### Starting Your Validator

```bash
# Using systemd
sudo systemctl start pokerchaind

# Or use the helper script
./start-node.sh
```

### Stopping Your Validator

```bash
# Using systemd
sudo systemctl stop pokerchaind

# Or use the helper script
./stop-node.sh
```

### Checking Status

```bash
# Node status
curl http://localhost:26657/status | jq

# Validator status
pokerchaind query staking validator $(pokerchaind keys show <n> --bech val -a --keyring-backend=test)

# Signing info
pokerchaind query slashing signing-info $(pokerchaind tendermint show-address)
```

### Viewing Logs

```bash
# Real-time logs
journalctl -u pokerchaind -f

# Last 100 lines
journalctl -u pokerchaind -n 100

# Search for errors
journalctl -u pokerchaind | grep -i error
```

---

## Monitoring

### Key Metrics to Monitor

#### 1. **Signing Performance**
```bash
# Check signing info
pokerchaind query slashing signing-info $(pokerchaind tendermint show-address)
```

Monitor:
- `missed_blocks_counter`: Should be low
- `jailed_until`: Should be "1970-01-01T00:00:00Z" (not jailed)

#### 2. **Node Sync Status**
```bash
curl -s http://localhost:26657/status | jq '.result.sync_info'
```

Monitor:
- `catching_up`: Should be `false`
- `latest_block_height`: Should increase regularly
- `latest_block_time`: Should be recent

#### 3. **Peer Connections**
```bash
curl http://localhost:26657/net_info | jq '.result.n_peers'
```

Monitor:
- Should have multiple peers (>5 recommended)

#### 4. **Validator Status**
```bash
pokerchaind query staking validator $VAL_ADDR
```

Monitor:
- `status`: Should be "BOND_STATUS_BONDED"
- `jailed`: Should be `false`
- `tokens`: Your voting power

### Alerting Setup

Create alerts for:
- Node stops responding
- Sync falls behind
- Peer count drops below threshold
- Missed blocks increases
- Validator gets jailed

Example monitoring script:

```bash
#!/bin/bash
# validator-monitor.sh

VAL_ADDR=$(pokerchaind keys show <n> --bech val -a --keyring-backend=test)

# Check if jailed
JAILED=$(pokerchaind query staking validator $VAL_ADDR | jq -r '.jailed')
if [ "$JAILED" = "true" ]; then
    echo "ALERT: Validator is jailed!"
    # Send notification
fi

# Check missed blocks
MISSED=$(pokerchaind query slashing signing-info $(pokerchaind tendermint show-address) | jq -r '.missed_blocks_counter')
if [ "$MISSED" -gt 50 ]; then
    echo "WARNING: Missed $MISSED blocks"
    # Send notification
fi

# Check sync status
CATCHING_UP=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up')
if [ "$CATCHING_UP" = "true" ]; then
    echo "WARNING: Node is not synced"
    # Send notification
fi
```

---

## Common Issues

### Issue 1: Validator is Jailed

**Symptoms**: 
- Validator status shows `jailed: true`
- Not signing blocks

**Causes**:
- Downtime (missed too many blocks)
- Double-signing

**Solution**:
```bash
# 1. Check why you were jailed
pokerchaind query slashing signing-info $(pokerchaind tendermint show-address)

# 2. Fix the underlying issue (sync, restart, etc.)

# 3. Wait for jail period to end (check jailed_until)

# 4. Unjail your validator
pokerchaind tx slashing unjail \
  --from=<name> \
  --keyring-backend=test \
  --chain-id=pokerchain \
  --fees=1000stake \
  --yes

# 5. Verify unjailed
pokerchaind query staking validator $VAL_ADDR | jq '.jailed'
```

### Issue 2: Not Signing Blocks

**Symptoms**:
- `missed_blocks_counter` increasing
- Not in active validator set

**Causes**:
- Node not synced
- Validator not in active set (insufficient voting power)
- Wrong validator keys

**Solution**:
```bash
# 1. Check sync status
curl http://localhost:26657/status | jq '.result.sync_info.catching_up'

# 2. Check if in active set
pokerchaind query staking validators | grep $(pokerchaind keys show <n> --bech val -a --keyring-backend=test)

# 3. Verify validator pubkey matches
pokerchaind tendermint show-validator
# Should match pubkey in: pokerchaind query staking validator $VAL_ADDR

# 4. Check node is running
systemctl status pokerchaind
```

### Issue 3: Low Voting Power

**Symptoms**:
- Out of active validator set
- Low rank in validator list

**Solution**:
```bash
# Delegate more tokens to your validator
pokerchaind tx staking delegate \
  $(pokerchaind keys show <n> --bech val -a --keyring-backend=test) \
  50000000000stake \
  --from=<n> \
  --keyring-backend=test \
  --chain-id=pokerchain \
  --fees=1000stake \
  --yes
```

---

## Security Best Practices

### 1. **Key Management**

#### Validator Keys (priv_validator_key.json)
```bash
# CRITICAL: This file must be protected!

# Set strict permissions
chmod 600 ~/.pokerchain/config/priv_validator_key.json

# Never share this file
# Never commit to git
# Never expose over network

# Backup securely (encrypted, offline storage)
# NEVER backup priv_validator_state.json to prevent double-signing
```

#### Account Keys
```bash
# Export for backup (encrypted)
pokerchaind keys export <name> --keyring-backend test

# Import on another system
pokerchaind keys import <name> <keyfile> --keyring-backend test
```

### 2. **Server Security**

```bash
# Use firewall
sudo ufw enable
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 26656/tcp  # P2P

# Change default SSH port
# Edit /etc/ssh/sshd_config
# Port 2222

# Use SSH keys, not passwords
# Disable root login
# Disable password authentication

# Keep system updated
sudo apt update && sudo apt upgrade -y

# Use fail2ban
sudo apt install fail2ban
```

### 3. **Monitoring & Alerts**

Set up monitoring for:
- Server resources (CPU, RAM, Disk)
- Network connectivity
- Process health (pokerchaind running)
- Validator status (signing, jailed)
- Block height (sync status)

### 4. **Backup Strategy**

**DO Backup**:
- Validator account keys (encrypted)
- Node private key (node_key.json)
- Configuration files

**DO NOT Backup**:
- priv_validator_state.json (can cause double-signing!)

**Backup Script Example**:
```bash
#!/bin/bash
BACKUP_DIR="/secure/backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup configs (exclude validator state!)
cp ~/.pokerchain/config/priv_validator_key.json $BACKUP_DIR/
cp ~/.pokerchain/config/node_key.json $BACKUP_DIR/
cp ~/.pokerchain/config/config.toml $BACKUP_DIR/
cp ~/.pokerchain/config/app.toml $BACKUP_DIR/

# Encrypt backup
tar czf - $BACKUP_DIR | gpg --encrypt -r your@email.com > backup.tar.gz.gpg

# DO NOT backup priv_validator_state.json!
```

### 5. **High Availability**

For production validators:

- **Sentry Nodes**: Run non-validator nodes as a buffer
- **DDoS Protection**: Use cloud DDoS protection services
- **Monitoring**: 24/7 monitoring with automatic alerts
- **Runbooks**: Document all procedures
- **On-Call**: Have someone available to respond

**⚠️ WARNING**: DO NOT run the same validator on multiple nodes simultaneously! This will cause double-signing and result in slashing and permanent jailing.

---

## Slashing Conditions

### Downtime Slashing

**Trigger**: Missing too many blocks in a window

**Parameters** (check in genesis):
- `signed_blocks_window`: Number of recent blocks checked
- `min_signed_per_window`: Minimum % that must be signed
- `downtime_jail_duration`: How long you're jailed
- `slash_fraction_downtime`: % of stake slashed

**Example**:
- Window: 100 blocks
- Minimum: 50% (must sign 50/100 blocks)
- Penalty: 1% slash + jail for 10 minutes

**Prevention**:
- Keep node running 24/7
- Monitor for issues
- Quick response to problems
- Redundancy/failover (careful with double-signing!)

### Double-Sign Slashing

**Trigger**: Signing two different blocks at the same height

**Parameters**:
- `slash_fraction_double_sign`: % of stake slashed (typically 5%)
- Usually results in permanent jailing (tombstoning)

**Causes**:
- Running validator on multiple nodes with same key
- Restoring from backup with old validator state
- Network partitions with active-active setup

**⚠️ CRITICAL**: This is the most serious offense!

**Prevention**:
- NEVER run same validator key on multiple nodes
- NEVER backup/restore priv_validator_state.json
- Use proper migrations when moving validators
- Implement safeguards to prevent simultaneous operation

### Recovery from Slashing

```bash
# 1. Fix the underlying issue first!

# 2. Check your validator status
pokerchaind query staking validator $VAL_ADDR

# 3. If jailed for downtime, wait for jail period
# Check: jailed_until field

# 4. Unjail
pokerchaind tx slashing unjail \
  --from=<n> \
  --keyring-backend=test \
  --chain-id=pokerchain \
  --fees=1000stake \
  --yes

# 5. Monitor to ensure you're signing again
pokerchaind query slashing signing-info $(pokerchaind tendermint show-address)

# Note: If tombstoned (permanent jail from double-signing),
# you cannot unjail and must create a new validator
```

---

## Resources

### Documentation
- [Cosmos Validator Guide](https://docs.cosmos.network/main/validators/overview)
- [Tendermint Documentation](https://docs.tendermint.com/)
- [Pokerchain Network Setup](./NETWORK_SETUP.md)

### Community
- Check GitHub issues for known problems
- Join validator channels for network updates

### Tools
- Validator monitoring dashboards
- Alert management systems
- Backup automation scripts

---

## Validator Checklist

### Before Going Live
- [ ] Hardware meets requirements
- [ ] Software is up to date
- [ ] Node is fully synced
- [ ] Validator keys are secure and backed up
- [ ] Account has sufficient tokens
- [ ] Monitoring is set up
- [ ] Alerts are configured
- [ ] Firewall is configured
- [ ] You understand slashing conditions
- [ ] You have a response plan for issues

### Daily Operations
- [ ] Check validator status
- [ ] Review missed blocks
- [ ] Check sync status
- [ ] Monitor resource usage
- [ ] Review logs for errors
- [ ] Verify peer connections

### Weekly Maintenance
- [ ] Update software if needed
- [ ] Review performance metrics
- [ ] Check backup integrity
- [ ] Review security logs
- [ ] Update documentation

### Emergency Response
- [ ] Have runbooks ready
- [ ] Know how to unjail
- [ ] Have backup access methods
- [ ] Contact list for escalation
- [ ] Tested recovery procedures

---

**Good luck with your validator! Remember: Security and uptime are paramount.**

*Last Updated: October 2025*