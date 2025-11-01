#!/bin/bash

# Build pokerchaind matching node1.block52.xyz version
# This ensures your local ARM64 binary produces the same AppHash as node1's x86_64 binary

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET_COMMIT="7a22c7ada02a1b7be6165f589f5761af9b3e9b16"
TARGET_SHORT="7a22c7a"

echo -e "${BLUE}🔧 Building pokerchaind to match node1.block52.xyz${NC}"
echo "=================================================="
echo ""
echo "Target commit: $TARGET_COMMIT"
echo "Architecture: $(uname -m) ($(uname -s))"
echo ""

# Check current commit
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Current branch: $CURRENT_BRANCH"
echo "Current commit: $CURRENT_COMMIT"
echo ""

# Stash changes if any
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes${NC}"
    echo "Stashing changes..."
    git stash push -m "Auto-stash before building matching node1 binary"
    STASHED=1
else
    STASHED=0
fi

# Checkout target commit
echo "Checking out commit $TARGET_SHORT..."
git checkout $TARGET_SHORT

# Build
echo ""
echo "Building pokerchaind..."
make install

# Get version
BUILT_VERSION=$(~/go/bin/pokerchaind version 2>/dev/null || echo "unknown")
echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo "   Version: $BUILT_VERSION"
echo "   Location: ~/go/bin/pokerchaind"

# Return to original branch
echo ""
echo "Returning to $CURRENT_BRANCH..."
git checkout $CURRENT_BRANCH

# Restore stashed changes
if [ $STASHED -eq 1 ]; then
    echo "Restoring stashed changes..."
    git stash pop
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"
echo ""
echo "Your ARM64 binary is now built from the same commit as node1's x86_64 binary."
echo "Both will produce identical AppHashes."
echo ""
echo "Next steps:"
echo "  1. Stop pokerchaind (Ctrl+C)"
echo "  2. Run: ./setup-local-sync-node.sh"
echo "  3. When asked to rebuild, answer: n"
echo ""
