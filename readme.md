# pokerchain
**pokerchain** is a blockchain built using Cosmos SDK and Tendermint and created with [Ignite CLI](https://ignite.com/cli).

## Get started

```
ignite chain serve
```

`serve` command installs dependencies, builds, initializes, and starts your blockchain in development.

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

```bash
git clone https://github.com/block52/pokerchain.git
cd pokerchain
make install
```

#### Option 3: Quick Install Script
For remote nodes, you can use the provided installation script:

```bash
curl -sSL https://raw.githubusercontent.com/block52/pokerchain/main/install-from-source.sh | bash
```

`block52/pokerchain` should match the `username` and `repo_name` of the Github repository to which the source code was pushed. Learn more about [the install process](https://github.com/allinbits/starport-installer).

## Troubleshooting

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
- Configure proper firewall rules
- Use the provided `second-node.sh` script for node setup
- Verify genesis configuration matches across nodes

## Learn more

- [Ignite CLI](https://ignite.com/cli)
- [Tutorials](https://docs.ignite.com/guide)
- [Ignite CLI docs](https://docs.ignite.com)
- [Cosmos SDK docs](https://docs.cosmos.network)
- [Developer Chat](https://discord.gg/ignite)
