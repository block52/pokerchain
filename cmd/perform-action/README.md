# Perform Action Script

This script performs poker actions (fold, call, check, bet, raise) on the blockchain using gRPC, without requiring the `pokerchaind` binary.

## How It Works

The script:
1. Derives a private key from the provided mnemonic seed phrase
2. Connects to the blockchain via gRPC (node.texashodl.net:9443)
3. Creates and signs a `MsgPerformAction` transaction
4. Broadcasts the transaction over the wire using gRPC

## Prerequisites

- Go 1.21 or higher
- Network access to node.texashodl.net
- An active game where you are seated
- It must be your turn to act
- Sufficient stake tokens for transaction fees

## Usage

### Build

From the pokerchain root directory:

```bash
go build -o perform-action ./cmd/perform-action
```

### Run

```bash
./perform-action <game_id> <action> [amount]
```

**Arguments:**
- `game_id` - The game/table ID (hex string starting with 0x)
- `action` - The poker action: `fold`, `call`, `check`, `bet`, or `raise`
- `amount` - Amount in uusdc (required only for `bet` and `raise`)

## Poker Actions

### Fold
Forfeit your hand and cards.

```bash
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 fold
```

### Call
Match the current bet.

```bash
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 call
```

### Check
Pass the action without betting (only valid when no bet is required).

```bash
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 check
```

### Bet
Place a bet (when no bet exists).

```bash
# Bet 1 USDC
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 bet 1000000

# Bet 5 USDC
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 bet 5000000
```

### Raise
Increase the current bet.

```bash
# Raise to 10 USDC
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 raise 10000000

# Raise to 50 USDC
./perform-action 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 raise 50000000
```

## Configuration

Edit `main.go` to change:

- **Mnemonic**: The seed phrase (currently hardcoded)
- **Chain ID**: `pokerchain`
- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`

## Amount Conversions

USDC uses 6 decimal places:

- 0.5 USDC = `500000` (0.5 * 10^6)
- 1 USDC = `1000000` (1 * 10^6)
- 5 USDC = `5000000` (5 * 10^6)
- 10 USDC = `10000000` (10 * 10^6)
- 100 USDC = `100000000` (100 * 10^6)

## Example Output

```
Using address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg
Account number: 7, Sequence: 3

Performing action:
  Game ID: 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
  Action: raise
  Amount: 5000000 uusdc

Broadcasting transaction...

Transaction Result:
{
  "txhash": "DEF456...",
  "logs": null,
  "events": null
}

✅ Transaction successful!
Transaction hash: DEF456...

Performed raise for 5000000 uusdc in game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
```

## Verify Transaction

After performing an action, verify it was included:

```bash
# Query the transaction (replace TX_HASH)
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | jq .

# Check action_performed event
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | \
  jq '.tx_response.events[] | select(.type=="action_performed")'
```

## Common Issues

### "not your turn"

Wait for other players to act. It must be your turn to perform an action.

### "invalid action"

The action you're trying to perform is not valid in the current game state:
- Can't `check` when there's a bet to call
- Can't `call` when there's no bet
- Can't `bet` when there's already a bet (use `raise` instead)

### "insufficient balance"

You don't have enough chips at the table for the bet/raise amount.

### "game not found"

The game ID is incorrect or the game has ended.

### "player not in game"

You must join the game first using the `join-game` script.

## Action Rules

- **Fold**: Always allowed when it's your turn
- **Check**: Only when there's no bet to call
- **Call**: Only when there's a bet to match
- **Bet**: Only when no bet exists in the current round
- **Raise**: Only when there's already a bet to raise

## Betting Limits

Your bet/raise amounts must respect:
- Minimum bet: Usually the big blind amount
- Maximum bet: Your remaining chips at the table
- Raise increments: Must meet minimum raise requirements

## Account Requirements

The account must have:
- Sufficient `stake` tokens for transaction fees (minimum 300 stake)
- Be seated at the game table
- Have sufficient chips for the action (bet/raise)

## One-liner Examples

```bash
# Build and fold
go build -o perform-action ./cmd/perform-action && \
  ./perform-action 0x89a7c...771df1 fold

# Build and call
go build -o perform-action ./cmd/perform-action && \
  ./perform-action 0x89a7c...771df1 call

# Build and raise to 5 USDC
go build -o perform-action ./cmd/perform-action && \
  ./perform-action 0x89a7c...771df1 raise 5000000
```

## Customization

To use a different account, update the `mnemonic` constant in `main.go` with your 24-word seed phrase.
