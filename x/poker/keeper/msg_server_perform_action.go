package keeper

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
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
	Result interface{} `json:"result"`
	Error  *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
	ID      int    `json:"id"`
	JSONRPC string `json:"jsonrpc"`
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
	gameExists, err := k.HasGameState(ctx, msg.GameId)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to check game existence")
	}
	if !gameExists {
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}

	// Make JSON-RPC call to game engine
	err = k.callGameEngine(msg.Creator, msg.GameId, msg.Action, msg.Amount)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to call game engine")
	}

	// TODO: After successful engine call, we could fetch updated game state
	// and save it back to the blockchain if needed

	return &types.MsgPerformActionResponse{}, nil
}

// callGameEngine makes a JSON-RPC call to the game engine
func (k msgServer) callGameEngine(playerId, gameId, action string, amount uint64) error {
	// Create JSON-RPC request
	request := JSONRPCRequest{
		Method:  "perform_action",
		Params:  []interface{}{playerId, gameId, action, strconv.FormatUint(amount, 10), 0, 1, 1},
		ID:      1,
		JSONRPC: "2.0",
	}

	// Marshal request to JSON
	requestBody, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON-RPC request: %w", err)
	}

	// Make HTTP POST request to game engine
	// node := "https://localhost:8545"
	node := "https://node1.block52.xyz"
	resp, err := http.Post(node, "application/json", bytes.NewBuffer(requestBody))
	if err != nil {
		return fmt.Errorf("failed to make HTTP request to game engine: %w", err)
	}
	defer resp.Body.Close()

	// Parse JSON-RPC response
	var response JSONRPCResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return fmt.Errorf("failed to decode JSON-RPC response: %w", err)
	}

	// Check for JSON-RPC error
	if response.Error != nil {
		return fmt.Errorf("game engine error: %s (code %d)", response.Error.Message, response.Error.Code)
	}

	return nil
}
