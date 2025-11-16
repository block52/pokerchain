package keeper

import (
	"context"

	sdk "github.com/cosmos/cosmos-sdk/types"

	"github.com/block52/pokerchain/x/poker/types"
)

// InitGenesis initializes the module's state from a provided genesis state.
func (k Keeper) InitGenesis(ctx context.Context, genState types.GenesisState) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Set params
	if err := k.Params.Set(ctx, genState.Params); err != nil {
		return err
	}

	// Import processed Ethereum transaction hashes (bridge state)
	for _, txHash := range genState.ProcessedEthTxs {
		if err := k.ProcessedEthTxs.Set(sdkCtx, txHash); err != nil {
			return err
		}
	}

	// Import withdrawal requests
	for _, wr := range genState.WithdrawalRequests {
		if err := k.WithdrawalRequests.Set(sdkCtx, wr.Nonce, *wr); err != nil {
			return err
		}
	}

	// Set withdrawal nonce sequence
	if genState.WithdrawalNonce > 0 {
		if err := k.WithdrawalNonce.Set(sdkCtx, genState.WithdrawalNonce); err != nil {
			return err
		}
	}

	return nil
}

// ExportGenesis returns the module's exported genesis.
func (k Keeper) ExportGenesis(ctx context.Context) (*types.GenesisState, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	var err error

	genesis := types.DefaultGenesis()
	genesis.Params, err = k.Params.Get(ctx)
	if err != nil {
		return nil, err
	}

	// Export processed Ethereum transaction hashes
	genesis.ProcessedEthTxs = []string{}
	err = k.ProcessedEthTxs.Walk(sdkCtx, nil, func(txHash string) (bool, error) {
		genesis.ProcessedEthTxs = append(genesis.ProcessedEthTxs, txHash)
		return false, nil // Continue iteration
	})
	if err != nil {
		return nil, err
	}

	// Export withdrawal requests
	genesis.WithdrawalRequests = []*types.WithdrawalRequest{}
	err = k.WithdrawalRequests.Walk(sdkCtx, nil, func(nonce string, wr types.WithdrawalRequest) (bool, error) {
		genesis.WithdrawalRequests = append(genesis.WithdrawalRequests, &wr)
		return false, nil // Continue iteration
	})
	if err != nil {
		return nil, err
	}

	// Export withdrawal nonce
	genesis.WithdrawalNonce, err = k.WithdrawalNonce.Peek(sdkCtx)
	if err != nil {
		// If no nonce has been set yet, default to 0
		genesis.WithdrawalNonce = 0
	}

	return genesis, nil
}
