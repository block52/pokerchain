package types

func NewMsgPerformAction(creator string, gameId string, action string, amount uint64) *MsgPerformAction {
	return &MsgPerformAction{
		Creator: creator,
		GameId:  gameId,
		Action:  action,
		Amount:  amount,
	}
}
