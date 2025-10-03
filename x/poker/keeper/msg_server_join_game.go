package keeper

import (
	"context"

	errorsmod "cosmossdk.io/errors"
	"github.com/block52/pokerchain/x/poker/types"
)

func (k msgServer) JoinGame(ctx context.Context, msg *types.MsgJoinGame) (*types.MsgJoinGameResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(err, "invalid authority address")
	}

	// TODO: Handle the message

	return &types.MsgJoinGameResponse{}, nil
}
