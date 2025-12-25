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
	"cosmossdk.io/math"
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
	Leave      PlayerActionType = "leave"
	Deal       PlayerActionType = "deal"
	NewHand    PlayerActionType = "new-hand"
)

// isValidAction checks if the action is valid
func isValidAction(action string) bool {
	validActions := []PlayerActionType{
		SmallBlind, BigBlind, Fold, Check, Bet, Call, Raise, AllIn, Muck, SitIn, SitOut, Show, Join, Leave, Deal, NewHand,
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
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	playerAddr, err := k.addressCodec.StringToBytes(msg.Player)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid player address")
	}

	// Validate the action type
	if !isValidAction(msg.Action) {
		return nil, errorsmod.Wrapf(types.ErrInvalidAction, "invalid action: %s", msg.Action)
	}

	// Check if the game exists
	game, err := k.Games.Get(ctx, msg.GameId)
	if err != nil {
		return nil, errorsmod.Wrapf(types.ErrGameNotFound, "game not found: %s", msg.GameId)
	}

	// For "leave" action, get player's stack BEFORE calling game engine
	var playerStack uint64 = 0
	if msg.Action == string(Leave) {
		gameState, err := k.GameStates.Get(ctx, msg.GameId)
		if err != nil {
			return nil, errorsmod.Wrap(err, "failed to get game state for leave action")
		}
		for _, player := range gameState.Players {
			if player.Address == msg.Player {
				stack, parseErr := strconv.ParseUint(player.Stack, 10, 64)
				if parseErr != nil {
					sdkCtx.Logger().Error("❌ Failed to parse player stack", "error", parseErr, "stack", player.Stack)
					return nil, errorsmod.Wrap(parseErr, "failed to parse player stack")
				}
				playerStack = stack
				sdkCtx.Logger().Info("💰 Player stack for leave",
					"player", msg.Player,
					"stack", playerStack)
				break
			}
		}
	}

	// Make JSON-RPC call to game engine with game state
	// For perform_action (not join), seat is not used, pass 0
	err = k.callGameEngine(ctx, msg.Player, msg.GameId, msg.Action, msg.Amount, 0)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to call game engine")
	}

	// Handle leave action: refund chips and update game player list
	if msg.Action == string(Leave) {
		// Credit the USDC balance back to the player
		if playerStack > 0 {
			refundCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(int64(playerStack)))
			sdkCtx.Logger().Info("💸 Refunding chips to player",
				"player", msg.Player,
				"amount", refundCoin.String())

			if err := k.bankKeeper.SendCoinsFromModuleToAccount(
				ctx,
				types.ModuleName,
				playerAddr,
				sdk.NewCoins(refundCoin),
			); err != nil {
				sdkCtx.Logger().Error("❌ Failed to refund chips", "error", err)
				return nil, errorsmod.Wrap(err, "failed to refund chips to player")
			}
			sdkCtx.Logger().Info("✅ Chips refunded successfully")
		}

		// Remove player from game's player list
		updatedPlayers := make([]string, 0, len(game.Players)-1)
		for _, p := range game.Players {
			if p != msg.Player {
				updatedPlayers = append(updatedPlayers, p)
			}
		}
		game.Players = updatedPlayers

		if err := k.Games.Set(ctx, msg.GameId, game); err != nil {
			sdkCtx.Logger().Error("❌ Failed to update game player list", "error", err)
			return nil, errorsmod.Wrap(err, "failed to update game player list")
		}
		sdkCtx.Logger().Info("✅ Player removed from game", "remainingPlayers", len(game.Players))

		// Emit player_left_game event
		sdkCtx.EventManager().EmitEvents(sdk.Events{
			sdk.NewEvent(
				"player_left_game",
				sdk.NewAttribute("game_id", msg.GameId),
				sdk.NewAttribute("player", msg.Player),
				sdk.NewAttribute("refund_amount", fmt.Sprintf("%d", playerStack)),
			),
		})
	}

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

	// Step 1: Calculate expected action index to match PVM's getActionIndex()
	// PVM calculates: this._actionCount + this.getPreviousActions().length + 1
	// - actionCount: persists across hands (total actions in the game session)
	// - previousActions.length: actions in the current hand (resets on new-hand)
	// This ensures action indices are globally unique and monotonically increasing
	expectedActionIndex := gameState.ActionCount + len(gameState.PreviousActions) + 1

	// Step 2: Validate against PVM legal actions
	// Find the player in game state and verify the action index matches legal actions
	var playerLegalActions []types.LegalActionDTO
	for _, player := range gameState.Players {
		if player.Address == playerId {
			playerLegalActions = player.LegalActions
			break
		}
	}

	// Verify the action index matches legal actions
	if len(playerLegalActions) > 0 {
		// All legal actions for a player should have the same index
		pvmExpectedIndex := playerLegalActions[0].Index

		if expectedActionIndex != pvmExpectedIndex {
			sdkCtx.Logger().Error("❌ Action index mismatch",
				"gameId", gameId,
				"player", playerId,
				"action", action,
				"cosmosCalculated", expectedActionIndex,
				"pvmExpects", pvmExpectedIndex,
				"actionCount", gameState.ActionCount,
				"previousActionsCount", len(gameState.PreviousActions))
			return fmt.Errorf(
				"action index mismatch: cosmos calculated %d but PVM expects %d (actionCount: %d, previousActions: %d)",
				expectedActionIndex,
				pvmExpectedIndex,
				gameState.ActionCount,
				len(gameState.PreviousActions),
			)
		}
	}

	// Step 4: Log validated index for debugging
	sdkCtx.Logger().Info("✅ Validated action index",
		"gameId", gameId,
		"player", playerId,
		"action", action,
		"actionCount", gameState.ActionCount,
		"previousActionsCount", len(gameState.PreviousActions),
		"calculatedIndex", expectedActionIndex)

	// Step 3: Use validated index
	actionIndex := expectedActionIndex

	// Format data parameter based on action type
	var seatData string
	if action == "new-hand" {
		// For new-hand action, generate a deterministic shuffled deck from block hash
		deck, err := k.Keeper.InitializeAndShuffleDeck(ctx)
		if err != nil {
			return fmt.Errorf("failed to initialize and shuffle deck: %w", err)
		}
		deckStr := k.Keeper.SaveDeckToState(deck)
		seatData = fmt.Sprintf("deck=%s", deckStr)
		sdkCtx.Logger().Info("🃏 Generated shuffled deck for new hand", "gameId", gameId)
	} else {
		// For other actions, use seat parameter
		// PVM requires explicit seat number - keeper should have resolved seat=0 to actual seat
		seatData = fmt.Sprintf("seat=%d", seat)
	}

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
	node := k.Keeper.GetPVMURL()
	resp, err := http.Post(node, "application/json", bytes.NewBuffer(requestBody))
	if err != nil {
		return fmt.Errorf("failed to make HTTP request to game engine at %s: %w", node, err)
	}
	defer resp.Body.Close()

	// Check HTTP status code
	if resp.StatusCode != http.StatusOK {
		responseBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("game engine returned non-OK status %d: %s (body: %s)", resp.StatusCode, resp.Status, string(responseBody))
	}

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

		// Additional validation: Validate that PVM incremented the action index correctly
		if len(updatedGameState.PreviousActions) > 0 {
			lastIndex := updatedGameState.PreviousActions[len(updatedGameState.PreviousActions)-1].Index

			// Should match what we sent
			if lastIndex != actionIndex {
				sdkCtx.Logger().Warn("⚠️ PVM returned different action index than expected",
					"expected", actionIndex,
					"received", lastIndex,
					"gameId", gameId,
					"action", action,
					"player", playerId)
			}
		}

		// Additional validation: Check for duplicate indices in previous actions
		indexMap := make(map[int]bool)
		for i, prevAction := range updatedGameState.PreviousActions {
			if indexMap[prevAction.Index] {
				sdkCtx.Logger().Error("🚨 Duplicate action index detected",
					"gameId", gameId,
					"index", prevAction.Index,
					"position", i,
					"action", prevAction.Action,
					"playerId", prevAction.PlayerId,
					"timestamp", prevAction.Timestamp)
				// Don't fail the transaction, but log it for monitoring
			}
			indexMap[prevAction.Index] = true
		}

		// Store the updated game state
		if err := k.GameStates.Set(ctx, gameId, updatedGameState); err != nil {
			return fmt.Errorf("failed to store updated game state: %w", err)
		}

		// Emit event for WebSocket subscribers (Tendermint event system)
		sdkCtx.EventManager().EmitEvents(sdk.Events{
			sdk.NewEvent(
				"action_performed",
				sdk.NewAttribute("game_id", gameId),
				sdk.NewAttribute("player", playerId),
				sdk.NewAttribute("action", action),
				sdk.NewAttribute("amount", strconv.FormatUint(amount, 10)),
			),
		})

		// Emit hand distribution events for indexer tracking
		if action == "new-hand" {
			// Emit hand_started event with deck seed for randomness verification
			blockHash := sdkCtx.BlockHeader().AppHash
			if len(blockHash) == 0 {
				blockHash = sdkCtx.BlockHeader().LastCommitHash
			}
			sdkCtx.EventManager().EmitEvents(sdk.Events{
				sdk.NewEvent(
					"hand_started",
					sdk.NewAttribute("game_id", gameId),
					sdk.NewAttribute("hand_number", strconv.Itoa(updatedGameState.HandNumber)),
					sdk.NewAttribute("block_height", strconv.FormatInt(sdkCtx.BlockHeight(), 10)),
					sdk.NewAttribute("deck_seed", fmt.Sprintf("%x", blockHash)),
					sdk.NewAttribute("deck", updatedGameState.Deck),
				),
			})
		}

		// Emit hand_completed event at showdown with revealed cards
		if updatedGameState.Round == "showdown" && len(updatedGameState.Winners) > 0 {
			// Collect all revealed hole cards from players who showed
			var revealedCards []string
			for _, player := range updatedGameState.Players {
				if player.HoleCards != nil && len(*player.HoleCards) > 0 {
					for _, card := range *player.HoleCards {
						revealedCards = append(revealedCards, card)
					}
				}
			}
			// Serialize community cards
			communityCardsStr := ""
			for i, card := range updatedGameState.CommunityCards {
				if i > 0 {
					communityCardsStr += ","
				}
				communityCardsStr += card
			}
			// Serialize revealed hole cards
			revealedCardsStr := ""
			for i, card := range revealedCards {
				if i > 0 {
					revealedCardsStr += ","
				}
				revealedCardsStr += card
			}
			sdkCtx.EventManager().EmitEvents(sdk.Events{
				sdk.NewEvent(
					"hand_completed",
					sdk.NewAttribute("game_id", gameId),
					sdk.NewAttribute("hand_number", strconv.Itoa(updatedGameState.HandNumber)),
					sdk.NewAttribute("block_height", strconv.FormatInt(sdkCtx.BlockHeight(), 10)),
					sdk.NewAttribute("community_cards", communityCardsStr),
					sdk.NewAttribute("revealed_hole_cards", revealedCardsStr),
					sdk.NewAttribute("winner_count", strconv.Itoa(len(updatedGameState.Winners))),
				),
			})
		}
	} else {
		return fmt.Errorf("no result returned from poker engine")
	}

	return nil
}
