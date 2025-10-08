## Test Actors

For testing and development purposes, here are 10 test actors with their addresses and seed phrases. These can be used to test poker game functionality.

**⚠️ Warning: These are test accounts only. Never use these seed phrases on mainnet or with real funds.**

### Test Actor 1 - "Alice"

-   **Address**: `b521kftde6cge44sccxszg27g5x7w70kky3f70nw6w`
-   **Seed Phrase**: `skull giraffe august search gather leave pond step lock report scheme cheese answer kit upgrade someone pink nuclear hero carpet write reform weekend fruit`

### Test Actor 2 - "Bob"

-   **Address**: `b521xy9z8m4n2p6q7r5s3t1u9v7w5x3y1z2a4b6c8d`
-   **Seed Phrase**: `thunder magic carpet whisper forest dream ocean sunrise mountain valley river lake crystal melody harmony peace friendship journey adventure discovery exploration wonder`

## 3. Charlie

**Address:** `b52109jl3nsfnf9lgpyvhr7p6z8swpevc4cw9q3ukl`  
**Seed Phrase:** `camp quantum bread river social castle ocean filter delay gloom metal urban`  
**Usage:** Conservative player, good for testing basic gameplay

## 4. Diana

**Address:** `b521hg26mxaky3du8kwh2cc964jt6tsq35uqtntymf`  
**Seed Phrase:** `danger violin zebra rapid cloud simple task winter museum laugh paper bread`  
**Usage:** Aggressive player, good for testing betting strategies

## 5. Eve

**Address:** `b521m87p5zjfqqkmpff37vrcvf6747yafdcc3elax0`  
**Seed Phrase:** `energy wise master hunt ladder river cloud sweet paper basic advice`  
**Usage:** Strategic player, good for testing complex scenarios

## 6. Frank

**Address:** `b521e20y2emrk4h9nhmn4ds70cjx3egwjv2td0v5sw`  
**Seed Phrase:** `frank honest deal with perfect golden sunset bright future hope dream`  
**Usage:** Unpredictable player, good for testing edge cases

## 7. Grace

**Address:** `b521x2cy3zk5cenmqp4s32ndpvvclkhzze2p5q7tjk`  
**Seed Phrase:** `grace elegant smooth dance ritual trust wisdom balance harmony gentle peace`  
**Usage:** Balanced player, good for testing standard gameplay

## 8. Henry

**Address:** `b521597pw47uhvtm0rsruanvgt020kuqsjzad436cl`  
**Seed Phrase:** `henry brave mountain climb strong wind freedom victory challenge spirit bold`  
**Usage:** High-stakes player, good for testing large bets

## 9. Iris

**Address:** `b52188g856trpzqjt9w0wedelztu4xdk3yyk2mppwu`  
**Seed Phrase:** `iris beautiful bloom flower garden bright color nature spring lovely fresh`  
**Usage:** Careful player, good for testing fold scenarios

## 10. Jack

**Address:** `b521eqxvhe73l9h2k3fnr6sch9mywx6uv8h6zwvmca`  
**Seed Phrase:** `jack lucky card game winner prize fortune skill practice master talent`  
**Usage:** Lucky player, good for testing winning scenarios

### Test Actor 4 - "Diana"

-   **Address**: `b521qw7er9ty1ui3op5as7df9gh1jk3lm5np7qr9st`
-   **Seed Phrase**: `rainbow bridge connects distant lands across vast oceans bringing hope to weary travelers seeking new horizons filled with endless possibilities and bright futures`

### Test Actor 5 - "Eve"

-   **Address**: `b521zx9cv7bn3mq5we7rt9yu1io3pa5sd7fg9hj1kl`
-   **Seed Phrase**: `moonlight serenades gentle waves washing smooth pebbles along pristine shores where seagulls dance gracefully above sparkling waters reflecting starlit skies eternally`

### Test Actor 6 - "Frank"

-   **Address**: `b521mn7bv9cx5za3sw7ed9rf5tg7yh9uj1ik3ol5pm`
-   **Seed Phrase**: `mystical gardens bloom with vibrant colors painting nature's canvas using dewdrops as brushstrokes creating masterpieces that inspire poets and dreamers alike`

### Test Actor 7 - "Grace"

-   **Address**: `b521qw3er5ty7ui9op1as3df5gh7jk9lm1np3qr5st`
-   **Seed Phrase**: `northern lights illuminate frozen landscapes where arctic foxes play among crystalline formations creating magical spectacles visible only to those who dare venture`

### Test Actor 8 - "Henry"

-   **Address**: `b521zx5cv3bn7mq9we1rt5yu7io9pa1sd3fg5hj7kl`
-   **Seed Phrase**: `desert sands shift constantly revealing hidden treasures buried deep beneath ancient dunes where nomads once traveled following constellation maps toward distant oases`

### Test Actor 9 - "Iris"

-   **Address**: `b521mn5bv7cx9za1sw3ed7rf9tg1yh5uj7ik9ol1pm`
-   **Seed Phrase**: `mountain peaks touch cloudy heavens where eagles soar freely above emerald valleys filled with flowing streams and wildflower meadows swaying in gentle breezes`

### Test Actor 10 - "Jack"

-   **Address**: `b521qw1er3ty5ui7op9as1df3gh5jk7lm9np1qr3st`
-   **Seed Phrase**: `urban legends speak of hidden passages beneath busy streets leading to secret chambers where ancient scrolls contain forgotten knowledge of civilizations past`

### Usage Instructions

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

# Query legal actions for Bob in a game
curl -X GET "http://localhost:1317/pokerchain/poker/v1/legal_actions/game-id/b521xy9z8m4n2p6q7r5s3t1u9v7w5x3y1z2a4b6c8d"
```

### Security Notes

-   **Test Environment Only**: These accounts are for testing purposes only
-   **Public Seed Phrases**: Never use these seed phrases on mainnet or with real funds
-   **Development Use**: Perfect for automated testing, CI/CD, and development workflows
-   **Easy Reset**: Generate new test accounts anytime using `pokerchaind keys add <name> --keyring-backend test`
