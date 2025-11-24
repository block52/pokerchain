# Join Game Script

This script joins a poker game/table on the blockchain using gRPC, without requiring the `pokerchaind` binary.

## How It Works

The script:
1. Derives a private key from the provided mnemonic seed phrase
2. Connects to the blockchain via gRPC (node.texashodl.net:9443)
3. Creates and signs a `MsgJoinGame` transaction
4. Broadcasts the transaction over the wire using gRPC

## Prerequisites

- Go 1.21 or higher
- Network access to node.texashodl.net
- An existing game/table to join
- Sufficient USDC balance for the buy-in
- Sufficient stake tokens for transaction fees

## Usage

### Build

From the pokerchain root directory:

```bash
go build -o join-game ./cmd/join-game
```

### Run

```bash
./join-game <game_id> <seat> <buy_in_amount>
```

**Arguments:**
- `game_id` - The game/table ID to join (hex string starting with 0x)
- `seat` - Seat number (0-8 for 9-max tables)
- `buy_in_amount` - Buy-in amount in uusdc (e.g., 500000000 = 500 USDC)

### Example

```bash
# Join game at seat 1 with 500 USDC buy-in
./join-game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 1 500000000
```

### One-liner (build + run)

```bash
go build -o join-game ./cmd/join-game && \
  ./join-game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 1 500000000
```

## Configuration

Edit `main.go` to change:

- **Mnemonic**: The seed phrase (currently hardcoded)
- **Chain ID**: `pokerchain`
- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`

## Example Output

```
Using address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg
Account number: 7, Sequence: 2

Joining game with parameters:
  Game ID: 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
  Seat: 1
  Buy-in: 500000000 uusdc

Broadcasting transaction...

Transaction Result:
{
  "txhash": "ABC123...",
  "logs": null,
  "events": null
}

✅ Transaction successful!
Transaction hash: ABC123...

You have joined game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 at seat 1 with 500000000 uusdc
```

## Get Game ID

To get a game ID, you can:

1. **Create a new game** using the `create-table` script
2. **Query existing games** via the API:
   ```bash
   curl https://node.texashodl.net/pokerchain/poker/v1/games | jq .
   ```

## Buy-in Requirements

The buy-in amount must be:
- Greater than or equal to the game's minimum buy-in
- Less than or equal to the game's maximum buy-in
- You must have sufficient USDC balance in your account

Example conversions:
- 100 USDC = `100000000` (100 * 10^6)
- 500 USDC = `500000000` (500 * 10^6)
- 1000 USDC = `1000000000` (1000 * 10^6)

## Verify Transaction

After running, verify the transaction was included:

```bash
# Query the transaction (replace TX_HASH)
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | jq .

# Check player_joined event
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | \
  jq '.tx_response.events[] | select(.type=="player_joined")'
```

## Common Issues

### "insufficient fees"

Make sure the fee is set to `stake` denomination with at least 300 stake.

### "game not found"

Double-check the game ID is correct and the game exists on-chain.

### "seat already occupied"

The seat you're trying to join is already taken. Try a different seat number.

### "insufficient buy-in"

Your buy-in amount is below the game's minimum. Check the game's min_buy_in parameter.

### "buy-in too high"

Your buy-in amount exceeds the game's maximum. Check the game's max_buy_in parameter.

### "insufficient balance"

You don't have enough USDC in your account for the buy-in. Fund your account first.

## Account Requirements

The account must have:
- Sufficient `stake` tokens for transaction fees (minimum 300 stake)
- Sufficient `uusdc` tokens for the buy-in amount
- The account must exist on-chain

## Customization

To use a different account, update the `mnemonic` constant in `main.go` with your 24-word seed phrase.
