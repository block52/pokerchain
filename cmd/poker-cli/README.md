# Poker CLI - Interactive Blockchain Poker Client

An interactive command-line interface for playing poker on the blockchain using gRPC.

## Features

- 🔑 **Import seed phrase** - Securely load your 24-word mnemonic
- 💰 **Check balance** - View your USDC and stake balances
- 🎲 **Create table** - Set up new poker games with custom parameters
- 🪑 **Join table** - Join existing games at any available seat
- ♠️ **Perform actions** - Fold, call, check, bet, and raise
- 📊 **Query game state** - View current game information in formatted tables
- 🎯 **Get legal actions** - Check available actions and if it's your turn
- 🚪 **Leave game** - Exit a game and cash out your chips
- 🔄 **Switch accounts** - Change seed phrase without restarting

## Installation

From the pokerchain root directory:

```bash
go build -o poker-cli ./cmd/poker-cli
```

## Usage

Simply run the CLI:

```bash
./poker-cli
```

## Menu System

### Welcome Screen

When you first start, you'll see:

```
╔══════════════════════════════════════════════════════════════════╗
║              🎲 Poker CLI - Blockchain Poker Client 🎲          ║
╚══════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Welcome! Please import your seed phrase to continue.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1) Import seed phrase
2) Exit

Select option:
```

### Main Menu

After importing your seed phrase:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1) Check balance
2) Create new table
3) Join existing table
4) Perform poker action
5) Query game state
6) Get legal actions
7) Leave game
8) Change seed phrase
9) Exit

Select option:
```

## Features in Detail

### 1. Import Seed Phrase

- Enter your 24-word mnemonic
- Validates the seed phrase
- Derives your blockchain address
- Connects to the blockchain via gRPC

### 2. Check Balance

Displays your account balances:
- USDC (formatted as decimal)
- Stake tokens (for transaction fees)
- Any other tokens

Example output:
```
Balances:
  999.999999 USDC (999999999 uusdc)
  10000 stake
```

### 3. Create New Table

Interactive prompts for:
- **Min buy-in** - Minimum chips to join (e.g., 100000000 = 100 USDC)
- **Max buy-in** - Maximum chips to join (e.g., 1000000000 = 1000 USDC)
- **Min players** - Minimum players to start (e.g., 2)
- **Max players** - Maximum seats (e.g., 9)
- **Small blind** - Small blind amount (e.g., 500000 = 0.5 USDC)
- **Big blind** - Big blind amount (e.g., 1000000 = 1 USDC)
- **Timeout** - Action timeout in seconds (e.g., 60)
- **Game type** - Game variant (default: nlhe)

Returns the transaction hash on success.

### 4. Join Existing Table

Interactive prompts for:
- **Game ID** - The table to join (hex format: 0x...)
- **Seat number** - Which seat to take (0-8)
- **Buy-in amount** - Chips to bring to table (e.g., 500000000 = 500 USDC)

### 5. Perform Poker Action

Interactive prompts for:
- **Game ID** - The active game
- **Action** - Choose from:
  - `fold` - Forfeit your hand
  - `call` - Match current bet
  - `check` - Pass (no bet required)
  - `bet` - Place a bet
  - `raise` - Increase current bet
- **Amount** - Required for bet/raise actions

### 6. Query Game State

- Enter a game ID
- View game information in formatted tables:
  - Game details (ID, creator, status, buy-ins, blinds)
  - Players table (seat, address, stack, status, bet)
  - Current hand (community cards, pot, round, next to act)
- Optional raw JSON display

### 7. Get Legal Actions

- Enter a game ID
- See if it's your turn to act
- View available actions (fold, call, check, bet, raise)
- Display betting information:
  - Current bet amount
  - Minimum raise amount
  - Maximum raise amount
- Optional raw JSON display

### 8. Leave Game

- Enter a game ID
- Exit the game and cash out your chips
- Chips are returned to your account balance
- Transaction confirmation with hash

### 9. Change Seed Phrase

- Clears current account
- Returns to welcome menu
- Import a different seed phrase

## Example Session

```bash
$ ./poker-cli

# Import your seed phrase
Select option: 1
Enter your 24-word seed phrase:
> grow broom cigar crime caught name...

✅ Seed phrase imported successfully!
Your address: b521s8aug28r6vned2xm767xhgrkg90wfef2hfg4mg

# Check your balance
Select option: 1
Checking balance...

Balances:
  999.999999 USDC (999999999 uusdc)
  10000 stake

# Create a new table
Select option: 2
Min buy-in (uusdc): 100000000
Max buy-in (uusdc): 1000000000
Min players: 2
Max players: 9
Small blind (uusdc): 500000
Big blind (uusdc): 1000000
Timeout (seconds): 60
Game type (nlhe): nlhe

✅ Table created successfully!
Transaction hash: A8E1668ABAB64109...

# Join a game
Select option: 3
Game ID (0x...): 0x89a7c217580fb3fc...
Seat number (0-8): 1
Buy-in amount (uusdc): 500000000

✅ Joined table successfully!
```

## USDC Amount Conversions

USDC uses 6 decimal places:

- 0.5 USDC = `500000`
- 1 USDC = `1000000`
- 5 USDC = `5000000`
- 10 USDC = `10000000`
- 100 USDC = `100000000`
- 500 USDC = `500000000`
- 1000 USDC = `1000000000`

## Configuration

The CLI connects to:
- **Chain ID**: `pokerchain`
- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`

To change these, edit the constants in `main.go`.

## Security Notes

- Seed phrases are stored in memory only while the CLI is running
- Never share your seed phrase with anyone
- The CLI connects over TLS (encrypted connection)
- Transaction fees are paid in `stake` tokens

## Requirements

- Go 1.21 or higher
- Network access to node.texashodl.net
- Valid seed phrase with funded account
- Sufficient stake tokens for transaction fees (300 stake per transaction)

## Troubleshooting

### "Invalid seed phrase"
- Ensure you're entering all 24 words
- Check for typos
- Words should be separated by spaces

### "Error connecting to blockchain"
- Check your internet connection
- Verify node.texashodl.net:9443 is accessible
- Firewall may be blocking the connection

### "Insufficient funds"
- Check your balance (option 1)
- Ensure you have enough USDC for buy-ins
- Ensure you have enough stake for transaction fees

### "Transaction failed"
- Read the error message for details
- Common issues:
  - Not your turn (perform action)
  - Seat already taken (join game)
  - Invalid action for game state

## Exit

Select option `9` or press `Ctrl+C` to exit the CLI.

## Related Scripts

For non-interactive use, see:
- `cmd/create-table/` - Create table script
- `cmd/join-game/` - Join game script
- `cmd/perform-action/` - Perform action script
- `cmd/get-legal-actions/` - Query available actions script
- `cmd/leave-game/` - Leave game script
