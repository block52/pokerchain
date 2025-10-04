#!/bin/bash

# Script to install pokerchaind from source
# Run this script on the target node

set -e

echo "Installing pokerchaind from source..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please install Go first."
    echo "Visit: https://golang.org/doc/install"
    exit 1
fi

# Check Go version
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
REQUIRED_VERSION="1.21"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$GO_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Error: Go version $REQUIRED_VERSION or higher is required. Found: $GO_VERSION"
    exit 1
fi

# Clone repository
REPO_DIR="/tmp/pokerchain-install"
if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

echo "Cloning repository..."
git clone https://github.com/block52/pokerchain.git "$REPO_DIR"
cd "$REPO_DIR"

# Checkout the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")
echo "Checking out $LATEST_TAG..."
git checkout "$LATEST_TAG"

# Build and install
echo "Building pokerchaind..."
make install

# Verify installation
echo "Verifying installation..."
pokerchaind version

echo "Installation completed successfully!"
echo "Binary location: $(which pokerchaind)"

# Cleanup
cd /
rm -rf "$REPO_DIR"

echo "You can now use 'pokerchaind' command."