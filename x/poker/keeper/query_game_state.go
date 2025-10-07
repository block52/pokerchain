package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) GameState(ctx context.Context, req *types.QueryGameStateRequest) (*types.QueryGameStateResponse, error) {
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

	// Convert game state to JSON string for response
	gameStateBytes, err := json.Marshal(gameState)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize game state data")
	}

	return &types.QueryGameStateResponse{
		GameState: string(gameStateBytes),
	}, nil
}
