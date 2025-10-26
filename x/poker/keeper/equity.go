package keeper

import (
	"fmt"

	"github.com/block52/pokerchain/x/poker/equity"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// CalculatePlayerEquity is a Cosmos SDK compatible method for calculating poker equity
// Can be called from your module's message handlers
func (k Keeper) CalculatePlayerEquity(
	ctx sdk.Context,
	gameID string,
	playerHands [][]string,
	communityCards []string,
	simulations int,
) ([]equity.EquityResult, error) {
	// Validate input
	if len(playerHands) < 2 {
		return nil, fmt.Errorf("need at least 2 players")
	}

	if simulations <= 0 {
		simulations = 10000 // Default
	}

	// Create equity calculator instance
	calc := equity.NewEquityCalculator()

	// Calculate equity
	results, err := calc.CalculateEquity(playerHands, communityCards, simulations)
	if err != nil {
		return nil, fmt.Errorf("equity calculation failed: %w", err)
	}

	// Log to blockchain (optional - for debugging/auditing)
	ctx.Logger().Info("Poker equity calculated",
		"gameID", gameID,
		"players", len(playerHands),
		"simulations", simulations,
	)

	return results, nil
}

// Example message handler for a Cosmos SDK module
type MsgCalculateEquity struct {
	GameID         string     `json:"game_id"`
	PlayerHands    [][]string `json:"player_hands"`
	CommunityCards []string   `json:"community_cards"`
	Simulations    int        `json:"simulations"`
	Sender         string     `json:"sender"`
}

// HandleMsgCalculateEquity is an example message handler
func HandleMsgCalculateEquity(ctx sdk.Context, keeper Keeper, msg MsgCalculateEquity) (*sdk.Result, error) {
	// Verify sender has permission (game creator, admin, etc.)
	// ... add your authorization logic here

	// Calculate equity
	results, err := keeper.CalculatePlayerEquity(
		ctx,
		msg.GameID,
		msg.PlayerHands,
		msg.CommunityCards,
		msg.Simulations,
	)
	if err != nil {
		return nil, err
	}

	// Emit event with results
	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"poker_equity_calculated",
			sdk.NewAttribute("game_id", msg.GameID),
			sdk.NewAttribute("players", fmt.Sprintf("%d", len(results))),
		),
	)

	// Store results in state if needed
	// ... add your storage logic here

	return &sdk.Result{
		Events: ctx.EventManager().ABCIEvents(),
	}, nil
}

// Example query handler for reading equity data
type QueryEquityParams struct {
	GameID         string     `json:"game_id"`
	PlayerHands    [][]string `json:"player_hands"`
	CommunityCards []string   `json:"community_cards"`
	Simulations    int        `json:"simulations"`
}

// QueryEquityResponse is the response for equity queries
type QueryEquityResponse struct {
	Results []EquityResultDTO `json:"results"`
}

// EquityResultDTO is a JSON-serializable equity result
type EquityResultDTO struct {
	PlayerIndex int     `json:"player_index"`
	WinPercent  float64 `json:"win_percent"`
	TiePercent  float64 `json:"tie_percent"`
	Hands       int     `json:"hands"`
}

// QueryEquity handles equity calculation queries (read-only, doesn't modify state)
func QueryEquity(ctx sdk.Context, keeper Keeper, params QueryEquityParams) (QueryEquityResponse, error) {
	results, err := keeper.CalculatePlayerEquity(
		ctx,
		params.GameID,
		params.PlayerHands,
		params.CommunityCards,
		params.Simulations,
	)
	if err != nil {
		return QueryEquityResponse{}, err
	}

	// Convert to DTO
	dtoResults := make([]EquityResultDTO, len(results))
	for i, result := range results {
		dtoResults[i] = EquityResultDTO{
			PlayerIndex: result.PlayerIndex,
			WinPercent:  result.WinPercent,
			TiePercent:  result.TiePercent,
			Hands:       result.Hands,
		}
	}

	return QueryEquityResponse{Results: dtoResults}, nil
}

// Example CLI command for Cosmos SDK
/*
func GetQueryEquityCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "equity [game-id] [player-hands-json] [community-cards-json] [simulations]",
		Short: "Calculate poker equity for a game",
		Args:  cobra.ExactArgs(4),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx := client.GetClientContextFromCmd(cmd)

			gameID := args[0]

			var playerHands [][]string
			if err := json.Unmarshal([]byte(args[1]), &playerHands); err != nil {
				return err
			}

			var communityCards []string
			if err := json.Unmarshal([]byte(args[2]), &communityCards); err != nil {
				return err
			}

			simulations, err := strconv.Atoi(args[3])
			if err != nil {
				return err
			}

			params := QueryEquityParams{
				GameID:         gameID,
				PlayerHands:    playerHands,
				CommunityCards: communityCards,
				Simulations:    simulations,
			}

			bz, err := clientCtx.LegacyAmino.MarshalJSON(params)
			if err != nil {
				return err
			}

			route := fmt.Sprintf("custom/%s/equity", types.QuerierRoute)
			res, _, err := clientCtx.QueryWithData(route, bz)
			if err != nil {
				return err
			}

			var response QueryEquityResponse
			if err := clientCtx.LegacyAmino.UnmarshalJSON(res, &response); err != nil {
				return err
			}

			return clientCtx.PrintProto(&response)
		},
	}

	return cmd
}
*/

// Example usage in CLI:
// poker-chaind query poker equity game123 '[["AS","AH"],["KS","KH"]]' '["2C","7D","9H"]' 10000
