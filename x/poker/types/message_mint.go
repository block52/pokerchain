package types

func NewMsgMint(creator string, recipient string, amount uint64, ethTxHash string, nonce uint64) *MsgMint {
	return &MsgMint{
		Creator:   creator,
		Recipient: recipient,
		Amount:    amount,
		EthTxHash: ethTxHash,
		Nonce:     nonce,
	}
}
