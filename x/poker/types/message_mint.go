package types

import (
	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

func NewMsgMint(creator string, recipient string, amount uint64, ethTxHash string, nonce uint64) *MsgMint {
	return &MsgMint{
		Creator:   creator,
		Recipient: recipient,
		Amount:    amount,
		EthTxHash: ethTxHash,
		Nonce:     nonce,
	}
}

// ValidateBasic performs basic validation of the MsgMint message
func (msg *MsgMint) ValidateBasic() error {
	// Validate creator address
	if _, err := sdk.AccAddressFromBech32(msg.Creator); err != nil {
		return errorsmod.Wrapf(ErrInvalidSigner, "invalid creator address: %v", err)
	}

	// Validate recipient address
	if _, err := sdk.AccAddressFromBech32(msg.Recipient); err != nil {
		return errorsmod.Wrapf(ErrInvalidRecipient, "invalid recipient address: %v", err)
	}

	// Validate amount
	if msg.Amount == 0 {
		return errorsmod.Wrap(ErrInvalidAmount, "amount must be greater than zero")
	}

	// Validate Ethereum transaction hash
	if len(msg.EthTxHash) == 0 {
		return errorsmod.Wrap(ErrInvalidSigner, "ethereum transaction hash cannot be empty")
	}

	return nil
}
