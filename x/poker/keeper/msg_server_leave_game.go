package keeper

import (
	"context"
	"fmt"
	"strconv"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func (k msgServer) LeaveGame(ctx context.Context, msg *types.MsgLeaveGame) (*types.MsgLeaveGameResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.Logger().Info("🚪 LeaveGame called",
		"gameId", msg.GameId,
		"player", msg.Creator)

	// Validate player address
	playerAddr, err := k.addressCodec.StringToBytes(msg.Creator)
	if err != nil {
		sdkCtx.Logger().Error("❌ Invalid player address", "error", err, "player", msg.Creator)
		return nil, errorsmod.Wrap(err, "invalid player address")
	}

	// Check if game exists
	game, err := k.Games.Get(ctx, msg.GameId)
	if err != nil {
		sdkCtx.Logger().Error("❌ Game not found", "error", err, "gameId", msg.GameId)
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}
	sdkCtx.Logger().Info("✅ Game found", "gameId", msg.GameId, "creator", game.Creator)

	// Verify player is in the game
	playerInGame := false
	for _, p := range game.Players {
		if p == msg.Creator {
			playerInGame = true
			break
		}
	}
	if !playerInGame {
		sdkCtx.Logger().Error("❌ Player not in game", "player", msg.Creator, "gameId", msg.GameId)
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest, "player %s is not in game %s", msg.Creator, msg.GameId)
	}

	// Step 1: Get current game state to find player's chip stack
	gameState, err := k.GameStates.Get(ctx, msg.GameId)
	if err != nil {
		sdkCtx.Logger().Error("❌ Failed to get game state", "error", err, "gameId", msg.GameId)
		return nil, errorsmod.Wrap(err, "failed to get game state")
	}

	// Step 2: Find the player in the game state and get their chip stack
	var playerStack uint64 = 0
	var playerSeat uint64 = 0
	playerFound := false
	for _, player := range gameState.Players {
		if player.Address == msg.Creator {
			playerFound = true
			playerSeat = uint64(player.Seat)
			// Parse stack from string to uint64
			stack, parseErr := strconv.ParseUint(player.Stack, 10, 64)
			if parseErr != nil {
				sdkCtx.Logger().Error("❌ Failed to parse player stack", "error", parseErr, "stack", player.Stack)
				return nil, errorsmod.Wrap(parseErr, "failed to parse player stack")
			}
			playerStack = stack
			sdkCtx.Logger().Info("💰 Player stack found",
				"player", msg.Creator,
				"stack", playerStack,
				"seat", playerSeat)
			break
		}
	}

	if !playerFound {
		sdkCtx.Logger().Error("❌ Player not found in game state", "player", msg.Creator, "gameId", msg.GameId)
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest, "player %s not found in game state", msg.Creator)
	}

	// Step 3: Call PVM with "leave" action to remove player from game
	// The PVM will validate the leave action and update the game state
	err = k.callGameEngine(ctx, msg.Creator, msg.GameId, "leave", 0, playerSeat)
	if err != nil {
		sdkCtx.Logger().Error("❌ Failed to call game engine for leave", "error", err)
		return nil, errorsmod.Wrap(err, "failed to process leave action in game engine")
	}
	sdkCtx.Logger().Info("✅ Game engine processed leave action")

	// Step 4: Credit the USDC balance back to the player
	if playerStack > 0 {
		refundCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(int64(playerStack)))
		sdkCtx.Logger().Info("💸 Refunding chips to player",
			"player", msg.Creator,
			"amount", refundCoin.String())

		if err := k.bankKeeper.SendCoinsFromModuleToAccount(
			ctx,
			types.ModuleName,
			playerAddr,
			sdk.NewCoins(refundCoin),
		); err != nil {
			sdkCtx.Logger().Error("❌ Failed to refund chips", "error", err)
			return nil, errorsmod.Wrap(err, "failed to refund chips to player")
		}
		sdkCtx.Logger().Info("✅ Chips refunded successfully")
	} else {
		sdkCtx.Logger().Info("ℹ️ Player has no chips to refund")
	}

	// Remove player from game's player list
	updatedPlayers := make([]string, 0, len(game.Players)-1)
	for _, p := range game.Players {
		if p != msg.Creator {
			updatedPlayers = append(updatedPlayers, p)
		}
	}
	game.Players = updatedPlayers

	if err := k.Games.Set(ctx, msg.GameId, game); err != nil {
		sdkCtx.Logger().Error("❌ Failed to update game player list", "error", err)
		return nil, errorsmod.Wrap(err, "failed to update game player list")
	}
	sdkCtx.Logger().Info("✅ Player removed from game", "remainingPlayers", len(game.Players))

	// Emit event
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"player_left_game",
			sdk.NewAttribute("game_id", msg.GameId),
			sdk.NewAttribute("player", msg.Creator),
			sdk.NewAttribute("refund_amount", fmt.Sprintf("%d", playerStack)),
		),
	})

	sdkCtx.Logger().Info("🎉 LeaveGame completed successfully",
		"gameId", msg.GameId,
		"player", msg.Creator,
		"refundAmount", playerStack)

	return &types.MsgLeaveGameResponse{}, nil
}
