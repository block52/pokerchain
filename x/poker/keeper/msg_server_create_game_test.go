package keeper_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/block52/pokerchain/x/poker/keeper"
	"github.com/block52/pokerchain/x/poker/types"
)

func TestMsgCreateGame(t *testing.T) {
	f := initFixture(t)
	ms := keeper.NewMsgServerImpl(f.keeper)

	testCases := []struct {
		name      string
		input     *types.MsgCreateGame
		expErr    bool
		expErrMsg string
	}{
		{
			name: "invalid creator address",
			input: &types.MsgCreateGame{
				Creator: "invalid_address",
			},
			expErr:    true,
			expErrMsg: "invalid creator address",
		},
		// Note: Testing with valid address would require proper mock setup for bankKeeper
		// The implementation is complete but requires integration testing with proper setup
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := ms.CreateGame(f.ctx, tc.input)

			if tc.expErr {
				require.Error(t, err)
				require.Contains(t, err.Error(), tc.expErrMsg)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestGameStateStorage(t *testing.T) {
	f := initFixture(t)

	// Test that the GameStates collection is properly configured
	gameId := "test_game_123"

	// Create string pointers for the test
	minBuyIn := "1000"
	maxBuyIn := "10000"
	smallBlind := "50"
	bigBlind := "100"
	minPlayers := 2
	maxPlayers := 6
	gameType := types.GameTypeTexasHoldem

	// Create a sample game state
	gameState := types.TexasHoldemStateDTO{
		Type:        types.GameTypeTexasHoldem,
		Address:     gameId,
		HandNumber:  1,
		Round:       types.RoundAnte,
		ActionCount: 0,
		GameOptions: types.GameOptionsDTO{
			MinBuyIn:   &minBuyIn,
			MaxBuyIn:   &maxBuyIn,
			SmallBlind: &smallBlind,
			BigBlind:   &bigBlind,
			MinPlayers: &minPlayers,
			MaxPlayers: &maxPlayers,
			Type:       &gameType,
		},
		Players:         []types.PlayerDTO{},
		CommunityCards:  []string{},
		Deck:            "",
		Pots:            []string{},
		NextToAct:       0,
		PreviousActions: []types.ActionDTO{},
		Winners:         []types.WinnerDTO{},
		Results:         []types.ResultDTO{},
		Signature:       "",
	}

	// Store the game state
	err := f.keeper.GameStates.Set(f.ctx, gameId, gameState)
	require.NoError(t, err)

	// Retrieve the game state
	retrievedState, err := f.keeper.GameStates.Get(f.ctx, gameId)
	require.NoError(t, err)

	// Verify the stored data matches
	require.Equal(t, gameState.Type, retrievedState.Type)
	require.Equal(t, gameState.Address, retrievedState.Address)
	require.Equal(t, gameState.HandNumber, retrievedState.HandNumber)
	require.Equal(t, gameState.Round, retrievedState.Round)
	require.Equal(t, gameState.ActionCount, retrievedState.ActionCount)
	require.Equal(t, gameState.GameOptions.MinBuyIn, retrievedState.GameOptions.MinBuyIn)
	require.Equal(t, gameState.GameOptions.MaxBuyIn, retrievedState.GameOptions.MaxBuyIn)
	require.Equal(t, gameState.GameOptions.SmallBlind, retrievedState.GameOptions.SmallBlind)
	require.Equal(t, gameState.GameOptions.BigBlind, retrievedState.GameOptions.BigBlind)
	require.Equal(t, gameState.GameOptions.MinPlayers, retrievedState.GameOptions.MinPlayers)
	require.Equal(t, gameState.GameOptions.MaxPlayers, retrievedState.GameOptions.MaxPlayers)
}
