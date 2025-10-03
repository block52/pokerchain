package keeper

import (
	"context"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) LegalActions(ctx context.Context, req *types.QueryLegalActionsRequest) (*types.QueryLegalActionsResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	// TODO: Process the query

	return &types.QueryLegalActionsResponse{}, nil
}
