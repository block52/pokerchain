#!/usr/bin/env python3

import os
import subprocess
import sys


def install_mnemonic():
    """Install the mnemonic library if not available"""
    try:
        import mnemonic
        return True
    except ImportError:
        print("Installing mnemonic library...")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "mnemonic"])
        return True


def generate_seed_phrase():
    """Generate a real BIP39 mnemonic seed phrase"""
    from mnemonic import Mnemonic
    mnemo = Mnemonic("english")
    return mnemo.generate(strength=128)  # 12 words


def generate_cosmos_address(seed_phrase, name):
    """Generate a cosmos address using pokerchaind (placeholder for now)"""
    # For now, we'll generate placeholder addresses
    # In a real implementation, you'd use the pokerchaind CLI or cosmos SDK
    import hashlib
    hash_obj = hashlib.sha256(f"{name}{seed_phrase}".encode())
    hex_hash = hash_obj.hexdigest()[:40]  # Take first 40 chars
    return f"pokerchain1{hex_hash}"


def main():
    # Install mnemonic library if needed
    install_mnemonic()

    # Test actor names and descriptions
    actors = [
        ("alice", "Conservative player, good for testing basic gameplay"),
        ("bob", "Aggressive player, good for testing betting strategies"),
        ("charlie", "Strategic player, good for testing complex scenarios"),
        ("diana", "Unpredictable player, good for testing edge cases"),
        ("eve", "Balanced player, good for testing standard gameplay"),
        ("frank", "High-stakes player, good for testing large bets"),
        ("grace", "Careful player, good for testing fold scenarios"),
        ("henry", "Lucky player, good for testing winning scenarios"),
        ("iris", "Passive player, good for testing check/call patterns"),
        ("jack", "Bluffer player, good for testing deception strategies")
    ]

    print("Generating 10 real BIP39 seed phrases for test actors...")

    # Generate the markdown content
    content = """# Test Actors

For testing and development purposes, here are 10 test actors with their addresses and seed phrases. These can be used to test poker game functionality.

**⚠️ Warning: These are test accounts only. Never use these seed phrases on mainnet or with real funds.**

"""

    for i, (name, description) in enumerate(actors, 1):
        seed_phrase = generate_seed_phrase()
        # For demo, using placeholder addresses - in real use you'd generate actual cosmos addresses
        address = f"pokerchain1{name}{'0' * (39 - len(name))}"

        content += f"""## Test Actor {i} - "{name.title()}"

**Address:** `{address}`  
**Seed Phrase:** `{seed_phrase}`  
**Usage:** {description}

"""

    # Add usage instructions
    content += """## Usage Instructions

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
pokerchaind tx poker create-game 1000 10000 2 6 50 100 30 "texas-holdem" \\
  --from alice \\
  --keyring-backend test \\
  --chain-id pokerchain \\
  --fees 1000token \\
  --yes

# Join the game with Bob
pokerchaind tx poker join-game <game-id> \\
  --from bob \\
  --keyring-backend test \\
  --chain-id pokerchain \\
  --fees 1000token \\
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
"""

    # Write to file
    with open("/Users/lucascullen/Github/block52/pokerchain/TEST_ACTORS.md", "w") as f:
        f.write(content)

    print("✅ Generated TEST_ACTORS.md with 10 real BIP39 seed phrases")
    print("📁 File saved to: /Users/lucascullen/Github/block52/pokerchain/TEST_ACTORS.md")


if __name__ == "__main__":
    main()
