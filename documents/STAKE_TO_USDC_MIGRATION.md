# Migration: Stake to USDC as Native Token

## Overview

This document tracks all changes required to migrate the Pokerchain native token from `stake` to `usdc` (bridged USDC from Base).

**Goal:** Make the bridged USDC from Base the native token for all chain operations including staking, gas fees, and governance.

---

## Critical Code Changes

### 1. Core Application Code

- [ ] **app/app.go:116** - Change `sdk.DefaultBondDenom = "stake"` to `"usdc"`

### 2. Genesis Configuration

- [ ] **genesis.json** - Update all `"denom": "stake"` references:
  - Lines 49, 58, 66: Bank balances
  - Lines 170, 222, 238: Staking delegations
  - Line 328: `"mint_denom": "stake"` → `"usdc"`
  - Line 365: `"bond_denom": "stake"` → `"usdc"`

- [ ] **production/node0/config/genesis.json** - Same changes as above

### 3. App Configuration Files

- [ ] **app.toml:11** - Change `minimum-gas-prices = "0.0stake"` → `"0.0usdc"`
- [ ] **production/node0/config/app.toml:11** - Change `minimum-gas-prices = "0stake"` → `"0usdc"`
- [ ] **template-app.toml:11** - Change `minimum-gas-prices = "0stake"` → `"0usdc"`
- [ ] **template-app.toml:176** - Change `denom-to-suggest = "stake"` → `"usdc"` (Rosetta API)

---

## Shell Scripts

### Setup Scripts

- [ ] **run-local-testnet.sh**
  - Line 208: `--default-denom stake` → `usdc`
  - Line 223: `52000000000000stake` → `usdc`
  - Line 227: `5000000000stake` → `usdc`
  - Line 451: `--minimum-gas-prices="0.01stake"` → `usdc`

- [ ] **setup-local-nodes.sh**
  - Lines 177-180: jq operations for `bond_denom`
  - Lines 304-311: sed commands for minimum-gas-prices
  - Line 356: Template usage echo

- [ ] **setup-production-nodes.sh**
  - Lines 24-25: `STAKE_AMOUNT` and `INITIAL_BALANCE` variables
  - Lines 870-876: sed commands for minimum-gas-prices

- [ ] **run-dev-node.sh**
  - Lines 320-322: sed commands for app.toml
  - Line 405: Start command `--minimum-gas-prices`

- [ ] **deploy-sync-node.sh**
  - Lines 565, 567: sed commands for minimum-gas-prices
  - Line 696: systemd ExecStart command

- [ ] **start-node.sh:190** - `--minimum-gas-prices="0.01stake"` → `usdc`

- [ ] **setup-network.sh**
  - Lines 1803, 1810, 1923, 1935-1936, 1954, 1971: Interactive prompts and transactions

### Bridge Scripts

- [ ] **process-bridge.sh:43** - `GAS_PRICES="0.001stake"` → `usdc`
- [ ] **process-bridge.sh.bak:46** - `GAS_PRICES="0stake"` → `usdc`

### Test Scripts

- [ ] **test-poker-flow.sh** - Lines 94, 127, 160: `--gas-prices=0stake` → `usdc`
- [ ] **test-poker-simple.sh** - Lines 34, 62, 91: `--gas-prices=0.001stake` → `usdc`
- [ ] **add-test-actors.sh** - Lines 6, 20, 42: Token references
- [ ] **add-validator.sh** - Lines 5, 91-92, 138, 149, 155: Stake transfer references

---

## TypeScript Client

- [ ] **ts-client/client.ts**
  - Line 15: Update comment about minimum-gas-prices
  - Lines 119-121: Dynamic - will auto-update from chain params (no change needed)

- [ ] **ts-client/pokerchain.poker.v1/module.ts:152** - Update comment

---

## Go Command-Line Tools (Comments Only)

- [ ] **cmd/create-table/main.go:124** - Update comment
- [ ] **cmd/join-game/main.go:147** - Update comment
- [ ] **cmd/leave-game/main.go:119** - Update comment
- [ ] **cmd/perform-action/main.go:158** - Update comment
- [ ] **cmd/poker-cli/main.go:782** - Update comment

---

## Documentation Updates

### Primary Documentation

- [ ] **documents/README.md** - Lines 229, 232, 235, 239, 381
- [ ] **documents/VALIDATOR_GUIDE.md** - Lines 116, 136-143, 153, 331, 376, 380, 548
- [ ] **documents/GENESIS_SUMMARY.md** - Lines 36, 38, 51
- [ ] **documents/TEST_ACTORS.md** - Lines 39, 86, 101
- [ ] **documents/RUN_DEV_NODE.md:264** - Bank send example
- [ ] **documents/DEPLOYMENT.md:54** - minimum-gas-prices
- [ ] **documents/BRIDGE_DEPOSIT_FLOW.md** - Multiple lines (extensive)
- [ ] **documents/CLAUDE.md:14** - Historical note

### Secondary Documentation

- [ ] **docs/ADD-VALIDATOR.md** - Lines 11, 19, 40, 147, 194, 197, 201, 217
- [ ] **docs/GENESIS_COMPARISON.md** - Multiple lines (technical analysis)
- [ ] **GENESIS_SETUP_TRACKING.md** - Lines 18, 28-30, 35, 41-42, 50, 54, 99

### Command Documentation

- [ ] **cmd/create-table/README.md** - Lines 104, 106, 108, 125
- [ ] **cmd/join-game/README.md** - Lines 130, 155
- [ ] **cmd/leave-game/README.md:124**
- [ ] **cmd/perform-action/README.md** - Lines 19, 188
- [ ] **cmd/poker-cli/README.md** - Lines 96, 184, 235, 242, 259

---

## Makefile

- [ ] **Makefile:228** - Docker environment variable (currently b52Token, update to usdc)

---

## Backup Files (Optional Cleanup)

- [ ] **backups/genesis-backup-20251117.json** - Update or delete
- [ ] **backups/genesis-minimal-b52Token.json** - Historical, can delete

---

## Already Correct (No Changes Needed)

These files already use `usdc` correctly:
- `x/poker/types/types.go` - `TokenDenom = "usdc"`
- `x/poker/keeper/withdrawal_keeper.go` - `USDC_DENOM = "usdc"`

---

## Migration Steps

### Phase 1: Code Changes
1. Update `app/app.go` DefaultBondDenom
2. Update all shell scripts
3. Update configuration templates

### Phase 2: Genesis Recreation
1. Create new genesis with usdc as bond_denom and mint_denom
2. Migrate any existing state or start fresh

### Phase 3: Documentation
1. Update all documentation files
2. Update README files in cmd directories

### Phase 4: Testing
1. Run local testnet with new configuration
2. Test all poker operations
3. Test bridge deposit/withdrawal flows
4. Verify staking and governance work with usdc

---

## Important Considerations

1. **Chain Reset Required**: Changing the native token requires a genesis reset
2. **Bridge Integration**: Ensure bridge contract can mint usdc for staking
3. **Decimal Precision**: USDC has 6 decimals - verify all amount calculations
4. **Gas Price Adjustment**: May need to adjust gas prices for usdc denomination
5. **Existing Balances**: Any existing stake balances will be lost in migration

---

## References

- Previous migration attempt: b52Token → stake (Oct 18, 2025)
- Historical genesis: `backups/genesis-minimal-b52Token.json`
