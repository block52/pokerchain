# Scripts Updated - Binary Path Changes

## Summary

All deployment scripts now use `./build/pokerchaind` instead of `$(go env GOPATH)/bin/pokerchaind`.

## Files Changed ✅

### 1. deploy-master-node.sh

-   **Line 18-36**: Changed to build into `./build/pokerchaind`
-   **Status**: ✅ Already using build directory

### 2. deploy-node.sh

-   **Line 23-45**: Updated to use `./build/pokerchaind`
-   **Before**: `LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"`
-   **After**: `LOCAL_BINARY="./build/pokerchaind"`
-   **Status**: ✅ Updated

### 3. install-binary.sh

-   **Line 8-12**: Added `BUILD_DIR` variable
-   **Line 27-44**: Updated build logic to use build directory
-   **Before**: `LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"`
-   **After**: `LOCAL_BINARY="./build/pokerchaind"`
-   **Status**: ✅ Updated

### 4. start-node.sh

-   **Line 36-58**: Added smart binary detection
-   **Priority**: `./build/pokerchaind` → system `pokerchaind`
-   **Line 181**: Uses `$POKERCHAIND_BIN` variable for start command
-   **Status**: ✅ Updated

## Key Changes

### Binary Selection Logic

```bash
# Old way (all scripts)
LOCAL_BINARY="$(go env GOPATH)/bin/pokerchaind"

# New way
BUILD_DIR="./build"
LOCAL_BINARY="$BUILD_DIR/pokerchaind"
```

### Build Process

```bash
# Old way
make install  # Installs to go/bin

# New way
mkdir -p ./build
go build -o ./build/pokerchaind ./cmd/pokerchaind
chmod +x ./build/pokerchaind
```

### Smart Detection (start-node.sh only)

```bash
# Prefers repo binary, falls back to system
if [ -f "./build/pokerchaind" ]; then
    POKERCHAIND_BIN="./build/pokerchaind"
elif command -v pokerchaind &> /dev/null; then
    POKERCHAIND_BIN="pokerchaind"  # With warning
else
    # Error: not found
fi
```

## Testing

Verify the changes:

```bash
# Check binary paths in scripts
grep "LOCAL_BINARY\|BUILD_DIR" deploy-*.sh install-binary.sh

# Should show:
# BUILD_DIR="./build"
# LOCAL_BINARY="$BUILD_DIR/pokerchaind"
```

Test deployment:

```bash
# Builds to ./build/ automatically
./deploy-master-node.sh
```

## Files NOT Changed (Intentional)

These scripts remain unchanged as they serve different purposes:

-   **test/\*.sh** - Test scripts use system `pokerchaind` command
-   **setup-network.sh** - Local setup uses system command
-   **setup-genesis-node.sh** - Documentation only
-   **configure-public-api.sh** - Config only, no binary usage
-   **connect-to-network.sh** - Uses system command
-   **install-from-source.sh** - Builds via make install to go/bin

## Benefits

✅ Clean separation: dev vs deployment binaries  
✅ Always fresh build from source for deployments  
✅ Version tracked via git commit  
✅ No binaries committed to git (build/ in .gitignore)  
✅ Reproducible deployments

## Next Steps

All scripts are now ready for production use with proper binary management.
