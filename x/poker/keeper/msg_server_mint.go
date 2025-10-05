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
