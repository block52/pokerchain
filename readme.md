# pokerchain

**pokerchain** is a blockchain built using Cosmos SDK and Tendermint and created with [Ignite CLI](https://ignite.com/cli).

## Requirements

### Go Version

-   **Go 1.24.0+** is required
-   **Recommended**: Go 1.24.7 or later
-   The project uses Cosmos SDK v0.53.2 which requires modern Go versions

### Dependencies

-   Cosmos SDK v0.53.2
-   Ignite CLI (latest version)
-   Required build tools are automatically managed via Go's `tool` directive

### Installation Check

Verify your Go version:

```bash
go version
# Should show: go version go1.24.7 linux/amd64 (or similar)
```

## Get started

```
ignite chain serve
```

`serve` command installs dependencies, builds, initializes, and starts your blockchain in development.

### Quick Test - Poker Functionality

Once your chain is running, test the poker module:

```bash
# 1. Import a test account (see TEST_ACTORS.md for seed phrases)
pokerchaind keys add alice --recover --keyring-backend test

# 2. Create a poker game
pokerchaind tx poker create-game 1000 10000 2 6 50 100 30 "texas-holdem" \
  --from alice --keyring-backend test --chain-id pokerchain --fees 1000token --yes

# 3. Query legal actions for a player
curl -X GET "http://localhost:1317/pokerchain/poker/v1/legal_actions/game-id/player-address"

# 4. Check game state
curl -X GET "http://localhost:1317/pokerchain/poker/v1/game/game-id"
```

### Configure

Your blockchain in development can be configured with `config.yml`. To learn more, see the [Ignite CLI docs](https://docs.ignite.com).

Chain ID:

```text
c4def329d68084abf24c63a1a2bb2055d9935d27
```

### Web Frontend

Additionally, Ignite CLI offers a frontend scaffolding feature (based on Vue) to help you quickly build a web frontend for your blockchain:

Use: `ignite scaffold vue`
This command can be run within your scaffolded blockchain project.

For more information see the [monorepo for Ignite front-end development](https://github.com/ignite/web).

## Release

To release a new version of your blockchain, create and push a new tag with `v` prefix. A new draft release with the configured targets will be created.

```
git tag v0.1
git push origin v0.1
```

After a draft release is created, make your final changes from the release page and publish it.

### Install

#### Option 1: Install from Release (Recommended)

To install the latest version of your blockchain node's binary, execute the following command on your machine:

```bash
curl https://get.ignite.com/block52/pokerchain@latest! | sudo bash
```

Or install a specific version:

```bash
curl https://get.ignite.com/block52/pokerchain@v0.1.0! | sudo bash
```

#### Option 2: Install from Source

If the above doesn't work or you want to build from source:

**Prerequisites**: Ensure you have Go 1.24.0+ installed:

```bash
# Check Go version
go version

# If you need to install/upgrade Go 1.24.7:
wget https://go.dev/dl/go1.24.7.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.7.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

**Build from source**:

```bash
git clone https://github.com/block52/pokerchain.git
cd pokerchain
make install
```

#### Option 3: Quick Install Script

For remote nodes, you can use the provided installation script (includes Go version check):

```bash
curl -sSL https://raw.githubusercontent.com/block52/pokerchain/main/install-from-source.sh | bash
```

`block52/pokerchain` should match the `username` and `repo_name` of the Github repository to which the source code was pushed. Learn more about [the install process](https://github.com/allinbits/starport-installer).

## Troubleshooting

### Go Version Issues

**Problem**: Build errors related to Go version compatibility
**Solution**: This project has been updated to work with Go 1.24.7 and Cosmos SDK v0.53.2

```bash
# Check your Go version
go version

# If you see errors about Go 1.23 vs 1.24 requirements:
# 1. Upgrade to Go 1.24.7 (see installation instructions above)
# 2. Run: go mod tidy
# 3. Try: ignite chain serve
```

**Recent Updates**:

-   Updated from Go 1.22.9 → Go 1.24.7 for full Cosmos SDK v0.53.2 compatibility
-   Uses Go's native `tool` directive for build tools (buf, protoc-gen-\*, etc.)
-   All dependencies now properly resolved for Go 1.24+

### Installation Issues

If you encounter "not found" errors with the curl installer:

1. **Wait for Release Processing**: After tagging a new version, GitHub Actions needs time to build and publish the release.

2. **Use Source Installation**:

    ```bash
    git clone https://github.com/block52/pokerchain.git
    cd pokerchain
    make install
    ```

3. **Manual Binary Copy**: If you have the binary on another machine:
    ```bash
    # Use the provided script
    ./install-binary.sh <remote-host> [remote-user]
    ```

### Network Configuration

For multi-node setups, ensure your nodes can communicate:

-   Configure proper firewall rules
-   Use the provided `second-node.sh` script for node setup
-   Verify genesis configuration matches across nodes

## Development Notes

### Test Actors

For testing poker functionality, we provide 10 pre-configured test actors with seed phrases. See [TEST_ACTORS.md](./TEST_ACTORS.md) for complete details including:

-   **Test accounts**: Alice, Bob, Charlie, Diana, Eve, Frank, Grace, Henry, Iris, Jack
-   **Seed phrases**: Ready-to-import mnemonic phrases for each account
-   **Usage instructions**: How to import accounts and add test funds
-   **Example commands**: Creating games and querying legal actions

**⚠️ Important**: These are test accounts only - never use on mainnet!

### Build Tools

The project uses Go 1.24's `tool` directive to automatically manage build dependencies:

-   `buf` for protocol buffer management
-   `protoc-gen-*` tools for code generation
-   `golangci-lint` for linting

All tools are automatically installed when running `go mod tidy` with Go 1.24+.

### Chain Configuration

-   **Chain ID**: Based on repository hash
-   **Cosmos SDK**: v0.53.2
-   **Consensus**: Tendermint
-   **Development ports**: 26657 (Tendermint), 1317 (API), 4500 (Faucet)

## Learn more

-   [Ignite CLI](https://ignite.com/cli)
-   [Tutorials](https://docs.ignite.com/guide)
-   [Ignite CLI docs](https://docs.ignite.com)
-   [Cosmos SDK docs](https://docs.cosmos.network)
-   [Developer Chat](https://discord.gg/ignite)
