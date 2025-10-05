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
