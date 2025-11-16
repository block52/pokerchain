package keeper

import (
	"context"

	"github.com/block52/pokerchain/x/poker/types"
)

// InitiateWithdrawal handles MsgInitiateWithdrawal transactions.
// This is the message server entry point for users initiating USDC withdrawals
// from Cosmos chain to Base chain.
func (ms msgServer) InitiateWithdrawal(ctx context.Context, msg *types.MsgInitiateWithdrawal) (*types.MsgInitiateWithdrawalResponse, error) {
	// Validate message (basic validation is done in ValidateBasic, but we can add more here)
	if msg.Amount == 0 {
		return nil, types.ErrInvalidAmount
	}

	// Call keeper to initiate withdrawal
	nonce, err := ms.Keeper.InitiateWithdrawal(ctx, msg.Creator, msg.BaseAddress, msg.Amount)
	if err != nil {
		return nil, err
	}

	return &types.MsgInitiateWithdrawalResponse{
		Nonce: nonce,
	}, nil
}
