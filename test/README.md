# Pokerchain Test Suite

This folder contains comprehensive test scripts for the Pokerchain poker game functionality.

## 🎯 Quick Start

1. **Start your local node:**

    ```bash
    ./start-node.sh
    ```

2. **Run the interactive test suite:**
    ```bash
    ./test/run-tests.sh
    ```

## 📁 Test Scripts

### Core Scripts

-   **`run-tests.sh`** - Interactive test menu with all options
-   **`create-game-test.sh`** - Creates a new poker game
-   **`join-game-test.sh`** - Joins an existing game
-   **`query-games-test.sh`** - Queries and displays game information
-   **`mint-tokens-test.sh`** - Mints stake tokens for testing

### Individual Usage

#### Create a Game

```bash
./test/create-game-test.sh
```

-   Creates a game with auto-generated ID
-   Uses first available key as player
-   Sets default parameters (buy-in: 1000, max players: 6, etc.)

#### Join a Game

```bash
./test/join-game-test.sh <game-id> [player-key]
```

-   Example: `./test/join-game-test.sh test-game-1697123456`

#### Query Games

```bash
./test/query-games-test.sh [specific-game-id]
```

-   Lists all games or shows details for specific game

#### Mint Tokens

```bash
./test/mint-tokens-test.sh [amount] [player-key]
```

-   Example: `./test/mint-tokens-test.sh 1000000`

## 🎮 Test Workflow

A typical test session:

1. **Setup**: Mint tokens for testing
2. **Create**: Create a new poker game
3. **Join**: Join the game with one or more players
4. **Query**: Check game status and player information
5. **Play**: Use game actions (deal cards, perform actions, etc.)

## 🔧 Configuration

All scripts use these default settings:

-   **Keyring Backend**: `test`
-   **Chain ID**: `pokerchain`
-   **Node URL**: `tcp://localhost:26657`
-   **Home Directory**: `~/.pokerchain`

## 🎲 Game Parameters

Default game creation parameters:

-   **Buy-in**: 1000 stake
-   **Max Players**: 6
-   **Small Blind**: 10 stake
-   **Big Blind**: 20 stake

## 🚨 Troubleshooting

### Node Not Running

```
❌ Local node is not running on port 26657
```

**Solution**: Start the node with `./start-node.sh`

### No Keys Available

```
❌ No keys found. Creating a test key...
```

**Solution**: Scripts will auto-create test keys or use existing ones

### Insufficient Balance

```
❌ Insufficient balance. Need stake tokens to create games.
```

**Solution**: Run `./test/mint-tokens-test.sh` to mint tokens

### Game Not Found

```
❌ Game test-game-123 not found
```

**Solution**: Check available games with `./test/query-games-test.sh`

## 📊 Expected Output

### Successful Game Creation

```
🎉 Game creation transaction submitted!
✅ Game created successfully!
🎲 Game ID: test-game-1697123456
```

### Successful Token Minting

```
✅ Mint transaction submitted!
💵 New balance:
balances:
- amount: "1000000"
  denom: stake
```

## 🔄 Cleanup

To reset test environment:

```bash
pkill pokerchaind
rm -rf ~/.pokerchain/data/*
./start-node.sh
```

Or use the interactive menu option 6 in `run-tests.sh`.

## 🎯 Advanced Testing

For more complex scenarios, combine multiple scripts:

```bash
# Multi-player game test
./test/mint-tokens-test.sh 1000000 alice
./test/mint-tokens-test.sh 1000000 bob
./test/create-game-test.sh
./test/join-game-test.sh test-game-123 alice
./test/join-game-test.sh test-game-123 bob
```
