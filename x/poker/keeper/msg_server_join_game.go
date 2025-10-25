package keeper

import (
	"context"
	"fmt"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	"github.com/block52/pokerchain/x/poker/types"
)

func (k msgServer) JoinGame(ctx context.Context, msg *types.MsgJoinGame) (*types.MsgJoinGameResponse, error) {
	// Validate player address
	playerAddr, err := k.addressCodec.StringToBytes(msg.Player)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid player address")
	}

	// Check if game exists
	game, err := k.Games.Get(ctx, msg.GameId)
	if err != nil {
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}

	// Verify buy-in amount is within game limits
	if msg.BuyInAmount < game.MinBuyIn || msg.BuyInAmount > game.MaxBuyIn {
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest,
			"buy-in amount %d must be between %d and %d",
			msg.BuyInAmount, game.MinBuyIn, game.MaxBuyIn)
	}

	// Check if player has enough balance for buy-in
	playerBalance := k.bankKeeper.SpendableCoins(ctx, playerAddr)
	buyInCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(int64(msg.BuyInAmount)))

	if !playerBalance.IsAllGTE(sdk.NewCoins(buyInCoin)) {
		return nil, errorsmod.Wrapf(sdkerrors.ErrInsufficientFunds,
			"player needs %s to join, but only has %s",
			buyInCoin.String(),
			playerBalance.AmountOf(types.TokenDenom).String())
	}

	// Transfer buy-in amount from player to module account (game pot)
	if err := k.bankKeeper.SendCoinsFromAccountToModule(
		ctx,
		playerAddr,
		types.ModuleName,
		sdk.NewCoins(buyInCoin),
	); err != nil {
		return nil, errorsmod.Wrap(err, "failed to transfer buy-in amount")
	}

	// Call PVM to add player to game
	// Use "join" action to add player to the game state
	err = k.callGameEngine(ctx, msg.Player, msg.GameId, "join", msg.BuyInAmount)
	if err != nil {
		// Refund buy-in if game engine call fails
		if refundErr := k.bankKeeper.SendCoinsFromModuleToAccount(
			ctx,
			types.ModuleName,
			playerAddr,
			sdk.NewCoins(buyInCoin),
		); refundErr != nil {
			return nil, errorsmod.Wrapf(err, "failed to call game engine AND failed to refund: %v", refundErr)
		}
		return nil, errorsmod.Wrap(err, "failed to add player to game")
	}

	// Add player to game's player list if not already present
	playerAlreadyInGame := false
	for _, p := range game.Players {
		if p == msg.Player {
			playerAlreadyInGame = true
			break
		}
	}

	if !playerAlreadyInGame {
		game.Players = append(game.Players, msg.Player)
		if err := k.Games.Set(ctx, msg.GameId, game); err != nil {
			return nil, errorsmod.Wrap(err, "failed to update game player list")
		}
	}

	// Emit event
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"player_joined_game",
			sdk.NewAttribute("game_id", msg.GameId),
			sdk.NewAttribute("player", msg.Player),
			sdk.NewAttribute("seat", fmt.Sprintf("%d", msg.Seat)),
			sdk.NewAttribute("buy_in_amount", fmt.Sprintf("%d", msg.BuyInAmount)),
		),
	})

	return &types.MsgJoinGameResponse{}, nil
}
