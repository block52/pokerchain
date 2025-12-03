# Critical Bug: Non-Deterministic State Machine

## Issue
The blockchain experienced a consensus failure when a second validator was added. Both validators calculated different AppHashes for the same transactions, causing the network to halt at block 176447.

## Root Cause
**File**: `x/poker/keeper/msg_server_create_game.go`
**Line**: 64

```go
now := time.Now()  // ← NON-DETERMINISTIC!
game := types.Game{
    ...
    CreatedAt:  now,
    UpdatedAt:  now,
}
```

### Problem
Each validator calls `time.Now()` at slightly different wall-clock times when executing the same transaction. This produces different timestamps in the game state, resulting in different AppHashes.

## The Fix

Replace `time.Now()` with the block's timestamp, which is deterministic and agreed upon by all validators:

```go
// Get the SDK context
sdkCtx := sdk.UnwrapSDKContext(ctx)

// Use block time instead of wall clock time
now := sdkCtx.BlockTime()  // ← DETERMINISTIC

game := types.Game{
    ...
    CreatedAt:  now,
    UpdatedAt:  now,
}
```

## Why This Matters
In blockchain consensus, **every validator must compute identical state** when processing the same transactions. Any source of non-determinism breaks consensus:

- ❌ `time.Now()` - different on each validator
- ❌ `rand.Float64()` - produces random values
- ❌ Map iteration order - non-deterministic in Go
- ❌ External API calls - may return different data

- ✅ `ctx.BlockTime()` - agreed upon by consensus
- ✅ `ctx.BlockHeight()` - agreed upon by consensus
- ✅ Deterministic PRNGs seeded from block data

## Additional Non-Determinism Sources to Check

Based on grep results, these files may have other non-deterministic operations:

```
x/poker/keeper/msg_server_create_game.go (CONFIRMED - time.Now())
x/poker/types/types.go
x/poker/keeper/msg_server_perform_action.go
x/poker/keeper/query_game_state.go
x/poker/keeper/deck_helpers.go
```

Review each for:
1. `time.Now()` calls
2. Uninitialized random number generators
3. External data queries

## Testing
After applying the fix:

1. Reset both nodes to genesis
2. Add transactions that create games
3. Verify both validators produce identical AppHashes
4. Re-add the second validator
5. Monitor for consensus over several thousand blocks

## Impact
- Network halted at block 176447
- Required rollback to genesis and removal of second validator
- All state after block 1 was lost (games, players, deposits since 2025-12-03)

## Recovery Action Taken
1. Stopped both validators
2. Reset primary node to genesis
3. Restarted with single validator
4. Kept node1 offline until bug is fixed
