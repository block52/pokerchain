# Script Consolidation - RESOLVED

Date: October 30, 2025  
Status: ✅ COMPLETED - setup-genesis-node.sh removed

## Resolution

**Decision**: Removed `setup-genesis-node.sh` in favor of the modern `deploy-master-node.sh`

**Rationale**:

-   deploy-master-node.sh uses the new ./build/ directory approach (production standard)
-   Simpler, more maintainable script (256 lines vs 1193 lines)
-   Successfully deployed node1.block52.xyz on Oct 30, 2025
-   setup-network.sh now calls deploy-master-node.sh for genesis node setup

---

## Historical Analysis

Previously, we had two scripts that served similar purposes for deploying the master/genesis node:

### 1. setup-genesis-node.sh (REMOVED - Previously Oct 11)

-   **Size**: 1,193 lines
-   **Binary**: Uses `make install` → `go/bin/pokerchaind`
-   **Features**:
    -   Interactive setup
    -   UFW firewall configuration
    -   File permissions management (600/644)
    -   Comprehensive validation
    -   systemd service creation
    -   Public endpoint verification
-   **Status**: ❌ Uses old go/bin approach

### 2. deploy-master-node.sh (Newer - Oct 30)

-   **Size**: 256 lines
-   **Binary**: Uses `go build` → `./build/pokerchaind` ✅
-   **Features**:
    -   Automated deployment
    -   Fresh binary build
    -   systemd service management
    -   Configuration deployment
    -   Basic verification
-   **Status**: ✅ Uses new build/ directory approach
-   **Successfully deployed**: node1.block52.xyz on Oct 30, 2025

## Comparison

| Feature              | setup-genesis-node.sh | deploy-master-node.sh |
| -------------------- | --------------------- | --------------------- |
| Binary Location      | ❌ go/bin             | ✅ ./build/           |
| Lines of Code        | 1,193                 | 256                   |
| Interactive          | Yes                   | No (fully automated)  |
| Firewall Config      | Yes                   | No                    |
| File Permissions     | Detailed (600/644)    | Basic                 |
| Validation           | Comprehensive         | Basic                 |
| Deployment           | SSH-based             | SSH-based             |
| **Last Updated**     | Oct 11                | **Oct 30**            |
| **Production Ready** | Needs update          | **✅ Yes**            |

## Recommendation

### Option 1: Update setup-genesis-node.sh (Recommended)

Keep both scripts but update `setup-genesis-node.sh` to use `./build/` directory:

**Pros**:

-   Preserves advanced features (firewall, permissions, validation)
-   Gives users choice: simple vs comprehensive
-   setup-genesis-node.sh useful for initial server setup
-   deploy-master-node.sh useful for quick updates

**Changes Needed**:

```bash
# In setup-genesis-node.sh, replace:
make install
local gobin="${GOBIN:-${GOPATH:-$HOME/go}/bin}"

# With:
BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"
go build -o "$BUILD_DIR/pokerchaind" ./cmd/pokerchaind
LOCAL_BINARY="$BUILD_DIR/pokerchaind"
```

**Files to update**:

1. Line 192-230: `build_pokerchaind()` function
2. Line 564-581: systemd service PATH
3. Line 214: Binary verification location

### Option 2: Deprecate setup-genesis-node.sh

Remove the old script and only use `deploy-master-node.sh`:

**Pros**:

-   Single deployment path
-   Simpler maintenance
-   Already proven in production

**Cons**:

-   Loses firewall configuration
-   Loses detailed permission management
-   Loses comprehensive validation

### Option 3: Hybrid Approach (Best of Both Worlds)

Create a two-stage process:

1. **Initial Setup**: Use `setup-genesis-node.sh` (updated for ./build/)

    - First-time server configuration
    - Firewall, permissions, systemd
    - Comprehensive validation

2. **Updates/Redeployments**: Use `deploy-master-node.sh`
    - Quick binary updates
    - Configuration changes
    - Routine maintenance

## Current Documentation Status

### README.md

```bash
./setup-genesis-node.sh       # 🌐 Deploy genesis node to node1.block52.xyz
```

This should be updated to mention both scripts or just `deploy-master-node.sh`.

### DEPLOYMENT.md

Already references `deploy-master-node.sh` ✅

### BINARY-MANAGEMENT.md

States: "setup-genesis-node.sh - Documentation references only" ✅

## Recommended Action Plan

1. **Update setup-genesis-node.sh** to use `./build/` directory
2. **Update README.md** to clarify when to use each script:
    ```bash
    ./setup-genesis-node.sh      # Initial server setup (firewall, permissions, etc.)
    ./deploy-master-node.sh      # Deploy/update master node (recommended)
    ```
3. **Add deprecation notice** in setup-genesis-node.sh if you prefer deploy-master-node.sh
4. **Test both scripts** after updates

## My Recommendation

**Use Option 3 (Hybrid Approach)** with priority on `deploy-master-node.sh`:

1. ✅ Keep `deploy-master-node.sh` as primary deployment tool (already working)
2. ✅ Update `setup-genesis-node.sh` to use `./build/` for consistency
3. ✅ Document when to use each:
    - setup-genesis-node.sh: Initial server configuration
    - deploy-master-node.sh: Regular deployments (primary)
4. ✅ Update README.md to reflect this

This gives you:

-   Simple, proven deployment (deploy-master-node.sh)
-   Advanced setup when needed (setup-genesis-node.sh)
-   Consistent binary management across both

Would you like me to:
A) Update setup-genesis-node.sh to use `./build/`?
B) Add deprecation notice and recommend deploy-master-node.sh only?
C) Update README.md to clarify the difference?
