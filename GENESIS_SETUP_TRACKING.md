# Genesis Account Setup Tracking

## Objective
Fix setup-network.sh option 7 (CLI method) to fund Alice's account with 52 million STAKE like production.

## Progress Checklist

- [x] Find production script/config for genesis account funding
- [x] Identify Alice's address and mnemonic
- [x] Update run-local-testnet.sh CLI method (option 7 calls this)
- [x] Code changes complete - ready for testing
- [ ] Test the updated script
- [ ] Verify Alice has 52M STAKE after fresh init

## Research Findings

### Production Config: `config.yml`
Found that `config.yml` uses `b52Token` denomination, but actual production uses `stake`.
The `run-local-testnet.sh` script is what option 7 calls, and it's where the CLI method lives.

### Key Accounts (from config.yml)
| Name  | Mnemonic | Amount |
|-------|----------|--------|
| Alice | cement shadow leave crash crisp aisle model hip lend february library ten cereal soul bind boil bargain barely rookie odor panda artwork damage reason | 52,000,000 STAKE (validator) |
| Bob   | vanish legend pelican blush control spike useful usage into any remove wear flee short october naive swear wall spy cup sort avoid agent credit | 900,000 STAKE (faucet) |

### Technical Details
- 1 STAKE = 1,000,000 ustake
- 52 million STAKE = 52,000,000,000,000 ustake
- 900,000 STAKE = 900,000,000,000 ustake

### Current Problem
The `init_testnet_with_cli()` function in `run-local-testnet.sh`:
1. Creates a NEW random "validator" key (line 212)
2. Gives it only 1,000,000,000,000 stake (1 million STAKE)
3. Does NOT import Alice/Bob mnemonics

### Fix Required
1. Import Alice's mnemonic as "alice" key (for validator)
2. Import Bob's mnemonic as "bob" key (for faucet)
3. Fund Alice with 52,000,000,000,000 ustake (52M STAKE)
4. Fund Bob with 900,000,000,000 ustake (900K STAKE)

## Changes Made

**File:** `run-local-testnet.sh` (lines 210-236)

**Before:**
- Created random "validator" key
- Funded with 1,000,000,000,000 ustake (1M STAKE)

**After:**
- Imports Alice's mnemonic as "alice" key
- Alice gets 52,000,000,000,000 ustake (52M STAKE) - validator + faucet
- Genesis tx created for Alice as validator
- Faucet .env updated to use Alice's mnemonic

## Updates Log
- Started: Searching for production genesis config
- Found: config.yml has mnemonics, run-local-testnet.sh has CLI method
- Issue: CLI method creates random key instead of using known mnemonics
- Fixed: Updated init_testnet_with_cli() in run-local-testnet.sh
- Complete: Code changes applied, ready for testing

## Next Steps
1. Delete existing testnet data: `rm -rf ~/.pokerchain-testnet`
2. Run: `./setup-network.sh` → Option 7 → Single Node → CLI Commands Method
3. Verify: Alice should have 52M STAKE

---

## Additional Fix: TableAdminPage USDC Check

**Issue**: Game creation fails with error code 5 (insufficient funds) because user has 0 USDC

**Solution**: Updated `ui/src/pages/TableAdminPage.tsx` to:
- Show user's USDC balance in the header
- Display the creation fee (0.000001 USDC = 1 usdc base unit)
- Show warning message if insufficient USDC
- Disable "Create Table" button if no USDC
- Link to Dashboard for depositing USDC from Base Chain

**Chain Config** (from `pokerchain/x/poker/types/types.go`):
- `TokenDenom = "usdc"`
- `GameCreationCost = 1` (1 base unit = 0.000001 USDC)

---

## Additional Fix: BridgeAdminDashboard STAKE Check

**Issue**: Bridge deposit processing fails because user has no STAKE for gas fees

**Solution**: Updated `ui/src/pages/BridgeAdminDashboard.tsx` to:
- Show user's STAKE balance in stats cards (purple if enough, red if not)
- Show yellow warning message if insufficient STAKE
- Disable "Process" buttons if no STAKE
- Link to /faucet to get STAKE tokens

**Gas Fee Requirement**: ~2000 stake per transaction

---

## Additional Fix: Hole Cards Not Visible After Dealing

**Issue**: Players couldn't see their own hole cards after dealing - all cards showed as "X"

**Root Causes Found**:
1. **WebSocket server (`cmd/ws-server/main.go`) missing authentication support**:
   - `ClientMessage` struct didn't have `player_address`, `timestamp`, `signature` fields
   - `Client` struct didn't store auth credentials
   - `sendGameState()` always used public `Game` query (masks all cards) instead of authenticated `GameState` query
   - `BroadcastGameUpdate()` sent same masked data to all clients instead of personalized states

2. **Case-sensitive address comparison (`x/poker/keeper/query_game_state.go`)**:
   - `maskOtherPlayersCards()` used case-sensitive `!=` for address comparison
   - If addresses differed in case, player's own cards would be masked

**Solution**:
1. Updated `cmd/ws-server/main.go`:
   - Added auth fields to `ClientMessage` struct
   - Added auth storage to `Client` struct
   - Updated subscribe handler to capture auth credentials
   - Updated `sendGameState()` to use authenticated `GameState` query when available
   - Updated `BroadcastGameUpdate()` to send personalized state per client via `sendPersonalizedUpdate()`

2. Updated `x/poker/keeper/query_game_state.go`:
   - Added `strings` import
   - Changed `maskOtherPlayersCards()` to use `strings.ToLower()` for case-insensitive comparison
   - Added debug logging to trace address matching

**Verification**:
```
[GRPC] ✅ Using authenticated GameState for player b5219dj7nyvsj2aq8vrrhyuvlah05e6lx05r3ghqy3
Game data preview: "holeCards":["3H","JH"]  <- Player sees their cards!
```

**Status**: ✅ FIXED AND TESTED
