package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) NextPlayerToAct(ctx context.Context, req *types.QueryNextPlayerToActRequest) (*types.QueryNextPlayerToActResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.GameId == "" {
		return nil, status.Error(codes.InvalidArgument, "game ID cannot be empty")
	}

	// Get game state from keeper
	gameState, err := q.k.GameStates.Get(ctx, req.GameId)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "game state with ID %s not found", req.GameId)
	}

	// Check if NextToAct is valid
	if gameState.NextToAct < 0 || gameState.NextToAct >= len(gameState.Players) {
		return nil, status.Error(codes.Internal, "invalid next to act index")
	}

	// Get the next player
	nextPlayer := gameState.Players[gameState.NextToAct]

	// Create response with next player information as JSON
	responseData := map[string]interface{}{
		"game_id":        req.GameId,
		"next_to_act":    gameState.NextToAct,
		"address":        nextPlayer.Address,
		"seat":           nextPlayer.Seat,
		"stack":          nextPlayer.Stack,
		"sum_of_bets":    nextPlayer.SumOfBets,
		"status":         nextPlayer.Status,
		"is_dealer":      nextPlayer.IsDealer,
		"is_small_blind": nextPlayer.IsSmallBlind,
		"is_big_blind":   nextPlayer.IsBigBlind,
	}

	responseBytes, err := json.Marshal(responseData)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize next player data")
	}

	return &types.QueryNextPlayerToActResponse{
		NextPlayer: string(responseBytes),
	}, nil
}
