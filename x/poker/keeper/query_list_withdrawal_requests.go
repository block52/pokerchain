package keeper

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/block52/pokerchain/x/poker/types"
)

// ListWithdrawalRequests handles queries for listing withdrawal requests
// Optionally filtered by cosmos address
func (qs queryServer) ListWithdrawalRequests(ctx context.Context, req *types.QueryListWithdrawalRequestsRequest) (*types.QueryListWithdrawalRequestsResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	// Get withdrawal requests from keeper
	withdrawalRequests, err := qs.k.ListWithdrawalRequestsInternal(ctx, req.CosmosAddress)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list withdrawal requests")
	}

	// Convert from []*WithdrawalRequest to []WithdrawalRequest for proto response
	requests := make([]*types.WithdrawalRequest, len(withdrawalRequests))
	copy(requests, withdrawalRequests)

	return &types.QueryListWithdrawalRequestsResponse{
		WithdrawalRequests: requests,
		Pagination:         nil, // TODO: Add pagination support if needed
	}, nil
}
