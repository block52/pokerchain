package types

import (
	"encoding/hex"
	"strings"

	errorsmod "cosmossdk.io/errors"

	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
)

var _ sdk.Msg = &MsgSignWithdrawal{}

func NewMsgSignWithdrawal(signer string, nonce string, validatorEthKeyHex string) *MsgSignWithdrawal {
	return &MsgSignWithdrawal{
		Signer:             signer,
		Nonce:              nonce,
		ValidatorEthKeyHex: validatorEthKeyHex,
	}
}

// ValidateBasic performs basic validation of the message
func (msg *MsgSignWithdrawal) ValidateBasic() error {
	// Validate signer address
	if _, err := sdk.AccAddressFromBech32(msg.Signer); err != nil {
		return errorsmod.Wrapf(sdkerrors.ErrInvalidAddress, "invalid signer address (%s)", err)
	}

	// Validate nonce
	if msg.Nonce == "" {
		return errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "nonce cannot be empty")
	}

	// Validate it starts with 0x and has correct length (66 characters: 0x + 64 hex chars)
	if !strings.HasPrefix(msg.Nonce, "0x") || len(msg.Nonce) != 66 {
		return errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "invalid nonce format: must be 0x followed by 64 hex characters")
	}

	// Validate Ethereum private key
	if msg.ValidatorEthKeyHex == "" {
		return errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "validator Ethereum key cannot be empty")
	}

	// Remove 0x prefix if present for validation
	keyHex := msg.ValidatorEthKeyHex
	if strings.HasPrefix(keyHex, "0x") {
		keyHex = keyHex[2:]
	}

	// Validate key length (should be 64 hex characters = 32 bytes)
	if len(keyHex) != 64 {
		return errorsmod.Wrapf(sdkerrors.ErrInvalidRequest,
			"invalid Ethereum private key length: expected 64 hex characters (optionally prefixed with 0x), got %d", len(keyHex))
	}

	// Validate it's valid hex
	if _, err := hex.DecodeString(keyHex); err != nil {
		return errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "invalid Ethereum private key: must be valid hex")
	}

	return nil
}
