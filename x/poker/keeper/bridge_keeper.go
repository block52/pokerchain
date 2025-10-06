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

	// Check if transaction was already processed
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, ethTxHash); err != nil {
		return fmt.Errorf("failed to check processed transactions: %w", err)
	} else if exists {
		return types.ErrTxAlreadyProcessed
	}

	// Validate recipient address
	recipientAddr, err := k.addressCodec.StringToBytes(recipient)
	if err != nil {
		return fmt.Errorf("invalid recipient address: %w", err)
	}

	// Validate amount
	if amount == 0 {
		return types.ErrInvalidAmount
	}

	// Create coins to mint
	coins := sdk.NewCoins(sdk.NewInt64Coin("uusdc", int64(amount)))

	// Mint coins to module account
	if err := k.bankKeeper.MintCoins(ctx, types.ModuleName, coins); err != nil {
		return fmt.Errorf("failed to mint coins: %w", err)
	}

	// Send to recipient
	if err := k.bankKeeper.SendCoinsFromModuleToAccount(ctx, types.ModuleName, recipientAddr, coins); err != nil {
		return fmt.Errorf("failed to send coins: %w", err)
	}

	// Mark as processed
	if err := k.ProcessedEthTxs.Set(sdkCtx, ethTxHash); err != nil {
		return fmt.Errorf("failed to mark transaction as processed: %w", err)
	}

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
