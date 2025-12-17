package keeper

import (
	"context"

	"github.com/cosmos/cosmos-sdk/version"

	"github.com/block52/pokerchain/x/poker/types"
)

// Version returns chain version info and PVM health status
func (q queryServer) Version(ctx context.Context, req *types.QueryVersionRequest) (*types.QueryVersionResponse, error) {
	// Get chain version info from cosmos SDK version package (set via ldflags)
	chainVersion := &types.ChainVersion{
		Name:             "pokerchain",
		Version:          version.Version,
		ConsensusVersion: 1,
	}

	// Check PVM health
	pvmStatus := q.k.checkPvmHealth()

	return &types.QueryVersionResponse{
		Chain: chainVersion,
		Pvm:   pvmStatus,
	}, nil
}
