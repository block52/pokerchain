package types

func NewMsgPerformAction(player string, gameId string, action string, amount uint64) *MsgPerformAction {
	return &MsgPerformAction{
		Player:  player,
		GameId:  gameId,
		Action:  action,
		Amount:  amount,
	}
}
