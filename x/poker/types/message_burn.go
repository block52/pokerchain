package types

func NewMsgBurn(creator string, amount uint64, ethRecipient string) *MsgBurn {
	return &MsgBurn{
		Creator:      creator,
		Amount:       amount,
		EthRecipient: ethRecipient,
	}
}
