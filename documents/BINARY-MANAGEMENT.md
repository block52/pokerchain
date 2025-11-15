# Binary Management - Updated Scripts

## Overview

All deployment and setup scripts now use the repository's `./build/pokerchaind` binary instead of the developer's local `go/bin/pokerchaind` binary.

## Why This Change?

**Before**: Scripts used `$(go env GOPATH)/bin/pokerchaind`

-   Mixed developer test binaries with production deployments
-   Hard to track which version was deployed
-   Developer's personal binary could be out of sync

**After**: Scripts use `./build/pokerchaind`

-   Clear separation between dev and deployment binaries
-   Always build fresh from repository source
-   Version control via git commit hash
-   `build/` directory is gitignored (no binaries in repo)

## Updated Scripts

### 1. deploy-master-node.sh ✅

**Status**: Already updated

-   Builds to `./build/pokerchaind`
-   Deploys fresh binary to node1.block52.xyz
-   Used for master node deployment

### 2. deploy-node.sh ✅

**Status**: Now updated

-   Changed from `go/bin` to `./build/pokerchaind`
-   Builds fresh binary before deployment
-   General deployment script for any node

### 3. install-binary.sh ✅

**Status**: Now updated

-   Changed from `go/bin` to `./build/pokerchaind`
-   Builds to repo directory if binary missing
-   Installs to remote nodes

### 4. start-node.sh ✅

**Status**: Now updated

-   Prefers `./build/pokerchaind` over system binary
-   Falls back to system `pokerchaind` with warning
-   Suggests building repo binary if none found

## Scripts That Don't Need Updates

### Test Scripts (test/\*.sh)

-   ✅ **Query scripts** - Use `pokerchaind` command (expects installed binary)
-   ✅ **Game test scripts** - Use system command (for testing against running node)
-   ✅ These scripts test functionality, not deployment

### Setup Scripts

-   ✅ **setup-network.sh** - Uses system `pokerchaind` command for local setup
-   ✅ **setup-genesis-node.sh** - Documentation references only
-   ✅ **setup-systemd.sh** - Works with already installed binary

### Other Scripts

-   ✅ **connect-to-network.sh** - Uses system command
-   ✅ **install-from-source.sh** - Installs via make install (builds to go/bin)
-   ✅ **configure-public-api.sh** - Configuration only, no binary usage

## Binary Location Strategy

### Deployment Binaries

**Location**: `./build/pokerchaind`
**Purpose**: Production deployment to remote nodes
**Build**: `go build -o ./build/pokerchaind ./cmd/pokerchaind`
**Scripts**: deploy-master-node.sh, deploy-node.sh, install-binary.sh

### Developer Binaries

**Location**: `$(go env GOPATH)/bin/pokerchaind`
**Purpose**: Local development and testing
**Build**: `make install` or `go install`
**Scripts**: All test scripts, setup scripts

### System Binaries

**Location**: `/usr/local/bin/pokerchaind` (remote nodes)
**Purpose**: Installed binary on remote servers
**Deployed by**: Deployment scripts from `./build/pokerchaind`

## Build Commands

### Build for Deployment

```bash
# Clean build to repo directory
go clean -cache
rm -f ./build/pokerchaind
go build -o ./build/pokerchaind ./cmd/pokerchaind
chmod +x ./build/pokerchaind
```

### Build for Development

```bash
# Install to go/bin for local testing
make install

# Or directly
go install ./cmd/pokerchaind
```

## Usage Examples

### Deploy to Node1

```bash
# Builds fresh binary and deploys
./deploy-master-node.sh
```

### Start Local Node

```bash
# Prefers ./build/pokerchaind, falls back to system
./start-node.sh
```

### Install Binary on Remote

```bash
# Uses ./build/pokerchaind if exists, else builds it
./install-binary.sh node1.block52.xyz root
```

## Directory Structure

```
pokerchain/
├── build/                      # Deployment binaries (gitignored)
│   └── pokerchaind            # Built from source for deployment
├── cmd/
│   └── pokerchaind/
│       └── main.go            # Source code
├── deploy-master-node.sh      # Uses ./build/pokerchaind
├── deploy-node.sh            # Uses ./build/pokerchaind
├── install-binary.sh         # Uses ./build/pokerchaind
├── start-node.sh             # Prefers ./build/pokerchaind
└── test/
    └── *.sh                  # Uses system pokerchaind
```

## Verification

Check which binary a script uses:

```bash
# Search for binary references
grep -n "pokerchaind" deploy-master-node.sh | grep BINARY
grep -n "pokerchaind" deploy-node.sh | grep BINARY
grep -n "pokerchaind" install-binary.sh | grep BINARY
```

Expected output should show `./build/pokerchaind` for deployment scripts.

## Benefits

1. **Clean Separation**: Dev vs production binaries clearly separated
2. **Version Control**: Deployment always uses repo source code version
3. **Reproducible**: Anyone can build and deploy the same binary
4. **No Pollution**: git ignores build directory, no binaries in repo
5. **Clear Intent**: `./build/` clearly indicates deployment artifacts

## Migration Notes

-   Old scripts that used `go/bin` are now updated
-   `build/` directory auto-created by scripts
-   No manual migration needed
-   Existing `go/bin` binaries unaffected (still work for local dev)
