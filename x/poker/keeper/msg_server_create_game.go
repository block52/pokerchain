package keeper

import (
	"context"
	"fmt"
	"time"

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

	// Generate unique game ID (using message fields or a counter approach)
	// For now, using a simple approach - in production, consider using a counter or UUID
	gameId := msg.GameId
	if gameId == "" {
		// Generate game ID based on creator and timestamp if not provided
		sdkCtx := sdk.UnwrapSDKContext(ctx)
		gameId = fmt.Sprintf("game_%s_%d", msg.Creator[:8], sdkCtx.BlockTime().Unix())
	}

	// Check if game with this ID already exists
	_, err = k.Games.Get(ctx, gameId)
	if err == nil {
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest, "game with ID %s already exists", gameId)
	}

	// Create game state
	now := time.Now()
	game := types.Game{
		GameId:     gameId,
		Creator:    msg.Creator,
		MinBuyIn:   msg.MinBuyIn,
		MaxBuyIn:   msg.MaxBuyIn,
		MinPlayers: msg.MinPlayers,
		MaxPlayers: msg.MaxPlayers,
		SmallBlind: msg.SmallBlind,
		BigBlind:   msg.BigBlind,
		Timeout:    msg.Timeout,
		GameType:   msg.GameType,
		Players:    []string{}, // Empty initially, players join separately
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	// Store game in keeper
	if err := k.Games.Set(ctx, gameId, game); err != nil {
		return nil, errorsmod.Wrap(err, "failed to store game")
	}

	// Emit events
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"game_created",
			sdk.NewAttribute("game_id", gameId),
			sdk.NewAttribute("creator", msg.Creator),
			sdk.NewAttribute("game_type", msg.GameType),
			sdk.NewAttribute("min_players", fmt.Sprintf("%d", msg.MinPlayers)),
			sdk.NewAttribute("max_players", fmt.Sprintf("%d", msg.MaxPlayers)),
			sdk.NewAttribute("min_buy_in", fmt.Sprintf("%d", msg.MinBuyIn)),
			sdk.NewAttribute("max_buy_in", fmt.Sprintf("%d", msg.MaxBuyIn)),
		),
	})

	return &types.MsgCreateGameResponse{}, nil
}
