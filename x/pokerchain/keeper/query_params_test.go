package keeper_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/block52/pokerchain/x/pokerchain/keeper"
	"github.com/block52/pokerchain/x/pokerchain/types"
)

func TestParamsQuery(t *testing.T) {
	f := initFixture(t)

	qs := keeper.NewQueryServerImpl(f.keeper)
	params := types.DefaultParams()
	require.NoError(t, f.keeper.Params.Set(f.ctx, params))

	response, err := qs.Params(f.ctx, &types.QueryParamsRequest{})
	require.NoError(t, err)
	require.Equal(t, &types.QueryParamsResponse{Params: params}, response)
}
