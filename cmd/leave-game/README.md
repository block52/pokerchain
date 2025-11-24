# Leave Game Script

This script allows a player to leave a poker game on the blockchain using gRPC, without requiring the `pokerchaind` binary.

## How It Works

The script:
1. Derives a private key from the provided mnemonic seed phrase
2. Connects to the blockchain via gRPC (node.texashodl.net:9443)
3. Creates and signs a `MsgLeaveGame` transaction
4. Broadcasts the transaction over the wire using gRPC
5. Your chips are returned to your account balance

## Prerequisites

- Go 1.21 or higher
- Network access to node.texashodl.net
- An active game where you are seated
- Sufficient stake tokens for transaction fees

## Usage

### Build

From the pokerchain root directory:

```bash
go build -o leave-game ./cmd/leave-game
```

### Run

```bash
./leave-game <game_id>
```

**Arguments:**
- `game_id` - The game/table ID to leave (hex string starting with 0x)

### Example

```bash
./leave-game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
```

### One-liner (build + run)

```bash
go build -o leave-game ./cmd/leave-game && \
  ./leave-game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
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
Account number: 7, Sequence: 5

Leaving game: 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1

Broadcasting transaction...

Transaction Result:
{
  "txhash": "DEF456...",
  "logs": null,
  "events": null
}

✅ Transaction successful!
Transaction hash: DEF456...

You have left game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1. Your chips have been cashed out.
```

## What Happens When You Leave

1. **Chips returned**: Your remaining chips at the table are converted back to USDC and credited to your account
2. **Seat freed**: Your seat becomes available for other players
3. **Hand forfeited**: If a hand is in progress, you forfeit your hand and any bets
4. **Game continues**: Other players continue playing

## Verify Transaction

After leaving, verify the transaction was included:

```bash
# Query the transaction (replace TX_HASH)
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | jq .

# Check player_left event
curl -s "https://node.texashodl.net/cosmos/tx/v1beta1/txs/TX_HASH" | \
  jq '.tx_response.events[] | select(.type=="player_left")'

# Check your balance to see chips returned
curl -s "https://node.texashodl.net/cosmos/bank/v1beta1/balances/YOUR_ADDRESS" | jq .
```

## When to Leave

You can leave a game:
- ✅ Before the game starts (waiting for players)
- ✅ Between hands
- ✅ During a hand (you'll forfeit your hand)
- ✅ After winning/losing a hand

## Common Issues

### "not in game"

You're not currently seated at this game. You can only leave games you've joined.

### "insufficient fees"

Make sure you have at least 300 stake tokens for the transaction fee.

### "game not found"

The game ID is incorrect or the game has already ended.

### "cannot leave during active hand"

Some game configurations may prevent leaving during an active hand. Wait for the hand to complete or fold first.

## Chips Calculation

When you leave:
- Your **stack** (remaining chips at the table) is converted to USDC
- Conversion: `chips_amount` uusdc = `chips_amount / 1,000,000` USDC
- Example: 50,000,000 chips = 50 USDC

## Account Requirements

The account must have:
- Sufficient `stake` tokens for transaction fees (minimum 300 stake)
- Be seated at the specified game

## Use Cases

1. **Cash out winnings** - Leave after winning pots
2. **Stop playing** - Exit when you want to stop playing
3. **Switch tables** - Leave one table to join another
4. **Manage bankroll** - Cash out to secure profits

## Integration with Other Scripts

Typical workflow:

1. **Check game state** using `query-game`
2. **Verify it's safe to leave** (not in middle of hand)
3. **Leave the game** using this script
4. **Check balance** to confirm chips were returned

## Safety Notes

- Leaving during an active hand forfeits your hand and any bets
- Make sure you want to leave before running this script
- Your chips will be returned to your account balance immediately
- Transaction is irreversible once broadcast

## Customization

To use a different account, update the `mnemonic` constant in `main.go` with your 24-word seed phrase.
