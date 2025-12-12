# Auto-Sync Deposit Fix Plan

## Problem Summary

The auto-sync deposit feature requires a relayer to bootstrap `eth_block_height` before auto-sync works. We need true auto-sync without manual intervention.

## The Constraint

All validators **MUST query Ethereum at the same block height** for consensus. The block height used by the first validator must be known by all other validators.

## Solution: Derive eth_block_height from Cosmos Block

Instead of requiring a relayer to set `eth_block_height`, derive it deterministically from the Cosmos block:

```go
func (k Keeper) ProcessNextDeposit(ctx context.Context) (bool, error) {
    sdkCtx := sdk.UnwrapSDKContext(ctx)

    // DETERMINISTIC: All validators in the same Cosmos block have the same block height/time
    cosmosBlockHeight := sdkCtx.BlockHeight()
    cosmosBlockTime := sdkCtx.BlockTime().Unix()

    // Calculate a deterministic Ethereum block height
    // Base L2: ~2 second blocks, started around June 2023
    // Use a conservative estimate that's guaranteed to be finalized
    baseGenesisTime := int64(1686789347) // Base mainnet genesis
    secondsSinceGenesis := cosmosBlockTime - baseGenesisTime
    estimatedEthBlock := uint64(secondsSinceGenesis / 2) // ~2 sec per block

    // Use finalized height (current - 64 blocks for safety)
    safeEthBlock := estimatedEthBlock - 64

    // Query at this deterministic height
    depositData, err := verifier.GetDepositByIndex(ctx, nextIndex, safeEthBlock)
    // ...
}
```

**Why This Works:**
1. All validators processing the same Cosmos block have identical `BlockHeight()` and `BlockTime()`
2. The Ethereum block height is derived from these deterministic values
3. All validators query Ethereum at the exact same block height
4. No relayer bootstrap required

## Files to Modify

| File | Change |
|------|--------|
| `x/poker/keeper/deposit_sync.go` | Replace `GetLastEthBlockHeight()` check with Cosmos-derived height calculation |

## Risks

1. **Block time estimation error**: If Base chain changes block times or our genesis time is wrong, the estimate could be off. Mitigation: Use `-64` blocks safety margin.
2. **RPC failures**: Same as before - if one validator's RPC fails, consensus could break.

## Open Question

Should we store the derived `eth_block_height` in state after processing? This would allow queries to know which Eth block was used for auditing, but isn't strictly necessary for consensus.
