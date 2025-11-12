package keeper

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/block52/pokerchain/x/poker/types"
)

// PlayerActionType represents valid poker actions
type PlayerActionType string

const (
	SmallBlind PlayerActionType = "post-small-blind"
	BigBlind   PlayerActionType = "post-big-blind"
	Fold       PlayerActionType = "fold"
	Check      PlayerActionType = "check"
	Bet        PlayerActionType = "bet"
	Call       PlayerActionType = "call"
	Raise      PlayerActionType = "raise"
	AllIn      PlayerActionType = "all-in"
	Muck       PlayerActionType = "muck"
	SitIn      PlayerActionType = "sit-in"
	SitOut     PlayerActionType = "sit-out"
	Show       PlayerActionType = "show"
	Join       PlayerActionType = "join"
	Deal       PlayerActionType = "deal"
)

// isValidAction checks if the action is valid
func isValidAction(action string) bool {
	validActions := []PlayerActionType{
		SmallBlind, BigBlind, Fold, Check, Bet, Call, Raise, AllIn, Muck, SitIn, SitOut, Show, Join, Deal,
	}
	for _, validAction := range validActions {
		if PlayerActionType(action) == validAction {
			return true
		}
	}
	return false
}

// JSONRPCRequest represents a JSON-RPC request
type JSONRPCRequest struct {
	Method  string        `json:"method"`
	Params  []interface{} `json:"params"`
	ID      int           `json:"id"`
	JSONRPC string        `json:"jsonrpc"`
}

// JSONRPCResponse represents a JSON-RPC response
type JSONRPCResponse struct {
	Result  interface{} `json:"result"`
	Error   interface{} `json:"error"` // Can be string or structured error
	ID      int         `json:"id"`
	JSONRPC string      `json:"jsonrpc"`
}

func (k msgServer) PerformAction(ctx context.Context, msg *types.MsgPerformAction) (*types.MsgPerformActionResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Player); err != nil {
		return nil, errorsmod.Wrap(err, "invalid player address")
	}

	// Validate the action type
	if !isValidAction(msg.Action) {
		return nil, errorsmod.Wrapf(types.ErrInvalidAction, "invalid action: %s", msg.Action)
	}

	// Check if the game exists
	_, err := k.Games.Get(ctx, msg.GameId)
	if err != nil {
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}

	// Make JSON-RPC call to game engine with game state
	// For perform_action (not join), seat is not used, pass 0
	err = k.callGameEngine(ctx, msg.Player, msg.GameId, msg.Action, msg.Amount, 0)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to call game engine")
	}

	// TODO: After successful engine call, we could fetch updated game state
	// and save it back to the blockchain if needed

	return &types.MsgPerformActionResponse{}, nil
}

// callGameEngine makes a JSON-RPC call to the game engine with game state and options
func (k msgServer) callGameEngine(ctx context.Context, playerId, gameId, action string, amount uint64, seat uint64) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.Logger().Info("🎲 callGameEngine called",
		"gameId", gameId,
		"playerId", playerId,
		"action", action,
		"amount", amount)

	// Fetch game state from GameStates collection
	gameState, err := k.GameStates.Get(ctx, gameId)
	if err != nil {
		sdkCtx.Logger().Error("❌ Failed to get game state", "error", err, "gameId", gameId)
		return fmt.Errorf("failed to get game state for gameId=%s: %w", gameId, err)
	}
	sdkCtx.Logger().Info("✅ Game state retrieved", "gameId", gameId, "players", len(gameState.Players))

	// Fetch game options from Games collection
	game, err := k.Games.Get(ctx, gameId)
	if err != nil {
		sdkCtx.Logger().Error("❌ Failed to get game", "error", err, "gameId", gameId)
		return fmt.Errorf("failed to get game for gameId=%s: %w", gameId, err)
	}
	sdkCtx.Logger().Info("✅ Game retrieved", "gameId", gameId, "creator", game.Creator)

	// Convert game state to JSON
	gameStateJson, err := json.Marshal(gameState)
	if err != nil {
		return fmt.Errorf("failed to marshal game state: %w", err)
	}

	// Convert string game type to GameType enum
	var gameType types.GameType
	switch game.GameType {
	case "cash":
		gameType = types.GameTypeCash
	case "sit-and-go":
		gameType = types.GameTypeSitAndGo
	case "tournament":
		gameType = types.GameTypeTournament
	default:
		gameType = types.GameTypeCash // default to cash if unrecognized
	}

	// Create GameOptionsDTO from the game object
	gameOptions := types.GameOptionsDTO{
		MinBuyIn:   &[]string{strconv.FormatUint(game.MinBuyIn, 10)}[0],
		MaxBuyIn:   &[]string{strconv.FormatUint(game.MaxBuyIn, 10)}[0],
		MinPlayers: &[]int{int(game.MinPlayers)}[0],
		MaxPlayers: &[]int{int(game.MaxPlayers)}[0],
		SmallBlind: &[]string{strconv.FormatUint(game.SmallBlind, 10)}[0],
		BigBlind:   &[]string{strconv.FormatUint(game.BigBlind, 10)}[0],
		Timeout:    &[]int{int(game.Timeout)}[0],
		Type:       &gameType,
	}

	// Convert game options to JSON
	gameOptionsJson, err := json.Marshal(gameOptions)
	if err != nil {
		return fmt.Errorf("failed to marshal game options: %w", err)
	}

	// Create JSON-RPC request with new params format:
	// [from, to, action, value, index, gameStateJson, gameOptionsJson, data]
	// Match PVM's getActionIndex() logic: actionCount + previousActions.length + 1
	actionIndex := gameState.ActionCount + len(gameState.PreviousActions) + 1

	// Format seat parameter for data field
	// PVM requires explicit seat number - keeper should have resolved seat=0 to actual seat
	seatData := fmt.Sprintf("seat=%d", seat)

	// Get deterministic timestamp from Cosmos block (for PVM determinism)
	// This ensures all validators get the same timestamp for consensus
	blockTimestamp := sdkCtx.BlockTime().UnixMilli() // Milliseconds since epoch

	request := JSONRPCRequest{
		Method: "perform_action",
		Params: []interface{}{
			playerId,                       // from
			gameId,                         // to (game address)
			action,                         // action
			strconv.FormatUint(amount, 10), // value
			actionIndex,                    // index (current action count)
			string(gameStateJson),          // gameStateJson
			string(gameOptionsJson),        // gameOptionsJson
			seatData,                       // data with seat parameter (empty = auto-assign)
			blockTimestamp,                 // timestamp (Cosmos block time for deterministic gameplay)
		},
		ID:      1,
		JSONRPC: "2.0",
	}

	// Marshal request to JSON
	requestBody, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON-RPC request: %w", err)
	}

	// Make HTTP POST request to game engine
	node := "http://localhost:8545"
	resp, err := http.Post(node, "application/json", bytes.NewBuffer(requestBody))
	if err != nil {
		return fmt.Errorf("failed to make HTTP request to game engine: %w", err)
	}
	defer resp.Body.Close()

	// Parse JSON-RPC response
	var response JSONRPCResponse
	responseBody, readErr := io.ReadAll(resp.Body)
	if readErr != nil {
		return fmt.Errorf("failed to read response body: %w", readErr)
	}

	if err := json.Unmarshal(responseBody, &response); err != nil {
		return fmt.Errorf("failed to decode JSON-RPC response (body: %s): %w", string(responseBody), err)
	}

	// Check for JSON-RPC error
	if response.Error != nil {
		switch err := response.Error.(type) {
		case string:
			return fmt.Errorf("game engine error: %s", err)
		case map[string]interface{}:
			if code, ok := err["code"].(float64); ok {
				if message, ok := err["message"].(string); ok {
					return fmt.Errorf("game engine error: %s (code %.0f)", message, code)
				}
			}
			return fmt.Errorf("game engine error: %v", err)
		default:
			return fmt.Errorf("game engine error: %v", response.Error)
		}
	}

	// Parse the result to get updated game state
	if response.Result != nil {
		// The result should contain the updated game state
		// Parse the result as a TexasHoldemStateDTO and update our stored game state
		resultBytes, err := json.Marshal(response.Result)
		if err != nil {
			return fmt.Errorf("failed to marshal response result: %w", err)
		}

		// The engine response has a "data" field containing the actual game state
		// First extract the wrapper structure
		var engineResponse struct {
			Data      map[string]interface{} `json:"data"`
			Signature interface{}            `json:"signature"`
		}

		if err := json.Unmarshal(resultBytes, &engineResponse); err != nil {
			return fmt.Errorf("failed to unmarshal engine response wrapper: %v", err)
		}

		// Now marshal just the data portion and unmarshal into our game state structure
		dataBytes, err := json.Marshal(engineResponse.Data)
		if err != nil {
			return fmt.Errorf("failed to marshal engine data: %w", err)
		}

		var updatedGameState types.TexasHoldemStateDTO
		if err := json.Unmarshal(dataBytes, &updatedGameState); err != nil {
			return fmt.Errorf("failed to unmarshal updated game state: %v", err)
		}

		// Store the updated game state
		if err := k.GameStates.Set(ctx, gameId, updatedGameState); err != nil {
			return fmt.Errorf("failed to store updated game state: %w", err)
		}
	} else {
		return fmt.Errorf("no result returned from poker engine")
	}

	return nil
}
