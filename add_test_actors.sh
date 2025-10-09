#!/bin/bash

# Add remaining test actors to genesis
HOME_DIR="/home/lucascullen/.pokerchain-local"
POKERCHAIND="/home/lucascullen/go/bin/pokerchaind"

# Diana
echo "twice bacon whale space improve galaxy liberty trumpet outside sunny action reflect doll hill ugly torch ride gossip snack fork talk market proud nothing" | $POKERCHAIND keys add diana --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account diana 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Eve
echo "raven mix autumn dismiss degree husband street slender maple muscle inch radar winner agent claw permit autumn expose power minute master scrub asthma retreat" | $POKERCHAIND keys add eve --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account eve 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Frank
echo "alpha satoshi civil spider expand bread pitch keen define helmet tourist rib habit cereal impulse earn milk need obscure ski purchase question vocal author" | $POKERCHAIND keys add frank --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account frank 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Grace
echo "letter stumble apology garlic liquid loyal bid board silver web ghost jewel lift direct green silk urge guitar nest erase remind jaguar decrease skin" | $POKERCHAIND keys add grace --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account grace 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Henry
echo "access execute loyal tag grid demise cloth desk dolphin pelican trumpet frown note level sibling dumb upon unfold wedding party success hint need fruit" | $POKERCHAIND keys add henry --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account henry 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Iris
echo "any antenna globe forget neglect race advice admit market guilt clay tunnel anxiety aim morning scrap visit sibling royal during proud flee maid fiscal" | $POKERCHAIND keys add iris --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account iris 100usdc,52000stake --home $HOME_DIR --keyring-backend test

# Jack
echo "digital option before hawk alcohol uncover expire faint enact shield bike uncle kangaroo museum domain heart purchase under answer topple timber hole height glance" | $POKERCHAIND keys add jack --recover --home $HOME_DIR --keyring-backend test
$POKERCHAIND genesis add-genesis-account jack 100usdc,52000stake --home $HOME_DIR --keyring-backend test

echo "All test actors added to genesis!"