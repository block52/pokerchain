# Pokerchain Startup Scripts

This directory contains convenient startup scripts for running the Pokerchain blockchain with automatic logging.

## Scripts

### `start.sh`
**Use this for regular development and testing.**

```bash
./start.sh
```

- Preserves existing blockchain state
- Automatically creates `~/.pokerchain/logs/` directory
- Saves all output to `~/.pokerchain/logs/chain.log`
- Displays output in terminal simultaneously

### `start-with-logs.sh`
**Use this for first-time setup or when you want a fresh chain.**

```bash
./start-with-logs.sh
```

- Resets blockchain state (using `--reset-once` flag)
- Automatically creates `~/.pokerchain/logs/` directory
- Saves all output to `~/.pokerchain/logs/chain.log`
- Displays output in terminal simultaneously
- Generates new test accounts (alice, bob)

## Why Use These Scripts?

### Problem They Solve
When you run `ignite chain serve --reset-once`, it deletes the entire `~/.pokerchain` directory, including any logs directory you created. This means log files won't be saved properly.

### Solution
These scripts:
1. **Automatically create the logs directory** every time before starting the chain
2. **Use `tee` to save logs** while still showing output in the terminal
3. **Make it easy** - just run one command instead of remembering multiple steps

## Log Files

Logs are saved to:
```
~/.pokerchain/logs/chain.log
```

Full path:
```
/Users/alexmiller/.pokerchain/logs/chain.log
```

## Viewing Logs

### While chain is running (in another terminal):
```bash
# View last 50 lines
tail -50 ~/.pokerchain/logs/chain.log

# Watch logs in real-time
tail -f ~/.pokerchain/logs/chain.log

# Search for bridge activity
grep -i "bridge\|deposit\|mint" ~/.pokerchain/logs/chain.log
```

### After chain stops:
```bash
# View entire log file
cat ~/.pokerchain/logs/chain.log

# View with paging
less ~/.pokerchain/logs/chain.log
```

## Stopping the Chain

Press `Ctrl+C` in the terminal where the chain is running.

## Manual Alternative

If you prefer not to use the scripts:

```bash
# Create logs directory
mkdir -p ~/.pokerchain/logs

# Start with logging
ignite chain serve --reset-once -v 2>&1 | tee ~/.pokerchain/logs/chain.log
```

## Bridge Monitoring

The scripts automatically start the Ethereum bridge service, which polls Base Chain every 15 seconds for USDC deposits. Look for these log indicators:

- 🌉 Bridge Service Starting
- 🔍 Checking for new deposits
- 📋 Found deposit events
- ✅ Queued deposit for processing
- ❌ Error (if something went wrong)

## Troubleshooting

### Script won't run
```bash
# Make sure script is executable
chmod +x start.sh start-with-logs.sh
```

### Can't find logs
```bash
# Verify logs directory exists
ls -la ~/.pokerchain/logs/

# Check if tee is writing
ps aux | grep tee
```

### Chain not starting
```bash
# Check if port 26657 is already in use
lsof -i :26657

# View detailed error in logs
tail -100 ~/.pokerchain/logs/chain.log
```

## Related Documentation

- `CLAUDE.md` - Complete project documentation
- `docs/tom/WORKING_CHECKLIST.md` - Detailed working checklist with bridge debugging guide
- `BRIDGE_README.md` - Bridge deployment and configuration
- `VALIDATOR-SETUP.md` - Validator node setup
