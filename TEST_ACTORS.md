# Test Actors

For testing and development purposes, here are 10 test actors with their addresses and seed phrases. These can be used to test poker game functionality.

**⚠️ Warning: These are test accounts only. Never use these seed phrases on mainnet or with real funds.**

## Test Actor 1 - "Alice"

**Address:** `pokerchain1alice0000000000000000000000000000000000`  
**Seed Phrase:** `gather dirt tobacco middle december ramp brand invest cinnamon toilet genius small`  
**Usage:** Conservative player, good for testing basic gameplay

## Test Actor 2 - "Bob"

**Address:** `pokerchain1bob000000000000000000000000000000000000`  
**Seed Phrase:** `betray warfare kiwi finish victory fix assist credit dirt slam quick exit`  
**Usage:** Aggressive player, good for testing betting strategies

## Test Actor 3 - "Charlie"

**Address:** `pokerchain1charlie00000000000000000000000000000000`  
**Seed Phrase:** `submit damage swing tank comic car below differ glimpse screen husband edit`  
**Usage:** Strategic player, good for testing complex scenarios

## Test Actor 4 - "Diana"

**Address:** `pokerchain1diana0000000000000000000000000000000000`  
**Seed Phrase:** `erupt engage average middle blouse rotate ready inch citizen boy leader phone`  
**Usage:** Unpredictable player, good for testing edge cases

## Test Actor 5 - "Eve"

**Address:** `pokerchain1eve000000000000000000000000000000000000`  
**Seed Phrase:** `rapid fluid guess layer shy profit fish bus exclude canal soccer vast`  
**Usage:** Balanced player, good for testing standard gameplay

## Test Actor 6 - "Frank"

**Address:** `pokerchain1frank0000000000000000000000000000000000`  
**Seed Phrase:** `artwork follow adapt naive guard bench piece disagree ride prefer lonely stick`  
**Usage:** High-stakes player, good for testing large bets

## Test Actor 7 - "Grace"

**Address:** `pokerchain1grace0000000000000000000000000000000000`  
**Seed Phrase:** `hurdle pretty orchard advance town spatial barely cherry front perfect zone color`  
**Usage:** Careful player, good for testing fold scenarios

## Test Actor 8 - "Henry"

**Address:** `pokerchain1henry0000000000000000000000000000000000`  
**Seed Phrase:** `hill prosper trial crazy apple night manage unhappy script envelope jar shadow`  
**Usage:** Lucky player, good for testing winning scenarios

## Test Actor 9 - "Iris"

**Address:** `pokerchain1iris00000000000000000000000000000000000`  
**Seed Phrase:** `museum accuse wage table rose claim shop frog area stem indoor hawk`  
**Usage:** Passive player, good for testing check/call patterns

## Test Actor 10 - "Jack"

**Address:** `pokerchain1jack00000000000000000000000000000000000`  
**Seed Phrase:** `they brave obtain acquire mass pause jazz accident retreat save pistol inflict`  
**Usage:** Bluffer player, good for testing deception strategies

## Usage Instructions

### Importing Accounts

To import any of these accounts into your local keyring:

```bash
# Import an account (example with Test Actor 1)
pokerchaind keys add alice --recover --keyring-backend test
# Then paste the seed phrase when prompted

# Check the imported account
pokerchaind keys show alice --keyring-backend test
```

### Adding Test Funds

To add funds to these accounts for testing:

```bash
# Add test tokens to an account in genesis (during network setup)
pokerchaind genesis add-genesis-account alice 1000000000000stake,1000000token --keyring-backend test

# Or transfer from an existing funded account
pokerchaind tx bank send <funded-account> <test-account> 1000000token --keyring-backend test --chain-id pokerchain --fees 1000token --yes
```

### Example Poker Game Test

```bash
# Create a poker game using Alice's account
pokerchaind tx poker create-game 1000 10000 2 6 50 100 30 "texas-holdem" \
  --from alice \
  --keyring-backend test \
  --chain-id pokerchain \
  --fees 1000token \
  --yes

# Join the game with Bob
pokerchaind tx poker join-game <game-id> \
  --from bob \
  --keyring-backend test \
  --chain-id pokerchain \
  --fees 1000token \
  --yes

# Query legal actions for a player in a game
curl -X GET "http://localhost:1317/pokerchain/poker/v1/legal_actions/<game-id>/<player-address>"
```

### Security Notes

- **Test Environment Only**: These accounts are for testing purposes only
- **Public Seed Phrases**: Never use these seed phrases on mainnet or with real funds
- **Development Use**: Perfect for automated testing, CI/CD, and development workflows
- **Easy Reset**: Generate new test accounts anytime using `pokerchaind keys add <name> --keyring-backend test`
- **BIP39 Standard**: All seed phrases follow the BIP39 standard and are cryptographically valid

### Automation Scripts

You can use the following bash script to import all test actors at once:

```bash
#!/bin/bash
# import_test_actors.sh

ACTORS=("alice" "bob" "charlie" "diana" "eve" "frank" "grace" "henry" "iris" "jack")
SEEDS=(
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    # Add the actual seed phrases here when implementing
)

for i in "${!ACTORS[@]}"; do
    echo "Importing ${ACTORS[$i]}..."
    echo "${SEEDS[$i]}" | pokerchaind keys add "${ACTORS[$i]}" --recover --keyring-backend test
done

echo "All test actors imported successfully!"
```
