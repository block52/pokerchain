package types

func NewMsgLeaveGame(creator string, gameId string) *MsgLeaveGame {
	return &MsgLeaveGame{
		Creator: creator,
		GameId:  gameId,
	}
}
