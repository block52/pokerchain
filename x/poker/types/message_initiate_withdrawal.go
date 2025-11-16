package types

import (
	"strings"

	"cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	"github.com/ethereum/go-ethereum/common"
)

// Ensure MsgInitiateWithdrawal implements sdk.Msg
var _ sdk.Msg = &MsgInitiateWithdrawal{}

// ValidateBasic performs basic validation of MsgInitiateWithdrawal
func (msg *MsgInitiateWithdrawal) ValidateBasic() error {
	// Validate creator address
	if _, err := sdk.AccAddressFromBech32(msg.Creator); err != nil {
		return errors.Wrapf(sdkerrors.ErrInvalidAddress, "invalid creator address (%s)", err)
	}

	// Validate amount
	if msg.Amount == 0 {
		return errors.Wrap(ErrInvalidAmount, "withdrawal amount must be greater than 0")
	}

	// Validate Base/Ethereum address format
	if msg.BaseAddress == "" {
		return errors.Wrap(sdkerrors.ErrInvalidRequest, "base address cannot be empty")
	}

	if !strings.HasPrefix(msg.BaseAddress, "0x") {
		return errors.Wrap(sdkerrors.ErrInvalidRequest, "base address must start with 0x")
	}

	if len(msg.BaseAddress) != 42 {
		return errors.Wrap(sdkerrors.ErrInvalidRequest, "base address must be 42 characters (0x + 40 hex chars)")
	}

	// Validate it's a valid Ethereum address
	if !common.IsHexAddress(msg.BaseAddress) {
		return errors.Wrapf(sdkerrors.ErrInvalidRequest, "invalid base address checksum: %s", msg.BaseAddress)
	}

	return nil
}
