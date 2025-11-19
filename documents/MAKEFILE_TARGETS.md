# Makefile Targets

## Overview

The Makefile has been refactored to separate build operations from state management.

## Available Targets

### `make install` (default)

Builds and installs the `pokerchaind` binary **without** modifying any existing chain state.

**What it does:**

-   Verifies Go module dependencies
-   Compiles and installs `pokerchaind` to `$GOPATH/bin` (typically `~/go/bin`)
-   Does NOT touch genesis.json or chain data

**Use when:**

-   Setting up a sync node (keeps your fetched genesis intact)
-   Rebuilding after code changes
-   Installing on a fresh system

```bash
make install
# or simply
make
```

### `make clean`

Cleans build artifacts and caches.

**What it does:**

-   Clears Go build cache
-   Clears Go module cache
-   Removes the installed `pokerchaind` binary

**Use when:**

-   Need a completely fresh build
-   Troubleshooting build issues
-   Freeing up disk space

```bash
make clean
```

### `make clean-state`

Removes chain data and genesis file.

**What it does:**

-   Deletes `~/.pokerchain/data/` directory
-   Removes `~/.pokerchain/config/genesis.json`
-   Leaves the binary intact

**Use when:**

-   Want to reset the chain state
-   Switching between testnet/mainnet
-   Corrupted chain data needs cleanup

```bash
make clean-state
```

### `make init-local-validator`

Sets up a local validator node with minimal genesis.

**What it does:**

-   Copies `genesis.json` to `~/.pokerchain/config/genesis.json`
-   Creates `priv_validator_state.json` from template if it doesn't exist
-   Sets up directories for local development

**Use when:**

-   Running a local development validator
-   Testing changes with minimal genesis
-   Single-node local testing

```bash
make init-local-validator
```

## Common Workflows

### Setting up a sync node (connects to remote network)

```bash
# 1. Build the binary
make install

# 2. Run the setup script (it will fetch remote genesis)
./setup-sync-node.sh
```

### Setting up a local validator for development

```bash
# 1. Build the binary
make install

# 2. Initialize with minimal genesis
make init-local-validator

# 3. Start the node
./start-node.sh
```

### Resetting everything and starting fresh

```bash
# Clean build artifacts
make clean

# Clean chain state
make clean-state

# Rebuild
make install

# Set up your node (sync or local)
./setup-sync-node.sh
# OR
make init-local-validator
```

### Rebuilding after code changes

```bash
# Just rebuild - keeps your existing state
make install

# Restart your node
sudo systemctl restart pokerchaind
# OR
./start-node.sh
```

## Migration from Old Makefile

**Old behavior:** `make install` would automatically clean state and copy minimal genesis

**New behavior:** `make install` only builds the binary

**If you relied on the old behavior:**

```bash
# Old way (single command)
make install

# New way (two commands for local validator)
make install
make init-local-validator

# For sync nodes, use the setup script instead
make install
./setup-sync-node.sh
```

## Benefits of This Change

1. **Sync nodes work correctly** - `setup-sync-node.sh` can now fetch remote genesis without it being overwritten
2. **Explicit state management** - Separated concerns: building vs. state initialization
3. **Safer rebuilds** - Recompiling doesn't accidentally wipe your synced chain data
4. **Clearer intent** - Each target does one thing well
