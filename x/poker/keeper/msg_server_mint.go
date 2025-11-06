package keeper

import (
	"context"
	"fmt"

	errorsmod "cosmossdk.io/errors"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func (k msgServer) Mint(ctx context.Context, msg *types.MsgMint) (*types.MsgMintResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(err, "invalid authority address")
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/mint")

	// Validate the message
	if err := msg.ValidateBasic(); err != nil {
		return nil, errorsmod.Wrap(err, "invalid mint message")
	}

	// Check if the Ethereum transaction has already been processed
	if exists, err := k.ProcessedEthTxs.Has(sdkCtx, msg.EthTxHash); err != nil {
		return nil, errorsmod.Wrap(err, "failed to check processed transactions")
	} else if exists {
		return nil, errorsmod.Wrap(types.ErrTxAlreadyProcessed, "ethereum transaction already processed")
	}

	// Validate recipient address
	recipientAddr, err := k.addressCodec.StringToBytes(msg.Recipient)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid recipient address")
	}

	// VERIFY THE DEPOSIT ON ETHEREUM
	// This ensures the deposit actually happened and matches the claimed parameters
	logger.Info("🔍 Verifying Ethereum deposit",
		"eth_tx_hash", msg.EthTxHash,
		"recipient", msg.Recipient,
		"amount", msg.Amount,
		"nonce", msg.Nonce,
	)

	// Create bridge verifier
	verifier, err := NewBridgeVerifier(k.ethRPCURL, k.depositContractAddr)
	if err != nil {
		logger.Error("❌ Failed to create bridge verifier", "error", err)
		return nil, errorsmod.Wrap(err, "failed to create bridge verifier")
	}
	defer verifier.Close()

	// Verify the deposit on Ethereum
	verification, err := verifier.VerifyDeposit(
		ctx,
		msg.EthTxHash,
		msg.Recipient,
		msg.Amount,
		msg.Nonce,
	)
	if err != nil {
		logger.Error("❌ Ethereum deposit verification failed", "error", err)
		return nil, errorsmod.Wrap(err, "ethereum deposit verification failed")
	}

	if !verification.Verified {
		logger.Error("❌ Deposit not verified")
		return nil, errorsmod.Wrap(fmt.Errorf("deposit not verified"), "invalid deposit")
	}

	logger.Info("✅ Ethereum deposit verified successfully",
		"recipient", verification.Recipient,
		"amount", verification.Amount,
		"nonce", verification.Nonce,
	)

	// Create coins to mint (assuming USDC with 6 decimals, so amount is in micro-USDC)
	coins := sdk.NewCoins(sdk.NewInt64Coin("uusdc", int64(msg.Amount)))

	// Mint coins to the module account first
	if err := k.bankKeeper.MintCoins(ctx, types.ModuleName, coins); err != nil {
		return nil, errorsmod.Wrap(err, "failed to mint coins")
	}

	// Send minted coins to the recipient
	if err := k.bankKeeper.SendCoinsFromModuleToAccount(ctx, types.ModuleName, recipientAddr, coins); err != nil {
		return nil, errorsmod.Wrap(err, "failed to send coins to recipient")
	}

	// Mark the Ethereum transaction as processed to prevent double spending
	if err := k.ProcessedEthTxs.Set(sdkCtx, msg.EthTxHash); err != nil {
		return nil, errorsmod.Wrap(err, "failed to mark transaction as processed")
	}

	// Emit an event for the successful mint
	sdkCtx.EventManager().EmitEvent(
		sdk.NewEvent(
			"bridge_mint",
			sdk.NewAttribute("recipient", msg.Recipient),
			sdk.NewAttribute("amount", sdk.NewInt64Coin("uusdc", int64(msg.Amount)).String()),
			sdk.NewAttribute("eth_tx_hash", msg.EthTxHash),
			sdk.NewAttribute("nonce", fmt.Sprintf("%d", msg.Nonce)),
		),
	)

	return &types.MsgMintResponse{}, nil
}
