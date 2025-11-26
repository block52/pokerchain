package keeper

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

const (
	// DepositCheckInterval is how often to check for new deposits (10 minutes)
	DepositCheckInterval = 10 * time.Minute
	// MaxDepositsPerBatch limits how many deposits to process per check (rate limiting)
	MaxDepositsPerBatch = 10
)

// ProcessPendingDeposits checks for missing deposits on Ethereum and processes them automatically
// This function is called from EndBlock and enforces:
// 1. 10-minute interval between checks (rate limiting)
// 2. Maximum 10 deposits per batch
// 3. Deterministic storage of L1 block number with each deposit
func (k *Keeper) ProcessPendingDeposits(ctx context.Context) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/auto_deposit_processor")

	// Check if bridge is configured
	if k.ethRPCURL == "" || k.depositContractAddr == "" {
		// Bridge not configured, skip silently
		return nil
	}

	// Get last check time
	lastCheckTime, err := k.LastDepositCheckTime.Get(sdkCtx)
	if err != nil {
		// First time, initialize to 0
		lastCheckTime = 0
	}

	// Check if 10 minutes have passed since last check
	currentTime := sdkCtx.BlockTime().Unix()
	timeSinceLastCheck := time.Duration(currentTime-lastCheckTime) * time.Second

	if timeSinceLastCheck < DepositCheckInterval {
		// Not time yet, skip
		return nil
	}

	logger.Info("🔍 Checking for pending deposits",
		"time_since_last_check", timeSinceLastCheck.String(),
		"contract", k.depositContractAddr,
	)

	// Update last check time
	if err := k.LastDepositCheckTime.Set(sdkCtx, currentTime); err != nil {
		logger.Error("❌ Failed to update last check time", "error", err)
		return err
	}

	// Create bridge verifier to query Ethereum
	verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
	if err != nil {
		logger.Error("❌ Failed to create bridge verifier", "error", err)
		return err
	}
	defer verifier.Close()

	// Get current Ethereum block number for determinism
	ethBlockNumber, err := verifier.GetEthereumBlockNumber(ctx)
	if err != nil {
		logger.Error("❌ Failed to get Ethereum block number", "error", err)
		return err
	}

	logger.Info("📊 Current Ethereum block", "block_number", ethBlockNumber)

	// Get highest deposit index from Ethereum contract
	highestIndex, err := verifier.GetHighestDepositIndex(ctx)
	if err != nil {
		logger.Error("❌ Failed to get highest deposit index", "error", err)
		return err
	}

	logger.Info("📈 Highest deposit index on Ethereum", "index", highestIndex)

	// If no deposits exist, nothing to do
	if highestIndex == 0 {
		// Check if index 0 exists and is processed
		hasIndex0, err := k.ProcessedDepositIndices.Has(sdkCtx, 0)
		if err != nil {
			return err
		}
		if hasIndex0 {
			// Index 0 processed and no more deposits
			logger.Info("ℹ️  No deposits to process")
			return nil
		}
		// Otherwise, index 0 might not be processed yet, continue to check
	}

	// Find missing deposit indices (gaps between 0 and highestIndex)
	missingIndices := make([]uint64, 0, MaxDepositsPerBatch)
	for i := uint64(0); i <= highestIndex && len(missingIndices) < MaxDepositsPerBatch; i++ {
		// Check if this index has been processed
		hasIndex, err := k.ProcessedDepositIndices.Has(sdkCtx, i)
		if err != nil {
			logger.Error("❌ Failed to check processed index", "index", i, "error", err)
			continue
		}

		if !hasIndex {
			missingIndices = append(missingIndices, i)
		}
	}

	if len(missingIndices) == 0 {
		logger.Info("✅ All deposits up to index are processed", "highest_index", highestIndex)
		return nil
	}

	logger.Info("🔄 Found missing deposit indices",
		"count", len(missingIndices),
		"indices", missingIndices,
		"eth_block", ethBlockNumber,
	)

	// Process each missing deposit
	processedCount := 0
	for _, depositIndex := range missingIndices {
		if err := k.processDepositByIndex(ctx, verifier, depositIndex, ethBlockNumber); err != nil {
			logger.Error("❌ Failed to process deposit",
				"index", depositIndex,
				"error", err,
			)
			// Continue with next deposit instead of failing entire batch
			continue
		}
		processedCount++
	}

	logger.Info("✅ Automatic deposit processing completed",
		"processed", processedCount,
		"total_missing", len(missingIndices),
		"eth_block", ethBlockNumber,
	)

	return nil
}

// processDepositByIndex processes a single deposit by its index
func (k *Keeper) processDepositByIndex(
	ctx context.Context,
	verifier *BridgeVerifier,
	depositIndex uint64,
	ethBlockNumber uint64,
) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/auto_deposit_processor")

	logger.Info("🔍 Querying deposit from Ethereum",
		"index", depositIndex,
		"eth_block", ethBlockNumber,
	)

	// Query Ethereum contract for deposit data by index
	depositData, err := verifier.GetDepositByIndex(ctx, depositIndex)
	if err != nil {
		return fmt.Errorf("failed to query deposit from ethereum: %w", err)
	}

	logger.Info("✅ Deposit data retrieved",
		"account", depositData.Account,
		"amount", depositData.Amount.String(),
		"index", depositData.Index,
	)

	// Generate deterministic txHash from contract address + deposit index
	txHashInput := fmt.Sprintf("%s-%d", k.depositContractAddr, depositIndex)
	hash := sha256.Sum256([]byte(txHashInput))
	ethTxHash := "0x" + hex.EncodeToString(hash[:])

	// Check if already processed via ProcessedEthTxs (double-check, shouldn't happen)
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, ethTxHash); err != nil {
		return fmt.Errorf("failed to check processed deposits: %w", err)
	} else if exists {
		logger.Warn("⚠️  Deposit already in ProcessedEthTxs, skipping",
			"index", depositIndex,
			"txHash", ethTxHash,
		)
		// Still mark it in ProcessedDepositIndices for tracking
		if err := k.ProcessedDepositIndices.Set(sdkCtx, depositIndex, ethBlockNumber); err != nil {
			return fmt.Errorf("failed to mark deposit index: %w", err)
		}
		return nil
	}

	// Convert amount from *big.Int to uint64
	amount := depositData.Amount.Uint64()

	// Process the deposit using existing logic
	logger.Info("🪙 Processing bridge deposit",
		"recipient", depositData.Account,
		"amount", amount,
		"nonce", depositData.Index,
		"txHash", ethTxHash,
		"eth_block", ethBlockNumber,
	)

	err = k.ProcessBridgeDeposit(ctx, ethTxHash, depositData.Account, amount, depositData.Index)
	if err != nil {
		return fmt.Errorf("failed to process bridge deposit: %w", err)
	}

	// Mark this deposit index as processed with L1 block number (for determinism)
	if err := k.ProcessedDepositIndices.Set(sdkCtx, depositIndex, ethBlockNumber); err != nil {
		return fmt.Errorf("failed to mark deposit index as processed: %w", err)
	}

	logger.Info("✅ Deposit processed and marked",
		"index", depositIndex,
		"recipient", depositData.Account,
		"amount", fmt.Sprintf("%d uusdc", amount),
		"eth_block", ethBlockNumber,
	)

	return nil
}
