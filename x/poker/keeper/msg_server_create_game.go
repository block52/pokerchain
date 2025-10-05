package keeper

import (
	"context"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
)

func (k msgServer) CreateGame(ctx context.Context, msg *types.MsgCreateGame) (*types.MsgCreateGameResponse, error) {
	// Validate creator address
	creatorAddr, err := k.addressCodec.StringToBytes(msg.Creator)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid creator address")
	}

	// Check if creator has enough tokens
	creatorBalance := k.bankKeeper.SpendableCoins(ctx, creatorAddr)
	tokenCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(types.GameCreationCost))

	if !creatorBalance.IsAllGTE(sdk.NewCoins(tokenCoin)) {
		return nil, errorsmod.Wrapf(sdkerrors.ErrInsufficientFunds,
			"creator needs %s to create a game, but only has %s",
			tokenCoin.String(),
			creatorBalance.AmountOf(types.TokenDenom).String())
	}

	// Deduct tokens from creator account and send to module account
	if err := k.bankKeeper.SendCoinsFromAccountToModule(
		ctx,
		creatorAddr,
		types.ModuleName,
		sdk.NewCoins(tokenCoin),
	); err != nil {
		return nil, errorsmod.Wrap(err, "failed to deduct game creation cost")
	}

	// TODO: Implement actual game creation logic here
	// This would involve:
	// - Generating a unique game ID
	// - Creating game state
	// - Storing game in keeper
	// - Emitting events

	return &types.MsgCreateGameResponse{}, nil
}
