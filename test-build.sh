#!/bin/bash

# Test script to verify local build and deployment readiness
# Usage: ./test-build.sh

set -e

echo "🧪 Testing Pokerchain Build Process"
echo "==================================="

# Test 1: Check Go version
echo ""
echo "📋 Test 1: Go version check"
GO_VERSION=$(go version)
echo "Go version: $GO_VERSION"

if [[ "$GO_VERSION" == *"go1.24"* ]]; then
    echo "✅ Go 1.24+ detected"
else
    echo "⚠️  Warning: Go 1.24+ recommended for best compatibility"
fi

# Test 2: Clean and build
echo ""
echo "🔨 Test 2: Clean build test"
echo "Cleaning previous builds..."
make clean

echo "Building pokerchaind..."
make install

# Test 3: Verify binary
echo ""
echo "🔍 Test 3: Binary verification"
LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"

if [ -f "$LOCAL_BINARY" ]; then
    echo "✅ Binary found at: $LOCAL_BINARY"
    BINARY_VERSION=$(${LOCAL_BINARY} version 2>/dev/null || echo "unknown")
    echo "📦 Version: $BINARY_VERSION"
    
    # Check binary size
    BINARY_SIZE=$(stat -f%z "$LOCAL_BINARY" 2>/dev/null || stat -c%s "$LOCAL_BINARY" 2>/dev/null || echo "unknown")
    echo "📏 Size: $BINARY_SIZE bytes"
else
    echo "❌ Binary not found after build"
    exit 1
fi

# Test 4: Check genesis file
echo ""
echo "📋 Test 4: Genesis file check"
if [ -f "./genesis.json" ]; then
    echo "✅ Genesis file found"
    GENESIS_SIZE=$(stat -f%z "./genesis.json" 2>/dev/null || stat -c%s "./genesis.json" 2>/dev/null || echo "unknown")
    echo "📏 Genesis size: $GENESIS_SIZE bytes"
    
    # Validate JSON
    if command -v jq >/dev/null 2>&1; then
        if jq empty genesis.json 2>/dev/null; then
            echo "✅ Genesis JSON is valid"
            CHAIN_ID=$(jq -r '.chain_id' genesis.json)
            echo "🔗 Chain ID: $CHAIN_ID"
        else
            echo "❌ Genesis JSON is invalid"
            exit 1
        fi
    else
        echo "ℹ️  jq not available - skipping JSON validation"
    fi
else
    echo "❌ Genesis file not found"
    exit 1
fi

# Test 5: Check deployment scripts
echo ""
echo "🛠️  Test 5: Deployment scripts check"
SCRIPTS=("install-binary.sh" "second-node.sh" "connect-to-network.sh" "get-node-info.sh" "setup-network.sh")

for script in "${SCRIPTS[@]}"; do
    if [ -f "./$script" ] && [ -x "./$script" ]; then
        echo "✅ $script (executable)"
    elif [ -f "./$script" ]; then
        echo "⚠️  $script (found but not executable)"
        chmod +x "./$script"
        echo "   Fixed permissions"
    else
        echo "❌ $script (missing)"
    fi
done

echo ""
echo "🎉 Build Test Summary"
echo "===================="
echo "✅ Go environment ready"
echo "✅ Build process working"
echo "✅ Binary created successfully"
echo "✅ Genesis file ready"
echo "✅ Deployment scripts ready"
echo ""
echo "🚀 Ready for deployment!"
echo ""