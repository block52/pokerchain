package keeper

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"

	errorsmod "cosmossdk.io/errors"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func (k msgServer) ProcessDeposit(ctx context.Context, msg *types.MsgProcessDeposit) (*types.MsgProcessDepositResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(err, "invalid creator address")
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/process_deposit")

	logger.Info("🔷 Processing deposit by index",
		"deposit_index", msg.DepositIndex,
		"creator", msg.Creator,
		"eth_block_height", msg.EthBlockHeight,
	)

	// Create bridge verifier to query Ethereum
	verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
	if err != nil {
		logger.Error("❌ Failed to create bridge verifier", "error", err)
		return nil, errorsmod.Wrap(err, "failed to create bridge verifier")
	}
	defer verifier.Close()

	// Query Ethereum contract for deposit data by index
	// Use the specified eth_block_height for deterministic replay
	// If eth_block_height is 0, GetDepositByIndex will use the current block and return it
	logger.Info("🔍 Querying Ethereum contract for deposit",
		"contract", k.depositContractAddr,
		"deposit_index", msg.DepositIndex,
		"eth_block_height", msg.EthBlockHeight,
	)

	depositData, err := verifier.GetDepositByIndex(ctx, msg.DepositIndex, msg.EthBlockHeight)
	if err != nil {
		logger.Error("❌ Failed to query deposit from Ethereum", "error", err)
		return nil, errorsmod.Wrap(err, "failed to query deposit from ethereum")
	}

	logger.Info("✅ Deposit data retrieved from Ethereum",
		"account", depositData.Account,
		"amount", depositData.Amount.String(),
		"index", depositData.Index,
		"eth_block_height", depositData.EthBlockHeight,
	)

	// Generate deterministic txHash from contract address + deposit index
	// This ensures we have a unique identifier for this deposit even without the actual Ethereum tx hash
	txHashInput := fmt.Sprintf("%s-%d", k.depositContractAddr, msg.DepositIndex)
	hash := sha256.Sum256([]byte(txHashInput))
	ethTxHash := "0x" + hex.EncodeToString(hash[:])

	logger.Info("📝 Generated deterministic txHash",
		"txHash", ethTxHash,
		"input", txHashInput,
	)

	// Check if already processed - return error to prevent double-spend
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, ethTxHash); err != nil {
		logger.Error("❌ Failed to check if deposit already processed", "error", err)
		return nil, errorsmod.Wrap(err, "failed to check processed deposits")
	} else if exists {
		logger.Warn("⚠️  Deposit already processed - rejecting duplicate",
			"deposit_index", msg.DepositIndex,
			"txHash", ethTxHash,
		)
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest, "deposit index %d already processed (txHash: %s)", msg.DepositIndex, ethTxHash)
	}

	// Convert amount from *big.Int to uint64
	// Note: This assumes the amount fits in uint64. For USDC with 6 decimals, max is ~18 trillion USDC
	amount := depositData.Amount.Uint64()

	// Process the deposit using the existing ProcessBridgeDeposit logic
	logger.Info("🪙 Processing bridge deposit",
		"recipient", depositData.Account,
		"amount", amount,
		"nonce", depositData.Index,
		"txHash", ethTxHash,
	)

	err = k.ProcessBridgeDeposit(ctx, ethTxHash, depositData.Account, amount, depositData.Index)
	if err != nil {
		logger.Error("❌ Failed to process bridge deposit", "error", err)
		return nil, errorsmod.Wrap(err, "failed to process bridge deposit")
	}

	logger.Info("✅ Deposit processed successfully",
		"deposit_index", msg.DepositIndex,
		"recipient", depositData.Account,
		"amount", fmt.Sprintf("%d usdc", amount),
		"eth_block_height", depositData.EthBlockHeight,
	)

	// Return success response with the Ethereum block height used
	// This block height should be included in the transaction for deterministic replay
	return &types.MsgProcessDepositResponse{
		Recipient:      depositData.Account,
		Amount:         fmt.Sprintf("%d usdc", amount),
		DepositIndex:   msg.DepositIndex,
		EthBlockHeight: depositData.EthBlockHeight,
	}, nil
}
