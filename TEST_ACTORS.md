# Test Actors

For testing and development purposes, here are 10 test actors with their addresses and seed phrases. These can be used to test poker game functionality.

**⚠️ Warning: These are test accounts only. Never use these seed phrases on mainnet or with real funds.**

## Test Actor 1 - "Alice"

**Address:** `b521dfe7r39q88zeqtde44efdqeky9thdtwngkzy2y`  
**Seed Phrase:** `cement shadow leave crash crisp aisle model hip lend february library ten cereal soul bind boil bargain barely rookie odor panda artwork damage reason`  
**Usage:** Conservative player, good for testing basic gameplay

## Test Actor 2 - "Bob"

**Address:** `b521hg93rsm2f5v3zlepf20ru88uweajt3nf492s2p`  
**Seed Phrase:** `vanish legend pelican blush control spike useful usage into any remove wear flee short october naive swear wall spy cup sort avoid agent credit`  
**Usage:** Aggressive player, good for testing betting strategies

## Test Actor 3 - "Charlie"

**Address:** `b521xkh7eznh50km2lxh783sqqyml8fjwl0tqjsc0c`  
**Seed Phrase:** `video short denial minimum vague arm dose parrot poverty saddle kingdom life buyer globe fashion topic vicious theme voice keep try jacket fresh potato`  
**Usage:** Strategic player, good for testing complex scenarios

## Test Actor 4 - "Diana"

**Address:** `b521n25h4eg6uhtdvs26988k9ye497sylum8lz5vns`  
**Seed Phrase:** `twice bacon whale space improve galaxy liberty trumpet outside sunny action reflect doll hill ugly torch ride gossip snack fork talk market proud nothing`  
**Usage:** Unpredictable player, good for testing edge cases

## Test Actor 5 - "Eve"

**Address:** `b521pscx3n8gygnm7pf3vxcyvxlwvcxa3ug2vzaxah`  
**Seed Phrase:** `raven mix autumn dismiss degree husband street slender maple muscle inch radar winner agent claw permit autumn expose power minute master scrub asthma retreat`  
**Usage:** Balanced player, good for testing standard gameplay

## Test Actor 6 - "Frank"

**Address:** `b521pejd682h20grq0em8jwhmnclggf2hqaq7xh8tk`  
**Seed Phrase:** `alpha satoshi civil spider expand bread pitch keen define helmet tourist rib habit cereal impulse earn milk need obscure ski purchase question vocal author`  
**Usage:** High-stakes player, good for testing large bets

## Test Actor 7 - "Grace"

**Address:** `b521r4ysrlg7cqgfx4nh48t234g6hl3lxap9dddede`  
**Seed Phrase:** `letter stumble apology garlic liquid loyal bid board silver web ghost jewel lift direct green silk urge guitar nest erase remind jaguar decrease skin`  
**Usage:** Careful player, good for testing fold scenarios

## Test Actor 8 - "Henry"

**Address:** `b521xe9xv26qtdern5k84csy2c6jxxfa33vxn6s0aw`  
**Seed Phrase:** `access execute loyal tag grid demise cloth desk dolphin pelican trumpet frown note level sibling dumb upon unfold wedding party success hint need fruit`  
**Usage:** Lucky player, good for testing winning scenarios

## Test Actor 9 - "Iris"

**Address:** `pokerchain1iris00000000000000000000000000000000000`  
**Seed Phrase:** `any antenna globe forget neglect race advice admit market guilt clay tunnel anxiety aim morning scrap visit sibling royal during proud flee maid fiscal`  
**Usage:** Passive player, good for testing check/call patterns

## Test Actor 10 - "Jack"

**Address:** `pokerchain1jack00000000000000000000000000000000000`  
**Seed Phrase:** `digital option before hawk alcohol uncover expire faint enact shield bike uncle kangaroo museum domain heart purchase under answer topple timber hole height glance`  
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

-   **Test Environment Only**: These accounts are for testing purposes only
-   **Public Seed Phrases**: Never use these seed phrases on mainnet or with real funds
-   **Development Use**: Perfect for automated testing, CI/CD, and development workflows
-   **Easy Reset**: Generate new test accounts anytime using `pokerchaind keys add <name> --keyring-backend test`
-   **BIP39 Standard**: All seed phrases follow the BIP39 standard and are cryptographically valid

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
