# Node1 Validator Setup

## Validator Details

-   **Chain ID**: pokerchain
-   **Moniker**: node1-validator
-   **Node ID**: ac70ea1760f332d7c0202a2798c5cc485c0f4416
-   **Validator Address**: b52valoper1rgaelup3yzxt6puf593k5wq3mz8k0m2pnmy2le
-   **Account Address**: b521rgaelup3yzxt6puf593k5wq3mz8k0m2pvkfj9p

## Network Configuration

-   **RPC**: http://node1.block52.xyz:26657
-   **API**: http://node1.block52.xyz:1317
-   **P2P**: node1.block52.xyz:26656

## Validator Mnemonic (KEEP SECURE!)

```
decorate bus teach decrease alert erode flat spray switch give trial eternal remain track pluck fence latin sand airport giant umbrella reopen census door
```

## Files in Repository

-   `genesis-validator.json` - Genesis file with validator configuration
-   `validator-key.json` - Validator private key (consensus key)
-   `keyring-validator/` - Validator account keys

## Usage

To deploy this validator setup to a new node:

1. Copy files to node: `scp genesis-validator.json validator-key.json root@node:~/`
2. Copy keyring: `scp -r keyring-validator/ root@node:~/.pokerchain/keyring-test/`
3. Initialize node and replace genesis
4. Start validator: `pokerchaind start --home ~/.pokerchain`

## Quick Start Node1

```bash
ssh root@node1.block52.xyz
pokerchaind start --home ~/.pokerchain
```
