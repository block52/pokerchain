# Get Legal Actions Script

This script queries the available actions for a player in a poker game on the blockchain using gRPC, without requiring the `pokerchaind` binary.

## How It Works

The script:
1. Derives a private key from the provided mnemonic seed phrase
2. Connects to the blockchain via gRPC (node.texashodl.net:9443)
3. Queries legal actions for the specified game and player
4. Displays formatted information about available actions

## Prerequisites

- Go 1.21 or higher
- Network access to node.texashodl.net
- An active game where you are seated

## Usage

### Build

From the pokerchain root directory:

```bash
go build -o get-legal-actions ./cmd/get-legal-actions
```

### Run

```bash
./get-legal-actions <game_id>
```

**Arguments:**
- `game_id` - The game/table ID (hex string starting with 0x)

### Example

```bash
./get-legal-actions 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
```

## Example Output

```
Using address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg

Querying legal actions for game: 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1
Player: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg

Legal Actions:
{
  "is_your_turn": true,
  "available_actions": ["fold", "call", "raise"],
  "current_bet": 1000000,
  "min_raise": 2000000,
  "max_raise": 50000000
}

✅ It's your turn to act!

Available actions:
  • fold
  • call
  • raise

Current bet: 1.000000 USDC
Min raise: 2.000000 USDC
Max raise: 50.000000 USDC
```

## Response Fields

The query returns the following information:

- **is_your_turn** - Boolean indicating if it's currently your turn to act
- **available_actions** - Array of valid poker actions you can perform:
  - `fold` - Forfeit your hand
  - `call` - Match the current bet
  - `check` - Pass without betting (when no bet is required)
  - `bet` - Place a bet (when no bet exists)
  - `raise` - Increase the current bet
- **current_bet** - The current bet amount in uusdc (if any)
- **min_raise** - Minimum raise amount in uusdc
- **max_raise** - Maximum raise amount in uusdc (limited by your stack)

## Use Cases

1. **Check if it's your turn** before attempting to perform an action
2. **View valid actions** to know what moves are allowed in the current game state
3. **Get betting limits** to know the range of valid bet/raise amounts
4. **Integrate into bots** for automated gameplay

## Configuration

Edit `main.go` to change:

- **Mnemonic**: The seed phrase (currently hardcoded)
- **Chain ID**: `pokerchain`
- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`

## Common Issues

### "not your turn"

The game is waiting for another player to act. You can only perform actions when it's your turn.

### "game not found"

The game ID is incorrect or the game has ended.

### "player not in game"

You must join the game first using the `join-game` script.

## Integration with Other Scripts

Typical workflow:

1. **Create a game** using `create-table`
2. **Join the game** using `join-game`
3. **Check legal actions** using this script
4. **Perform an action** using `perform-action`
5. **Repeat** steps 3-4 until the game ends

## One-liner Examples

```bash
# Build and query
go build -o get-legal-actions ./cmd/get-legal-actions && \
  ./get-legal-actions 0x89a7c...771df1

# Query and pipe to jq for parsing
./get-legal-actions 0x89a7c...771df1 | grep "Legal Actions:" -A 100 | head -10
```

## Customization

To use a different account, update the `mnemonic` constant in `main.go` with your 24-word seed phrase.
