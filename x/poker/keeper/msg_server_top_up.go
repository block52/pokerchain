package keeper

import (
	"context"
	"fmt"
	"strconv"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
)

// TopUp handles adding chips to a player's stack when not in an active hand.
// The player must have sufficient balance in their wallet.
// The total chips after top-up cannot exceed the table's max_buy_in.
func (k msgServer) TopUp(ctx context.Context, msg *types.MsgTopUp) (*types.MsgTopUpResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.Logger().Info("💰 TopUp called",
		"gameId", msg.GameId,
		"player", msg.Player,
		"amount", msg.Amount)

	// Validate player address
	playerAddr, err := k.addressCodec.StringToBytes(msg.Player)
	if err != nil {
		sdkCtx.Logger().Error("❌ Invalid player address", "error", err, "player", msg.Player)
		return nil, errorsmod.Wrap(err, "invalid player address")
	}

	// Check if game exists
	game, err := k.Games.Get(ctx, msg.GameId)
	if err != nil {
		sdkCtx.Logger().Error("❌ Game not found", "error", err, "gameId", msg.GameId)
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}

	// Validate amount is positive
	if msg.Amount == 0 {
		return nil, errorsmod.Wrap(types.ErrInvalidRequest, "top-up amount must be positive")
	}

	// Get game state to check player's current stack
	gameState, err := k.GameStates.Get(ctx, msg.GameId)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to get game state")
	}

	// Find the player in the game
	var playerSeat int
	var currentStack uint64
	playerFound := false
	for _, player := range gameState.Players {
		if player.Address == msg.Player {
			playerFound = true
			playerSeat = player.Seat
			// Parse stack from string to uint64
			stack, parseErr := strconv.ParseUint(player.Stack, 10, 64)
			if parseErr != nil {
				sdkCtx.Logger().Error("❌ Failed to parse player stack", "error", parseErr, "stack", player.Stack)
				return nil, errorsmod.Wrap(parseErr, "failed to parse player stack")
			}
			currentStack = stack
			sdkCtx.Logger().Info("💰 Player stack found",
				"player", msg.Player,
				"currentStack", currentStack,
				"seat", playerSeat)
			break
		}
	}

	if !playerFound {
		return nil, errorsmod.Wrap(types.ErrInvalidRequest, "player not found in game")
	}

	// Calculate new stack and check if top-up would exceed max buy-in
	newStack := currentStack + msg.Amount
	if newStack > game.MaxBuyIn {
		maxAllowed := game.MaxBuyIn - currentStack
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest,
			"top-up would exceed max buy-in. Current: %d, Requested: %d, Max allowed: %d",
			currentStack, msg.Amount, maxAllowed)
	}

	// Check if player has enough balance for top-up
	playerBalance := k.bankKeeper.SpendableCoins(ctx, playerAddr)
	topUpCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(int64(msg.Amount)))

	sdkCtx.Logger().Info("💰 Checking player balance for top-up",
		"playerBalance", playerBalance.String(),
		"requiredTopUp", topUpCoin.String(),
		"playerUSDC", playerBalance.AmountOf(types.TokenDenom).String())

	if !playerBalance.IsAllGTE(sdk.NewCoins(topUpCoin)) {
		return nil, errorsmod.Wrapf(sdkerrors.ErrInsufficientFunds,
			"player needs %s to top up, but only has %s",
			topUpCoin.String(),
			playerBalance.AmountOf(types.TokenDenom).String())
	}

	// Transfer top-up amount from player to module account
	if err := k.bankKeeper.SendCoinsFromAccountToModule(
		ctx,
		playerAddr,
		types.ModuleName,
		sdk.NewCoins(topUpCoin),
	); err != nil {
		return nil, errorsmod.Wrap(err, "failed to transfer top-up amount")
	}

	// Call PVM to execute top-up action
	// Use "top-up" action which is NonPlayerActionType.TOP_UP in the PVM
	err = k.callGameEngine(ctx, msg.Player, msg.GameId, "top-up", msg.Amount, uint64(playerSeat))
	if err != nil {
		// Refund top-up if game engine call fails
		if refundErr := k.bankKeeper.SendCoinsFromModuleToAccount(
			ctx,
			types.ModuleName,
			playerAddr,
			sdk.NewCoins(topUpCoin),
		); refundErr != nil {
			sdkCtx.Logger().Error("❌ Failed to refund after game engine error",
				"originalError", err,
				"refundError", refundErr)
			return nil, errorsmod.Wrapf(err, "failed to call game engine AND failed to refund: %v", refundErr)
		}
		return nil, errorsmod.Wrap(err, "failed to execute top-up in game engine")
	}

	sdkCtx.Logger().Info("✅ TopUp successful",
		"player", msg.Player,
		"amount", msg.Amount,
		"newStack", newStack)

	// Emit event
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"player_top_up",
			sdk.NewAttribute("game_id", msg.GameId),
			sdk.NewAttribute("player", msg.Player),
			sdk.NewAttribute("amount", fmt.Sprintf("%d", msg.Amount)),
			sdk.NewAttribute("new_stack", fmt.Sprintf("%d", newStack)),
		),
	})

	return &types.MsgTopUpResponse{
		NewStack: newStack,
	}, nil
}
