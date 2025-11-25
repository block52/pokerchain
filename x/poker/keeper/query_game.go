package keeper

import (
	"context"
	"encoding/json"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// CombinedGameResponse combines game metadata with public game state
type CombinedGameResponse struct {
	// Game metadata
	GameId     string   `json:"gameId"`
	Creator    string   `json:"creator"`
	MinBuyIn   uint64   `json:"minBuyIn"`
	MaxBuyIn   uint64   `json:"maxBuyIn"`
	MinPlayers int64    `json:"minPlayers"`
	MaxPlayers int64    `json:"maxPlayers"`
	SmallBlind uint64   `json:"smallBlind"`
	BigBlind   uint64   `json:"bigBlind"`
	Timeout    int64    `json:"timeout"`
	GameType   string   `json:"gameType"`
	Players    []string `json:"players"`

	// Game state (public view with masked cards)
	GameState *types.TexasHoldemStateDTO `json:"gameState,omitempty"`
}

func (q queryServer) Game(ctx context.Context, req *types.QueryGameRequest) (*types.QueryGameResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.GameId == "" {
		return nil, status.Error(codes.InvalidArgument, "game ID cannot be empty")
	}

	// Get game metadata from keeper
	game, err := q.k.Games.Get(ctx, req.GameId)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "game with ID %s not found", req.GameId)
	}

	// Build combined response
	combined := CombinedGameResponse{
		GameId:     game.GameId,
		Creator:    game.Creator,
		MinBuyIn:   game.MinBuyIn,
		MaxBuyIn:   game.MaxBuyIn,
		MinPlayers: game.MinPlayers,
		MaxPlayers: game.MaxPlayers,
		SmallBlind: game.SmallBlind,
		BigBlind:   game.BigBlind,
		Timeout:    game.Timeout,
		GameType:   game.GameType,
		Players:    game.Players,
	}

	// Try to get game state (may not exist for new games)
	gameState, err := q.k.GameStates.Get(ctx, req.GameId)
	if err == nil {
		// Mask all cards for public view
		maskedState := maskAllCards(gameState)
		combined.GameState = &maskedState
	}

	// Convert combined response to JSON string
	combinedBytes, err := json.Marshal(combined)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize game data")
	}

	return &types.QueryGameResponse{
		Game: string(combinedBytes),
	}, nil
}

// maskAllCards masks all hole cards and deck for public viewing
func maskAllCards(gameState types.TexasHoldemStateDTO) types.TexasHoldemStateDTO {
	// Create a copy of the game state
	maskedState := gameState

	// Mask hole cards for all players
	maskedPlayers := make([]types.PlayerDTO, len(gameState.Players))
	for i, player := range gameState.Players {
		maskedPlayers[i] = player

		// Mask all hole cards
		if player.HoleCards != nil {
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
