package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) LegalActions(ctx context.Context, req *types.QueryLegalActionsRequest) (*types.QueryLegalActionsResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.GameId == "" {
		return nil, status.Error(codes.InvalidArgument, "game ID cannot be empty")
	}

	if req.PlayerAddress == "" {
		return nil, status.Error(codes.InvalidArgument, "player address cannot be empty")
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Retrieve the game state
	gameState, err := q.k.GameStates.Get(sdkCtx, req.GameId)
	if err != nil {
		return nil, status.Error(codes.NotFound, "game state not found")
	}

	// Find the player in the game state
	var playerLegalActions []types.LegalActionDTO
	for _, player := range gameState.Players {
		if player.Address == req.PlayerAddress {
			playerLegalActions = player.LegalActions
			break
		}
	}

	// If player is not found in the game, return empty legal actions
	if playerLegalActions == nil {
		playerLegalActions = []types.LegalActionDTO{}
	}

	// Convert legal actions to JSON string
	actionsJSON, err := json.Marshal(playerLegalActions)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to marshal legal actions")
	}

	return &types.QueryLegalActionsResponse{
		Actions: string(actionsJSON),
	}, nil
}
