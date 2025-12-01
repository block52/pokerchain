package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// GameStatePublic returns the game state with all hole cards masked (public/unauthenticated view)
func (q queryServer) GameStatePublic(ctx context.Context, req *types.QueryGameStatePublicRequest) (*types.QueryGameStatePublicResponse, error) {
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

	// Mask ALL hole cards for public view (passing empty address means no player match)
	maskedGameState := maskAllHoleCards(gameState)

	// Convert game state to JSON string for response
	gameStateBytes, err := json.Marshal(maskedGameState)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize game state data")
	}

	return &types.QueryGameStatePublicResponse{
		GameState: string(gameStateBytes),
	}, nil
}

// maskAllHoleCards masks all players' hole cards for public viewing
// Only cards from players with StatusShowing are visible
func maskAllHoleCards(gameState types.TexasHoldemStateDTO) types.TexasHoldemStateDTO {
	maskedState := gameState

	maskedPlayers := make([]types.PlayerDTO, len(gameState.Players))
	for i, player := range gameState.Players {
		maskedPlayers[i] = player

		// Only show cards for players who are showing (e.g., at showdown)
		isShowing := player.Status == types.StatusShowing
		hasCards := player.HoleCards != nil && len(*player.HoleCards) > 0

		if isShowing && hasCards {
			// Player is showing their cards - don't mask them
			// Keep original cards
		} else if hasCards {
			// Mask all other players' cards
			maskedCards := make([]string, len(*player.HoleCards))
			for j := range maskedCards {
				maskedCards[j] = "X"
			}
			maskedPlayers[i].HoleCards = &maskedCards
		}
	}

	maskedState.Players = maskedPlayers

	// Mask the deck (should never be visible)
	maskedState.Deck = "X"

	return maskedState
}
