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
)

// isValidAction checks if the action is valid
func isValidAction(action string) bool {
	validActions := []PlayerActionType{
		SmallBlind, BigBlind, Fold, Check, Bet, Call, Raise, AllIn, Muck, SitIn, SitOut, Show,
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
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(err, "invalid authority address")
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
	err = k.callGameEngine(ctx, msg.Creator, msg.GameId, msg.Action, msg.Amount)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to call game engine")
	}

	// TODO: After successful engine call, we could fetch updated game state
	// and save it back to the blockchain if needed

	return &types.MsgPerformActionResponse{}, nil
}

// callGameEngine makes a JSON-RPC call to the game engine with game state and options
func (k msgServer) callGameEngine(ctx context.Context, playerId, gameId, action string, amount uint64) error {
	// Fetch game state from GameStates collection
	gameState, err := k.GameStates.Get(ctx, gameId)
	if err != nil {
		return fmt.Errorf("failed to get game state: %w", err)
	}

	// Fetch game options from Games collection
	game, err := k.Games.Get(ctx, gameId)
	if err != nil {
		return fmt.Errorf("failed to get game: %w", err)
	}

	// Convert game state to JSON
	gameStateJson, err := json.Marshal(gameState)
	if err != nil {
		return fmt.Errorf("failed to marshal game state: %w", err)
	}

	// Convert game options to JSON
	gameOptionsJson, err := json.Marshal(game)
	if err != nil {
		return fmt.Errorf("failed to marshal game options: %w", err)
	}

	// Create JSON-RPC request with new params format:
	// [from, to, action, value, index, gameStateJson, gameOptionsJson, data]
	request := JSONRPCRequest{
		Method: "perform_action",
		Params: []interface{}{
			playerId,                       // from
			gameId,                         // to (game address)
			action,                         // action
			strconv.FormatUint(amount, 10), // value
			0,                              // index
			string(gameStateJson),          // gameStateJson
			string(gameOptionsJson),        // gameOptionsJson
			"{}",                           // data (empty for now)
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

	return nil
}
