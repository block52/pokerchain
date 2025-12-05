package keeper

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

// GetLastProcessedDepositIndex returns the last processed deposit index
func (k Keeper) GetLastProcessedDepositIndex(ctx context.Context) (uint64, error) {
	return k.LastProcessedDepositIndex.Peek(ctx)
}

// SetLastProcessedDepositIndex sets the last processed deposit index
func (k Keeper) SetLastProcessedDepositIndex(ctx context.Context, index uint64) error {
	// Sequence.Set expects the next value, so we set it to index+1
	// This way Peek returns the current index
	return k.LastProcessedDepositIndex.Set(ctx, index+1)
}

// GetLastEthBlockHeight returns the last Ethereum block height used for queries
func (k Keeper) GetLastEthBlockHeight(ctx context.Context) (uint64, error) {
	return k.LastEthBlockHeight.Peek(ctx)
}

// SetLastEthBlockHeight sets the last Ethereum block height used for queries
func (k Keeper) SetLastEthBlockHeight(ctx context.Context, height uint64) error {
	return k.LastEthBlockHeight.Set(ctx, height+1)
}

// ProcessNextDeposit attempts to process the next deposit in the queue.
// It queries Ethereum for the next deposit index and processes it if found.
// Returns true if a deposit was processed, false otherwise.
//
// DETERMINISM: Querying Ethereum by deposit INDEX is deterministic because:
// - Deposit data at a given index is IMMUTABLE once written to the contract
// - Even if validators query at different Ethereum blocks, index N always returns same data
// - The only non-determinism would be if a deposit doesn't exist yet at one validator's query time
//   but does exist at another's - we handle this by only storing state on SUCCESS
//
// Flow:
// 1. Query Ethereum for deposit at next index (using stored or fresh block height)
// 2. If deposit exists and is valid → process it, store eth_block_height used
// 3. If deposit doesn't exist → return false (try again next block)
// 4. If deposit is invalid → skip it deterministically
func (k Keeper) ProcessNextDeposit(ctx context.Context) (bool, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/deposit_sync")

	// Get stored Ethereum block height (may be 0 on fresh chain)
	ethBlockHeight, err := k.GetLastEthBlockHeight(ctx)
	if err != nil {
		ethBlockHeight = 0
	}

	// CONSENSUS CRITICAL: If no eth_block_height is set, we MUST wait for a relayer
	// to set it via MsgProcessDeposit. Querying Ethereum for "current" block in EndBlock
	// is NON-DETERMINISTIC because validators can get different block heights at
	// slightly different times, causing AppHash mismatches and consensus failures.
	//
	// The relayer should:
	// 1. Query Ethereum for deposits
	// 2. Submit MsgProcessDeposit with a specific eth_block_height
	// 3. This stores the eth_block_height in consensus state
	// 4. All subsequent auto-syncs use that stored height
	if ethBlockHeight == 0 {
		logger.Debug("No eth_block_height set, waiting for relayer to bootstrap via MsgProcessDeposit")
		return false, nil
	}

	// Get the last processed deposit index
	lastIndex, err := k.GetLastProcessedDepositIndex(ctx)
	if err != nil {
		// If not set, start from 0
		lastIndex = 0
	}

	nextIndex := lastIndex + 1

	logger.Info("Checking for next deposit",
		"next_index", nextIndex,
		"eth_block_height", ethBlockHeight,
	)

	// Create bridge verifier to query Ethereum
	verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
	if err != nil {
		logger.Debug("Failed to create bridge verifier", "error", err)
		return false, nil // Don't halt chain
	}
	defer verifier.Close()

	// Query Ethereum contract for the next deposit
	depositData, err := verifier.GetDepositByIndex(ctx, nextIndex, ethBlockHeight)
	if err != nil {
		// No deposit found at this index (yet) - this is normal
		logger.Debug("No deposit found at index", "index", nextIndex, "error", err)
		return false, nil
	}

	logger.Info("Found deposit to process",
		"index", nextIndex,
		"account", depositData.Account,
		"amount", depositData.Amount.String(),
		"eth_block_height", ethBlockHeight,
	)

	// Generate deterministic txHash from contract address + deposit index
	txHashInput := fmt.Sprintf("%s-%d", k.depositContractAddr, nextIndex)
	hash := sha256.Sum256([]byte(txHashInput))
	ethTxHash := "0x" + hex.EncodeToString(hash[:])

	// Check if already processed (shouldn't happen, but safety check)
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, ethTxHash); err != nil {
		logger.Error("Failed to check if deposit processed", "error", err)
		return false, nil
	} else if exists {
		logger.Warn("Deposit already processed, updating index", "index", nextIndex)
		// Update the index to skip this deposit
		if err := k.SetLastProcessedDepositIndex(ctx, nextIndex); err != nil {
			logger.Error("Failed to update last processed index", "error", err)
		}
		return true, nil // Consider it processed
	}

	// Convert amount from *big.Int to uint64
	amount := depositData.Amount.Uint64()

	// Process the deposit
	err = k.ProcessBridgeDeposit(ctx, ethTxHash, depositData.Account, amount, depositData.Index)
	if err != nil {
		// CONSENSUS CRITICAL: If processing fails (e.g., invalid address), we MUST
		// skip this deposit deterministically to avoid retrying forever.
		// All validators will see the same deposit data and make the same decision.
		logger.Error("Failed to process bridge deposit, marking as skipped",
			"error", err,
			"index", nextIndex,
			"account", depositData.Account,
		)

		// Mark the tx hash as processed to prevent retries
		if setErr := k.ProcessedEthTxs.Set(sdkCtx, ethTxHash); setErr != nil {
			logger.Error("Failed to mark skipped deposit", "error", setErr)
		}

		// Update the last processed index to move past this deposit
		if setErr := k.SetLastProcessedDepositIndex(ctx, nextIndex); setErr != nil {
			logger.Error("Failed to update last processed index", "error", setErr)
		}

		// Store eth_block_height for consistency in future queries
		if setErr := k.SetLastEthBlockHeight(ctx, ethBlockHeight); setErr != nil {
			logger.Error("Failed to update eth_block_height", "error", setErr)
		}

		// Emit event for skipped deposit
		sdkCtx.EventManager().EmitEvents(sdk.Events{
			sdk.NewEvent(
				"deposit_skipped",
				sdk.NewAttribute("deposit_index", fmt.Sprintf("%d", nextIndex)),
				sdk.NewAttribute("recipient", depositData.Account),
				sdk.NewAttribute("amount", fmt.Sprintf("%d", amount)),
				sdk.NewAttribute("reason", err.Error()),
				sdk.NewAttribute("eth_block_height", fmt.Sprintf("%d", ethBlockHeight)),
			),
		})

		return true, nil // Return true to indicate we processed (skipped) this deposit
	}

	// Update state: last processed index AND eth_block_height
	// Storing eth_block_height ensures future queries use this height for consistency
	if err := k.SetLastProcessedDepositIndex(ctx, nextIndex); err != nil {
		logger.Error("Failed to update last processed index", "error", err)
	}
	if err := k.SetLastEthBlockHeight(ctx, ethBlockHeight); err != nil {
		logger.Error("Failed to update eth_block_height", "error", err)
	}

	logger.Info("Successfully processed deposit",
		"index", nextIndex,
		"recipient", depositData.Account,
		"amount", amount,
		"eth_block_height", ethBlockHeight,
	)

	// Emit event
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"deposit_synced",
			sdk.NewAttribute("deposit_index", fmt.Sprintf("%d", nextIndex)),
			sdk.NewAttribute("recipient", depositData.Account),
			sdk.NewAttribute("amount", fmt.Sprintf("%d", amount)),
			sdk.NewAttribute("eth_block_height", fmt.Sprintf("%d", ethBlockHeight)),
		),
	})

	return true, nil
}

// UpdateEthBlockHeight updates the Ethereum block height used for deposit queries.
// This MUST be called via a transaction to ensure all validators update at the same time.
// The height should be a finalized Ethereum block (at least 64 blocks behind current).
func (k Keeper) UpdateEthBlockHeight(ctx context.Context, height uint64) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/deposit_sync")

	// Get current height for logging
	currentHeight, _ := k.GetLastEthBlockHeight(ctx)

	// Update the height
	if err := k.SetLastEthBlockHeight(ctx, height); err != nil {
		return err
	}

	logger.Info("Updated eth_block_height",
		"old_height", currentHeight,
		"new_height", height,
	)

	// Emit event
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"eth_block_height_updated",
			sdk.NewAttribute("old_height", fmt.Sprintf("%d", currentHeight)),
			sdk.NewAttribute("new_height", fmt.Sprintf("%d", height)),
		),
	})

	return nil
}

// GetDepositContractCount queries the Ethereum contract for the total deposit count
func (k Keeper) GetDepositContractCount(ctx context.Context) (uint64, error) {
	verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
	if err != nil {
		return 0, err
	}
	defer verifier.Close()

	// Query the depositCount from the contract
	// This would need to be implemented in bridge_verifier.go
	// For now, we'll try to get deposits sequentially until we hit an error
	return 0, fmt.Errorf("deposit count query not implemented")
}

// EnsureDepositSyncInitialized initializes the deposit sync state if not already set
func (k Keeper) EnsureDepositSyncInitialized(ctx context.Context) error {
	_, err := k.GetLastProcessedDepositIndex(ctx)
	if err != nil {
		// Initialize to 0 (no deposits processed yet)
		return k.SetLastProcessedDepositIndex(ctx, 0)
	}
	return nil
}
