# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pokerchain** is a Cosmos SDK blockchain built with Ignite CLI for poker gaming functionality with an Ethereum USDC bridge. The chain uses:
- **Cosmos SDK v0.53.2**
- **Go 1.24.0+** (recommended: 1.24.7)
- **CometBFT v0.38.17** for consensus
- **IBC v10.2.0** for cross-chain communication
- **Chain ID**: `pokerchain`
- **Address prefix**: `b52`
- **Native token denomination**: `b52Token` (changed from `stake` on Oct 18, 2025)

### Bridge Contract (Deployed)
- **Network**: Base Chain (Chain ID: 8453)
- **Contract**: CosmosBridge
- **Address**: `0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B`
- **Deployed**: 2025-10-06
- **Verified on Sourcify**: [View Contract](https://repo.sourcify.dev/contracts/full_match/8453/0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B/)
- **Basescan**: [View on Basescan](https://basescan.org/address/0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B)

## Essential Commands

### Development & Testing
```bash
# Start development chain with automatic logging (RECOMMENDED)
./start.sh                    # Preserves existing state
./start-with-logs.sh          # Resets chain state (use for first run)

# Or start manually
ignite chain serve            # Basic start (no logs saved)
ignite chain serve --reset-once -v   # Reset state once

# Build and install binary
make install

# Run all tests (includes govet, govulncheck, and unit tests)
make test

# Run unit tests only
make test-unit

# Run tests with race detection
make test-race

# Test with coverage report
make test-cover

# Run benchmarks
make bench
```

### Linting & Code Quality
```bash
# Run linter
make lint

# Run linter and auto-fix issues
make lint-fix

# Run go vet
make govet

# Check for vulnerabilities
make govulncheck
```

### Protocol Buffers
```bash
# Generate Go protobuf files
make proto-gen
# Or: ignite generate proto-go --yes

# Generate TypeScript client for SDK
ignite generate ts-client
# Generates: ts-client/pokerchain.poker.v1/ and Cosmos SDK modules
# Must copy to SDK: cp -r ts-client/* ../poker-vm/sdk/src/
```

### Build & Installation
```bash
# Clean build cache and binaries
make clean

# Full build and install
make all
```

### Blockchain Operations
```bash
# Query commands
pokerchaind query poker params
pokerchaind query poker list-games
pokerchaind query poker game [game-id]
pokerchaind query poker player-games [address]
pokerchaind query poker legal-actions [game-id]

# Check if Ethereum tx has been processed (bridge)
pokerchaind query poker is-tx-processed [eth-tx-hash]
pokerchaind query poker processed-transactions

# Transaction commands (examples)
pokerchaind tx poker create-game [params] --from alice
pokerchaind tx poker join-game [game-id] [stake] --from bob
pokerchaind tx poker perform-action [game-id] [action] --from alice
```

## Architecture

### Module Structure: `x/poker`

The poker module implements both poker game logic and an Ethereum USDC bridge:

**Keeper Layer** (`x/poker/keeper/`):
- `keeper.go` - Core keeper with collections-based state management
- `bridge_keeper.go` - Bridge-specific keeper methods (transaction tracking)
- `bridge_service.go` - Ethereum event monitoring service
- `msg_server_*.go` - Transaction message handlers (create_game, join_game, deal_cards, perform_action, leave_game, mint, burn)
- `query_*.go` - Query handlers for state reads

**State Management**:
- Uses Cosmos SDK v0.53 collections framework
- `ProcessedEthTxs` KeySet prevents bridge double-spending
- State stored in module-specific KVStore

**Types** (`x/poker/types/`):
- `message_*.go` - Message type definitions and validation
- `types.go` - Core types (games, players, actions)
- Protocol buffer generated files (`*.pb.go`, `*.pb.gw.go`)
- `expected_keepers.go` - Keeper interface definitions for dependency injection

### Ethereum Bridge Architecture

**Bridge Components**:
1. **BridgeService** (`bridge_service.go`): Background service that polls Ethereum L1 for USDC deposit events
2. **BridgeKeeper** (`bridge_keeper.go`): Handles minting, burning, and transaction tracking
3. **ProcessedEthTxs**: KeySet collection prevents double-processing of Ethereum transactions

**Bridge Flow**:
- Monitors Ethereum deposit contract for Transfer events
- Validates transaction hasn't been processed
- Mints corresponding USDC on Pokerchain
- Marks transaction as processed in state
- Supports manual `MsgMint` for authorized minting

**Configuration** (typically in app config):
```yaml
bridge:
  enabled: true
  ethereum_rpc_url: "https://eth.llamarpc.com"
  deposit_contract_address: "0x..."
  usdc_contract_address: "0xA0b86a33E6d3D24fDbCBFe003eDa2E26A6E73a60"
  polling_interval_seconds: 15
  starting_block: 0
```

### App Integration (`app/app.go`)

The main application wires together:
- All Cosmos SDK modules (auth, bank, staking, gov, etc.)
- IBC modules (transfer, ICA controller/host)
- Custom poker module with dependency injection
- Keeper references for cross-module calls

### Command Line (`cmd/pokerchaind/`)

- `cmd/commands.go` - Command registration
- `cmd/config.go` - Chain configuration
- `cmd/root.go` - Root command setup
- `cmd/testnet.go` - Testnet utilities
- `main.go` - Entry point

## Key Implementation Patterns

### Adding a New Message Type

1. **Define proto** in `proto/pokerchain/poker/v1/tx.proto`
2. **Run proto generation**: `make proto-gen`
3. **Implement validation** in `x/poker/types/message_*.go`
4. **Create handler** in `x/poker/keeper/msg_server_*.go`
5. **Register in codec** (auto-handled by protobuf)
6. **Add simulation** in `x/poker/simulation/*.go` (optional)

### State Management with Collections

The keeper uses collections framework (Cosmos SDK v0.53):
```go
// In keeper.go
ProcessedEthTxs: collections.NewKeySet(sb, types.ProcessedEthTxsKey, "processed_eth_txs", collections.StringKey)

// Usage
err := k.ProcessedEthTxs.Set(ctx, txHash)
exists := k.ProcessedEthTxs.Has(ctx, txHash)
```

### Keeper Dependencies

Keepers are injected via depinject:
- `BankKeeper` - Token transfers and balance queries
- `StakingKeeper` - Validator and delegation operations
- Authority address - Typically `x/gov` module account for governance

## Protocol Buffers

**Proto files location**: `proto/pokerchain/poker/v1/`
- `tx.proto` - Transaction messages
- `query.proto` - Query requests/responses
- `genesis.proto` - Genesis state
- `params.proto` - Module parameters

**Buf configuration**: Multiple codegen configs in `proto/`
- `buf.gen.gogo.yaml` - Cosmos-style gogo protobuf
- `buf.gen.swagger.yaml` - OpenAPI/Swagger docs
- `buf.gen.ts.yaml` - TypeScript client generation

**Generated files are committed** - Don't manually edit `*.pb.go` files.

**TypeScript Client Generation**:
- Command: `ignite generate ts-client`
- Output directory: `ts-client/`
- Key modules generated:
  - `pokerchain.poker.v1/` - Custom poker module types
  - `cosmos.auth.v1beta1/`, `cosmos.bank.v1beta1/`, etc. - Cosmos SDK types
- **SDK Integration**: Copy to SDK with `cp -r ts-client/* ../poker-vm/sdk/src/`
- **Dependencies required in SDK**: `@bufbuild/protobuf` (^2.10.0), `long` (^5.3.2)

## Testing

Tests use Cosmos SDK testing utilities:
- `testutil/` - Test helpers and mock keepers
- Keeper tests in `x/poker/keeper/*_test.go`
- Message validation tests in `x/poker/types/*_test.go`

Run specific test:
```bash
go test -v ./x/poker/keeper -run TestSpecificFunction
```

## Deployment & Operations

**Validator Setup**: See `VALIDATOR-SETUP.md` for validator configuration and network details.

**Bridge Setup**: See `BRIDGE_README.md` for Ethereum bridge deployment and monitoring.

**Systemd Service**:
```bash
# Setup systemd service
./setup-systemd.sh

# Service file: pokerchaind.service
```

**Helper Scripts**:
- `setup-network.sh` - Initialize network configuration
- `second-node.sh` - Add additional nodes
- `deploy-node.sh` - Deploy to remote nodes
- `connect-to-network.sh` - Connect to existing network
- `get-node-info.sh` - Query node information
- `install-from-source.sh` - Build and install from source
- `test-build.sh` - Verify build works

## Development Configuration

**Ignite config** (`config.yml`):
- Defines development accounts (alice, bob)
- Configures validators for local dev chain
- Sets default denomination and faucet settings

**Development ports**:
- 26657 - Tendermint RPC
- 1317 - Cosmos SDK REST API
- 4500 - Faucet (development)
- 26656 - P2P

## Important Notes

- **Go version**: Must use Go 1.24.0+. The project uses Go's `tool` directive for automatic build tool management (buf, protoc-gen-*, golangci-lint).
- **Protocol buffers**: Always use `make proto-gen` or `ignite generate proto-go --yes` to regenerate. Never edit generated files.
- **Collections framework**: State management uses the new collections API introduced in Cosmos SDK v0.50+. Avoid legacy KVStore patterns.
- **Bridge security**: ProcessedEthTxs KeySet is critical for preventing double-spending. Never remove or bypass this check.
- **Address prefix**: All addresses use `b52` prefix (e.g., `b521rgaelup3yzxt6puf593k5wq3mz8k0m2pvkfj9p`).
- **Module authority**: Poker module uses governance module account as authority for privileged operations.

## Common Issues

**Go version mismatch**: If you see build errors, verify Go 1.24.7+ is installed:
```bash
go version
# If needed, upgrade and run:
go mod tidy
```

**Proto generation fails**: Ensure Ignite CLI is up to date and run `go mod tidy` first.

**Bridge not starting**: Check Ethereum RPC URL is accessible and contract addresses are correct in configuration.
