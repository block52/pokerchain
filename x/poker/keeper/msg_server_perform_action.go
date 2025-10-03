package keeper

import (
	"context"

	errorsmod "cosmossdk.io/errors"
	"github.com/block52/pokerchain/x/poker/types"
)

func (k msgServer) PerformAction(ctx context.Context, msg *types.MsgPerformAction) (*types.MsgPerformActionResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(err, "invalid authority address")
	}

	// TODO: Handle the message

	return &types.MsgPerformActionResponse{}, nil
}
