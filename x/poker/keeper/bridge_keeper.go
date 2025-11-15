package keeper

import (
	"context"
	"fmt"

	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// ProcessBridgeDeposit handles a bridge deposit from Ethereum
// This method can be called by the bridge service or validators
func (k Keeper) ProcessBridgeDeposit(ctx context.Context, ethTxHash string, recipient string, amount uint64, nonce uint64) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/bridge")

	logger.Info("🔷 trackMint: Starting deposit processing",
		"txHash", ethTxHash,
		"recipient", recipient,
		"amount", amount,
		"nonce", nonce,
	)

	// Check if transaction was already processed
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, ethTxHash); err != nil {
		logger.Error("❌ trackMint: Failed to check processed transactions", "error", err)
		return fmt.Errorf("failed to check processed transactions: %w", err)
	} else if exists {
		logger.Warn("⚠️ trackMint: Transaction already processed", "txHash", ethTxHash)
		return types.ErrTxAlreadyProcessed
	}

	logger.Info("✅ trackMint: Transaction not yet processed, continuing...")

	// Validate recipient address
	recipientAddr, err := k.addressCodec.StringToBytes(recipient)
	if err != nil {
		logger.Error("❌ trackMint: Invalid recipient address", "recipient", recipient, "error", err)
		return fmt.Errorf("invalid recipient address: %w", err)
	}

	recipientStr, _ := k.addressCodec.BytesToString(recipientAddr)
	logger.Info("✅ trackMint: Recipient address validated", "recipientAddr", recipientStr)

	// Ensure account exists before sending coins
	account := k.authKeeper.GetAccount(ctx, recipientAddr)
	if account == nil {
		logger.Info("📝 trackMint: Account doesn't exist, creating new account", "recipient", recipient)
		account = k.authKeeper.NewAccountWithAddress(ctx, recipientAddr)
		k.authKeeper.SetAccount(ctx, account)
		logger.Info("✅ trackMint: New account created successfully")
	} else {
		logger.Info("✅ trackMint: Account already exists")
	}

	// Validate amount
	if amount == 0 {
		logger.Error("❌ trackMint: Invalid amount (zero)")
		return types.ErrInvalidAmount
	}

	logger.Info("✅ trackMint: Amount validated", "amount", amount)

	// Create coins to mint
	coins := sdk.NewCoins(sdk.NewInt64Coin("usdc", int64(amount)))

	logger.Info("🪙 trackMint: Minting coins to module account",
		"module", types.ModuleName,
		"coins", coins.String(),
	)

	// Mint coins to module account
	if err := k.bankKeeper.MintCoins(ctx, types.ModuleName, coins); err != nil {
		logger.Error("❌ trackMint: Failed to mint coins", "error", err)
		return fmt.Errorf("failed to mint coins: %w", err)
	}

	logger.Info("✅ trackMint: Coins minted successfully to module account")

	logger.Info("💸 trackMint: Sending coins to recipient",
		"from_module", types.ModuleName,
		"to_recipient", recipient,
		"coins", coins.String(),
	)

	// Send to recipient
	if err := k.bankKeeper.SendCoinsFromModuleToAccount(ctx, types.ModuleName, recipientAddr, coins); err != nil {
		logger.Error("❌ trackMint: Failed to send coins to recipient", "error", err)
		return fmt.Errorf("failed to send coins: %w", err)
	}

	logger.Info("✅ trackMint: Coins sent successfully to recipient", "recipient", recipient)

	logger.Info("📝 trackMint: Marking transaction as processed", "txHash", ethTxHash)

	// Mark as processed
	if err := k.ProcessedEthTxs.Set(sdkCtx, ethTxHash); err != nil {
		logger.Error("❌ trackMint: Failed to mark transaction as processed", "error", err)
		return fmt.Errorf("failed to mark transaction as processed: %w", err)
	}

	logger.Info("✅ trackMint: Transaction marked as processed")

	// Emit event
	sdkCtx.EventManager().EmitEvent(
		sdk.NewEvent(
			"bridge_deposit_processed",
			sdk.NewAttribute("eth_tx_hash", ethTxHash),
			sdk.NewAttribute("recipient", recipient),
			sdk.NewAttribute("amount", coins.String()),
			sdk.NewAttribute("nonce", fmt.Sprintf("%d", nonce)),
		),
	)

	logger.Info("🎉 trackMint: Deposit processed successfully!",
		"txHash", ethTxHash,
		"recipient", recipient,
		"amount", coins.String(),
	)

	return nil
}

// IsTransactionProcessed checks if an Ethereum transaction has been processed
func (k Keeper) IsTransactionProcessed(ctx context.Context, ethTxHash string) (bool, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	return k.ProcessedEthTxs.Has(sdkCtx, ethTxHash)
}

// GetProcessedTransactions returns all processed Ethereum transaction hashes
func (k Keeper) GetProcessedTransactions(ctx context.Context) ([]string, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	var txHashes []string

	err := k.ProcessedEthTxs.Walk(sdkCtx, nil, func(key string) (stop bool, err error) {
		txHashes = append(txHashes, key)
		return false, nil
	})

	return txHashes, err
}

// ValidateEthereumTransaction performs additional validation on Ethereum transactions
func (k Keeper) ValidateEthereumTransaction(ctx context.Context, ethTxHash string, expectedAmount uint64, expectedRecipient string) error {
	// This is where you would add custom validation logic
	// For example:
	// - Check against a whitelist of valid Ethereum addresses
	// - Validate transaction confirmation count
	// - Check for minimum/maximum deposit amounts
	// - Verify the transaction came from the correct contract

	// Placeholder validation
	if len(ethTxHash) < 66 { // Ethereum transaction hashes are 66 characters (0x + 64 hex chars)
		return fmt.Errorf("invalid ethereum transaction hash format")
	}

	if expectedAmount == 0 {
		return types.ErrInvalidAmount
	}

	if len(expectedRecipient) == 0 {
		return types.ErrInvalidRecipient
	}

	return nil
}
