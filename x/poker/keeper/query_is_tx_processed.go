package keeper

import (
	"context"

	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// IsTxProcessed checks if an Ethereum transaction hash has been processed
func (q queryServer) IsTxProcessed(ctx context.Context, req *types.QueryIsTxProcessedRequest) (*types.QueryIsTxProcessedResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Check if the transaction hash exists in ProcessedEthTxs KeySet
	processed, err := q.k.ProcessedEthTxs.Has(sdkCtx, req.EthTxHash)
	if err != nil {
		return nil, err
	}

	return &types.QueryIsTxProcessedResponse{
		Processed: processed,
	}, nil
}
