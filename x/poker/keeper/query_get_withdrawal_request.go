package keeper

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/block52/pokerchain/x/poker/types"
)

// GetWithdrawalRequest handles queries for a specific withdrawal request by nonce
func (qs queryServer) GetWithdrawalRequest(ctx context.Context, req *types.QueryGetWithdrawalRequestRequest) (*types.QueryGetWithdrawalRequestResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.Nonce == "" {
		return nil, status.Error(codes.InvalidArgument, "nonce cannot be empty")
	}

	// Get withdrawal request from keeper
	withdrawalRequest, err := qs.k.getWithdrawalRequest(ctx, req.Nonce)
	if err != nil {
		return nil, status.Error(codes.NotFound, "withdrawal request not found")
	}

	return &types.QueryGetWithdrawalRequestResponse{
		WithdrawalRequest: withdrawalRequest,
	}, nil
}
