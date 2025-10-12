package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) ListGames(ctx context.Context, req *types.QueryListGamesRequest) (*types.QueryListGamesResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	// Collect all games from the Games collection
	var games []types.Game

	// Iterate over all games in the collection
	err := q.k.Games.Walk(ctx, nil, func(gameId string, game types.Game) (bool, error) {
		games = append(games, game)
		return false, nil // false means continue iterating
	})

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to iterate games")
	}

	// Convert games slice to JSON string for response
	gamesBytes, err := json.Marshal(games)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize games data")
	}

	return &types.QueryListGamesResponse{
		Games: string(gamesBytes),
	}, nil
}
