# Block Production Testing Guide

## Overview

This guide explains how to verify that your Pokerchain node is actively producing blocks.

## Quick Test Methods

### Method 1: Interactive Menu (Recommended)

Use the setup-network.sh script's built-in verification:

```bash
./setup-network.sh
# Select option 5: "Verify Network Connectivity"
```

This will:

-   Check RPC/API accessibility
-   Display current network status
-   **Test block production over 10 seconds**
-   Show blocks/minute production rate
-   Provide troubleshooting tips if no blocks are produced

### Method 2: Standalone Script

Use the dedicated block production checker:

```bash
./check-block-production.sh [node] [port] [wait_time]

# Examples:
./check-block-production.sh                           # Default: node1.block52.xyz:26657, 10 seconds
./check-block-production.sh node1.block52.xyz         # Custom node
./check-block-production.sh node1.block52.xyz 26657 20  # Wait 20 seconds
```

### Method 3: Manual Testing

Quick manual check with curl:

```bash
# Get current block height
BLOCK1=$(curl -s http://node1.block52.xyz:26657/status | jq -r '.result.sync_info.latest_block_height')
echo "Block 1: $BLOCK1"

# Wait 10 seconds
sleep 10

# Get new block height
BLOCK2=$(curl -s http://node1.block52.xyz:26657/status | jq -r '.result.sync_info.latest_block_height')
echo "Block 2: $BLOCK2"

# Calculate difference
echo "Blocks produced: $((BLOCK2 - BLOCK1))"
```

## Understanding the Results

### ✅ Healthy Block Production

```
✅ BLOCK PRODUCTION ACTIVE!
   Produced 15 block(s) in 10 seconds
   Rate: ~90 blocks/minute
```

This means:

-   Your validator is active and signing blocks
-   The network consensus is working
-   Transactions can be processed

### ❌ No Blocks Produced

```
❌ NO BLOCKS PRODUCED
```

Possible causes:

1. **Validator Not Started**

    ```bash
    ssh node1.block52.xyz 'sudo systemctl status pokerchaind'
    ssh node1.block52.xyz 'sudo systemctl start pokerchaind'
    ```

2. **Genesis Time Not Reached**

    - Check genesis file: `cat ~/.pokerchain/config/genesis.json | jq .genesis_time`
    - If in the future, blocks won't start until that time

3. **No Voting Power**

    ```bash
    curl http://node1.block52.xyz:26657/validators | jq '.result.validators[]'
    ```

    - Ensure your validator has voting_power > 0

4. **Node at Block 0**

    - This usually means the genesis hasn't been initialized properly
    - Or the node hasn't started block production yet

5. **Configuration Issues**
    ```bash
    ssh node1.block52.xyz 'sudo journalctl -u pokerchaind -n 100 --no-pager'
    ```
    - Look for errors in the logs

## Common Scenarios

### Scenario 1: Fresh Deployment (Block 0)

If your node shows block height 0:

```bash
# Check if genesis time is in the future
ssh node1.block52.xyz "cat ~/.pokerchain/config/genesis.json | jq .genesis_time"

# Check node logs for startup
ssh node1.block52.xyz "sudo journalctl -u pokerchaind -n 50 --no-pager | grep -i genesis"

# Verify validator is configured
ssh node1.block52.xyz "cat ~/.pokerchain/config/genesis.json | jq '.app_state.genutil.gen_txs | length'"
```

**Solution**: The genesis time may be set in the future, or the validator needs to be added.

### Scenario 2: Node Was Working, Now Stopped

```bash
# Check if service is running
ssh node1.block52.xyz 'sudo systemctl is-active pokerchaind'

# If inactive, check why it stopped
ssh node1.block52.xyz 'sudo journalctl -u pokerchaind --since "1 hour ago" | tail -50'

# Restart if needed
ssh node1.block52.xyz 'sudo systemctl restart pokerchaind'

# Monitor startup
ssh node1.block52.xyz 'sudo journalctl -u pokerchaind -f'
```

### Scenario 3: Validator Present But Not Producing

```bash
# Check consensus state
curl http://node1.block52.xyz:26657/dump_consensus_state | jq '.result.round_state.height_vote_set[].prevotes_bit_array'

# Check if validator is in active set
curl http://node1.block52.xyz:26657/validators | jq '.result.validators[] | select(.voting_power != "0")'

# Verify validator key matches
ssh node1.block52.xyz 'pokerchaind tendermint show-validator'
```

## Automated Monitoring

### Continuous Monitoring Script

Create a monitoring loop:

```bash
#!/bin/bash
while true; do
    ./check-block-production.sh
    sleep 60
done
```

### Integration with Monitoring Tools

Export block height as a metric:

```bash
#!/bin/bash
# prometheus-export.sh
BLOCK_HEIGHT=$(curl -s http://node1.block52.xyz:26657/status | jq -r '.result.sync_info.latest_block_height')
echo "pokerchain_block_height{chain=\"pokerchain\"} $BLOCK_HEIGHT"
```

## Expected Block Times

Typical Cosmos SDK chains produce blocks:

-   **Fast chains**: 1-2 seconds per block (30-60 blocks/minute)
-   **Standard chains**: 5-7 seconds per block (8-12 blocks/minute)
-   **Conservative chains**: 10-15 seconds per block (4-6 blocks/minute)

Check your chain's configured block time:

```bash
ssh node1.block52.xyz "cat ~/.pokerchain/config/config.toml | grep -A 5 'timeout_commit'"
```

## Troubleshooting Commands Reference

```bash
# Node Status
curl http://node1.block52.xyz:26657/status | jq

# Validator Set
curl http://node1.block52.xyz:26657/validators | jq

# Network Info (peers)
curl http://node1.block52.xyz:26657/net_info | jq

# Consensus State
curl http://node1.block52.xyz:26657/dump_consensus_state | jq

# Genesis Info
curl http://node1.block52.xyz:26657/genesis | jq '.result.genesis'

# Node Info
curl http://node1.block52.xyz:26657/status | jq '.result.node_info'

# Sync Info
curl http://node1.block52.xyz:26657/status | jq '.result.sync_info'

# Service Status (on node)
ssh node1.block52.xyz 'sudo systemctl status pokerchaind'

# Recent Logs (on node)
ssh node1.block52.xyz 'sudo journalctl -u pokerchaind -n 100 --no-pager'

# Follow Logs (on node)
ssh node1.block52.xyz 'sudo journalctl -u pokerchaind -f'
```

## Next Steps

If blocks are not being produced after troubleshooting:

1. **Review deployment logs**: Check the initial deployment for errors
2. **Verify genesis file**: Ensure all validators are included
3. **Check network connectivity**: Ensure peers can connect
4. **Review validator power**: Confirm voting power is assigned
5. **Check genesis time**: Ensure it's in the past

For persistent issues, review:

-   `/home/lucascullen/GitHub/block52/pokerchain/DEPLOYMENT.md`
-   `/home/lucascullen/GitHub/block52/pokerchain/VALIDATOR_GUIDE.md`
-   Genesis configuration in `genesis.json`
