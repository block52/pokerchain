# Create Table Script

This script creates a poker table (game) on the blockchain using gRPC, without requiring the `pokerchaind` binary.

## How It Works

The script:
1. Derives a private key from the provided mnemonic seed phrase
2. Connects to the blockchain via gRPC (node.texashodl.net:9443)
3. Creates and signs a `MsgCreateGame` transaction
4. Broadcasts the transaction over the wire using gRPC

## Prerequisites

- Go 1.21 or higher
- Network access to node.texashodl.net

## Usage

### Build and Run

From the pokerchain root directory:

```bash
# Build the script
go build -o create-table ./cmd/create-table

# Run it
./create-table
```

### One-liner (build + run)

```bash
go build -o create-table ./cmd/create-table && ./create-table
```

## Configuration

Edit `main.go` to change:

- **Mnemonic**: The seed phrase (currently hardcoded)
- **Chain ID**: `pokerchain`
- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`

### Table Parameters

Default table settings (edit in `main.go`):

```go
MinBuyIn:   100_000_000,    // 100 USDC (6 decimals)
MaxBuyIn:   1_000_000_000,  // 1000 USDC
MinPlayers: 2,
MaxPlayers: 9,
SmallBlind: 500_000,        // 0.5 USDC
BigBlind:   1_000_000,      // 1 USDC
Timeout:    60,             // 60 seconds
GameType:   "nlhe",         // No-Limit Hold'em
```

## Example Output

```
Using address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg
Account number: 7, Sequence: 1

Creating game with parameters:
  Min Buy-in: 100000000 uusdc
  Max Buy-in: 1000000000 uusdc
  Small Blind: 500000 uusdc
  Big Blind: 1000000 uusdc
  Players: 2-9
  Game Type: nlhe

Broadcasting transaction...

Transaction Result:
{
  "txhash": "A8E1668ABAB64109B567A6DBBF741C4AF8051870F54EB3B995AF2BC1477F1902",
  "logs": null,
  "events": null
}

✅ Transaction successful!
Transaction hash: A8E1668ABAB64109B567A6DBBF741C4AF8051870F54EB3B995AF2BC1477F1902
```

## Verify Transaction

After running, you can verify the transaction was included in a block:

```bash
# Query the transaction (replace TX_HASH with your transaction hash)
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | jq .

# Or query just the game_created event
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | \
  jq '.tx_response.events[] | select(.type=="game_created")'
```

## Common Issues

### "insufficient fees; got: 7500uusdc required: 300stake"

Make sure the fee is set to `stake` denomination:
```go
txBuilder.SetFeeAmount(sdk.NewCoins(sdk.NewCoin("stake", math.NewInt(300))))
```

### "hrp does not match bech32 prefix: expected 'b52' got 'b521'"

The address prefix should be `b52`, not `b521`. Check the `addressPrefix` constant.

### gRPC connection errors

Ensure you can reach node.texashodl.net:9443:
```bash
nc -zv node.texashodl.net 9443
```

## Account Requirements

The account derived from the mnemonic must have:
- Sufficient `stake` tokens for transaction fees (minimum 300 stake)
- The account must exist on-chain (have been funded at least once)

## Customization

To use a different account, update the `mnemonic` constant in `main.go` with your 24-word seed phrase.

To create tables with different parameters, modify the `MsgCreateGame` fields in the `main()` function.
