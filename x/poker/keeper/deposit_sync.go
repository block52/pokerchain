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
func (k Keeper) ProcessNextDeposit(ctx context.Context) (bool, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/deposit_sync")

	// Get the last processed deposit index
	lastIndex, err := k.GetLastProcessedDepositIndex(ctx)
	if err != nil {
		// If not set, start from 0
		lastIndex = 0
	}

	nextIndex := lastIndex + 1

	// Get the Ethereum block height to use for the query
	// We use a finalized block height that's agreed upon by consensus
	ethBlockHeight, err := k.GetLastEthBlockHeight(ctx)
	if err != nil || ethBlockHeight == 0 {
		// Query current Ethereum block and use a finalized height (current - 64 blocks for safety)
		verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
		if err != nil {
			logger.Error("Failed to create bridge verifier", "error", err)
			return false, nil // Don't halt chain, just skip this block
		}
		defer verifier.Close()

		currentBlock, err := verifier.ethClient.BlockNumber(ctx)
		if err != nil {
			logger.Error("Failed to get current Ethereum block", "error", err)
			return false, nil
		}

		// Use a finalized block height (64 blocks behind for safety)
		// This ensures all validators query at the same height
		if currentBlock > 64 {
			ethBlockHeight = currentBlock - 64
		} else {
			ethBlockHeight = currentBlock
		}

		// Store this height so all future queries in this round use the same height
		if err := k.SetLastEthBlockHeight(ctx, ethBlockHeight); err != nil {
			logger.Error("Failed to set last eth block height", "error", err)
		}
	}

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
		logger.Error("Failed to process bridge deposit", "error", err)
		return false, nil // Don't halt chain
	}

	// Update the last processed index
	if err := k.SetLastProcessedDepositIndex(ctx, nextIndex); err != nil {
		logger.Error("Failed to update last processed index", "error", err)
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
