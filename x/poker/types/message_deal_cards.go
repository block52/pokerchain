package types

func NewMsgDealCards(creator string, gameId string) *MsgDealCards {
	return &MsgDealCards{
		Creator: creator,
		GameId:  gameId,
	}
}
