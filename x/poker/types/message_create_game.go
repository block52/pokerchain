package types

func NewMsgCreateGame(creator string, minBuyIn uint64, maxBuyIn uint64, minPlayers int64, maxPlayers int64, smallBlind uint64, bigBlind uint64, timeout int64, gameType string) *MsgCreateGame {
	return &MsgCreateGame{
		Creator:    creator,
		MinBuyIn:   minBuyIn,
		MaxBuyIn:   maxBuyIn,
		MinPlayers: minPlayers,
		MaxPlayers: maxPlayers,
		SmallBlind: smallBlind,
		BigBlind:   bigBlind,
		Timeout:    timeout,
		GameType:   gameType,
	}
}
