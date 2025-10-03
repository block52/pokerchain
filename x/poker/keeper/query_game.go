package keeper

import (
	"context"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) Game(ctx context.Context, req *types.QueryGameRequest) (*types.QueryGameResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	// TODO: Process the query

	return &types.QueryGameResponse{}, nil
}
