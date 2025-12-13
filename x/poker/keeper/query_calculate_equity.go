package keeper

import (
	"context"
	"fmt"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/block52/pokerchain/x/poker/equity"
	"github.com/block52/pokerchain/x/poker/types"
)

func (q queryServer) CalculateEquity(ctx context.Context, req *types.QueryCalculateEquityRequest) (*types.QueryCalculateEquityResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if len(req.Hands) < 2 {
		return nil, status.Error(codes.InvalidArgument, "must provide at least 2 hands")
	}

	if len(req.Hands) > 9 {
		return nil, status.Error(codes.InvalidArgument, "maximum 9 hands allowed")
	}

	// Convert proto HandCards to [][]string
	hands := make([][]string, len(req.Hands))
	for i, h := range req.Hands {
		if h == nil || len(h.Cards) != 2 {
			return nil, status.Errorf(codes.InvalidArgument, "hand %d must have exactly 2 cards", i)
		}
		hands[i] = h.Cards
	}

	// Set default simulations if not specified
	simulations := int(req.Simulations)
	if simulations <= 0 {
		simulations = 10000
	}
	if simulations > 100000 {
		simulations = 100000 // Cap at 100k for performance
	}

	// Create calculator and run equity calculation
	calc := equity.NewCalculator(equity.WithSimulations(simulations))
	result, err := calc.CalculateEquity(hands, req.Board, req.Dead)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "equity calculation failed: %v", err)
	}

	// Convert results to proto format
	protoResults := make([]*types.EquityResult, len(result.Results))
	for i, r := range result.Results {
		protoResults[i] = &types.EquityResult{
			HandIndex:  int32(r.HandIndex),
			Hand:       hands[r.HandIndex],
			Wins:       int32(r.Wins),
			Ties:       int32(r.Ties),
			Losses:     int32(r.Losses),
			Equity:     fmt.Sprintf("%.4f", r.Equity),
			TieEquity:  fmt.Sprintf("%.4f", r.TieEquity),
			Total:      fmt.Sprintf("%.4f", r.Total),
		}
	}

	return &types.QueryCalculateEquityResponse{
		Results:     protoResults,
		Simulations: int32(result.Simulations),
		Stage:       result.Stage.String(),
		DurationMs:  fmt.Sprintf("%.2f", float64(result.Duration.Microseconds())/1000.0),
		HandsPerSec: fmt.Sprintf("%.0f", result.HandsPerSec),
	}, nil
}
