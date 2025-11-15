# Quick Start Guide

## Overview

This guide helps you quickly set up a pokerchain node in different configurations.

## Prerequisites

-   Go 1.24.7 or higher
-   Git
-   8GB+ RAM recommended
-   50GB+ disk space

---

## 🌐 Sync Node (Connect to Remote Network)

Set up a read-only node that syncs with the network:

```bash
# 1. Clone the repository
git clone https://github.com/block52/pokerchain.git
cd pokerchain

# 2. Run the automated setup
./setup-sync-node.sh
```

**What it does:**

-   Builds `pokerchaind` from source
-   Fetches genesis.json from remote node
-   Configures peer connections
-   Optionally sets up systemd service

**After setup:**

```bash
# Start the node (if using systemd)
sudo systemctl start pokerchaind

# Check status
sudo systemctl status pokerchaind

# View logs
journalctl -u pokerchaind -f
```

---

## 🏠 Local Validator (Development)

Set up a single-node validator for local testing:

```bash
# 1. Build the binary
make install

# 2. Initialize with minimal genesis
make init-local-validator

# 3. Start the node
./start-node.sh
```

**What you get:**

-   Local validator with minimal genesis
-   Single node for development/testing
-   Immediate block production

---

## 🔄 Common Tasks

### Rebuild After Code Changes

```bash
make install
sudo systemctl restart pokerchaind  # if using systemd
```

### Reset Chain State (Keep Config)

```bash
make clean-state
```

### Complete Fresh Install

```bash
# Clean everything
make clean
make clean-state

# Rebuild and reinitialize
make install

# Then choose your setup:
./setup-sync-node.sh        # For sync node
# OR
make init-local-validator    # For local validator
```

### Update to Latest Code

```bash
git pull
make install
sudo systemctl restart pokerchaind
```

---

## 📋 Makefile Targets

| Target                      | Purpose                   | When to Use               |
| --------------------------- | ------------------------- | ------------------------- |
| `make install`              | Build & install binary    | Always do this first      |
| `make clean`                | Remove build artifacts    | Build issues, fresh start |
| `make clean-state`          | Remove chain data         | Reset blockchain state    |
| `make init-local-validator` | Setup local dev validator | Local testing only        |

---

## 🔍 Troubleshooting

### Binary not found after install

```bash
# Add Go bin to PATH
export PATH="$HOME/go/bin:$PATH"
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
```

### Genesis mismatch after setup-sync-node

```bash
# The new Makefile doesn't overwrite genesis anymore, but if you have issues:
make clean-state
./setup-sync-node.sh
```

### Node won't start

```bash
# Check logs
journalctl -u pokerchaind -n 100

# Ensure validator state file exists (for local validator)
ls -la ~/.pokerchain/data/priv_validator_state.json

# If missing, reinitialize
make init-local-validator
```

### Build fails

```bash
# Clean and retry
make clean
go mod tidy
make install
```

---

## 📖 Additional Documentation

-   **Makefile Targets:** See [MAKEFILE_TARGETS.md](MAKEFILE_TARGETS.md)
-   **Scripts:** See [README_SCRIPTS.md](README_SCRIPTS.md)
-   **Validator Setup:** See [VALIDATOR_GUIDE.md](VALIDATOR_GUIDE.md)
-   **Next Player Query:** See [NEXT_PLAYER_QUERY.md](NEXT_PLAYER_QUERY.md)

---

## 🆘 Getting Help

1. Check existing documentation in the repo
2. Review script output for error messages
3. Check system logs: `journalctl -u pokerchaind -n 100`
4. Verify Go version: `go version`
5. Ensure sufficient disk space: `df -h`

---

## 🎯 Quick Command Reference

```bash
# Build
make install

# Local validator setup
make init-local-validator
./start-node.sh

# Sync node setup
./setup-sync-node.sh

# Clean state
make clean-state

# Query commands
pokerchaind query poker game <game-id>
pokerchaind query poker next-player-to-act <game-id>
pokerchaind query poker game-state <game-id>

# Service management (if using systemd)
sudo systemctl start pokerchaind
sudo systemctl stop pokerchaind
sudo systemctl status pokerchaind
journalctl -u pokerchaind -f
```
