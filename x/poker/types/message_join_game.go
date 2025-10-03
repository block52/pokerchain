package types

func NewMsgJoinGame(creator string, gameId string, seat uint64, buyIn uint64) *MsgJoinGame {
	return &MsgJoinGame{
		Creator: creator,
		GameId:  gameId,
		Seat:    seat,
		BuyIn:   buyIn,
	}
}
