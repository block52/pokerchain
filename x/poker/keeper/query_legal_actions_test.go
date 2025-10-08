package keeper_test

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/block52/pokerchain/x/poker/keeper"
	"github.com/block52/pokerchain/x/poker/types"
)

func TestQueryLegalActions(t *testing.T) {
	f := initFixture(t)
	qs := keeper.NewQueryServerImpl(f.keeper)

	testCases := []struct {
		name       string
		input      *types.QueryLegalActionsRequest
		setup      func()
		expErr     bool
		expErrMsg  string
		expActions []types.LegalActionDTO
	}{
		{
			name:      "invalid request - nil",
			input:     nil,
			expErr:    true,
			expErrMsg: "invalid request",
		},
		{
			name: "invalid request - empty game ID",
			input: &types.QueryLegalActionsRequest{
				GameId:        "",
				PlayerAddress: "test_address",
			},
			expErr:    true,
			expErrMsg: "game ID cannot be empty",
		},
		{
			name: "invalid request - empty player address",
			input: &types.QueryLegalActionsRequest{
				GameId:        "test_game",
				PlayerAddress: "",
			},
			expErr:    true,
			expErrMsg: "player address cannot be empty",
		},
		{
			name: "game state not found",
			input: &types.QueryLegalActionsRequest{
				GameId:        "nonexistent_game",
				PlayerAddress: "test_address",
			},
			expErr:    true,
			expErrMsg: "game state not found",
		},
		{
			name: "player not in game - returns empty actions",
			input: &types.QueryLegalActionsRequest{
				GameId:        "test_game",
				PlayerAddress: "unknown_player",
			},
			setup: func() {
				// Create a game state without the requested player
				gameState := types.TexasHoldemStateDTO{
					Type:    types.GameTypeTexasHoldem,
					Address: "test_game",
					Players: []types.PlayerDTO{
						{
							Address: "other_player",
							LegalActions: []types.LegalActionDTO{
								{Action: "fold", Index: 0},
							},
						},
					},
				}
				err := f.keeper.GameStates.Set(f.ctx, "test_game", gameState)
				require.NoError(t, err)
			},
			expErr:     false,
			expActions: []types.LegalActionDTO{},
		},
		{
			name: "successful query - player with legal actions",
			input: &types.QueryLegalActionsRequest{
				GameId:        "test_game_with_player",
				PlayerAddress: "test_player",
			},
			setup: func() {
				minAmount := "100"
				maxAmount := "500"
				gameState := types.TexasHoldemStateDTO{
					Type:    types.GameTypeTexasHoldem,
					Address: "test_game_with_player",
					Players: []types.PlayerDTO{
						{
							Address: "test_player",
							LegalActions: []types.LegalActionDTO{
								{Action: "fold", Index: 0},
								{Action: "call", Min: &minAmount, Index: 1},
								{Action: "raise", Min: &minAmount, Max: &maxAmount, Index: 2},
							},
						},
						{
							Address: "other_player",
							LegalActions: []types.LegalActionDTO{
								{Action: "check", Index: 0},
							},
						},
					},
				}
				err := f.keeper.GameStates.Set(f.ctx, "test_game_with_player", gameState)
				require.NoError(t, err)
			},
			expErr: false,
			expActions: []types.LegalActionDTO{
				{Action: "fold", Index: 0},
				{Action: "call", Min: stringPtr("100"), Index: 1},
				{Action: "raise", Min: stringPtr("100"), Max: stringPtr("500"), Index: 2},
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			if tc.setup != nil {
				tc.setup()
			}

			resp, err := qs.LegalActions(f.ctx, tc.input)

			if tc.expErr {
				require.Error(t, err)
				require.Contains(t, err.Error(), tc.expErrMsg)
				require.Nil(t, resp)
			} else {
				require.NoError(t, err)
				require.NotNil(t, resp)

				// Parse the returned JSON actions
				var returnedActions []types.LegalActionDTO
				err = json.Unmarshal([]byte(resp.Actions), &returnedActions)
				require.NoError(t, err)

				// Compare the returned actions with expected
				require.Equal(t, tc.expActions, returnedActions)
			}
		})
	}
}

// Helper function to create string pointers
func stringPtr(s string) *string {
	return &s
}
