package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) Game(ctx context.Context, req *types.QueryGameRequest) (*types.QueryGameResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.GameId == "" {
		return nil, status.Error(codes.InvalidArgument, "game ID cannot be empty")
	}

	// Get game from keeper
	game, err := q.k.Games.Get(ctx, req.GameId)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "game with ID %s not found", req.GameId)
	}

	// Convert game to JSON string for response
	gameBytes, err := json.Marshal(game)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize game data")
	}

	return &types.QueryGameResponse{
		Game: string(gameBytes),
	}, nil
}
