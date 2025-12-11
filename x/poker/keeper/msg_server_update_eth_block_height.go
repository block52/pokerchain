package keeper

import (
	"bytes"
	"context"

	errorsmod "cosmossdk.io/errors"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// UpdateEthBlockHeight handles updating the Ethereum block height used for deterministic deposit queries.
// This is CONSENSUS CRITICAL - all validators must use the same height when querying deposits.
func (k msgServer) UpdateEthBlockHeight(ctx context.Context, msg *types.MsgUpdateEthBlockHeight) (*types.MsgUpdateEthBlockHeightResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	sdkCtx.Logger().Info("📦 UpdateEthBlockHeight called",
		"authority", msg.Authority,
		"eth_block_height", msg.EthBlockHeight)

	// Verify authority (should be gov module or admin)
	authority, err := k.addressCodec.StringToBytes(msg.Authority)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid authority address")
	}

	if !bytes.Equal(k.GetAuthority(), authority) {
		expectedAuthorityStr, _ := k.addressCodec.BytesToString(k.GetAuthority())
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest,
			"invalid authority; expected %s, got %s", expectedAuthorityStr, msg.Authority)
	}

	// Get current height for response
	oldHeight, _ := k.GetLastEthBlockHeight(ctx)

	// Call the keeper method to update
	if err := k.Keeper.UpdateEthBlockHeight(ctx, msg.EthBlockHeight); err != nil {
		return nil, errorsmod.Wrap(err, "failed to update eth block height")
	}

	return &types.MsgUpdateEthBlockHeightResponse{
		OldHeight: oldHeight,
		NewHeight: msg.EthBlockHeight,
	}, nil
}
