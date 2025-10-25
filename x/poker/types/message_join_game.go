package types

func NewMsgJoinGame(player string, gameId string, seat uint64, buyInAmount uint64) *MsgJoinGame {
	return &MsgJoinGame{
		Player:      player,
		GameId:      gameId,
		Seat:        seat,
		BuyInAmount: buyInAmount,
	}
}
