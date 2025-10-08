#!/bin/bash

# Generate New Seed Phrases
# This script generates new BIP39 seed phrases for development use

echo "🎲 Generating New BIP39 Seed Phrases"
echo "===================================="

# Check if we have python3 and mnemonic library
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found"
    exit 1
fi

# Generate using Python
python3 -c "
try:
    from mnemonic import Mnemonic
except ImportError:
    import subprocess
    import sys
    print('Installing mnemonic library...')
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'mnemonic'])
    from mnemonic import Mnemonic

mnemo = Mnemonic('english')
count = ${1:-10}
print(f'Generating {count} new seed phrases:')
print()

for i in range(1, count + 1):
    seed = mnemo.generate(strength=128)
    print(f'Seed {i:2d}: {seed}')
print()
print('⚠️  Remember: These are for testing only!')
"