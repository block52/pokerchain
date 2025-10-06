package types

import (
	"encoding/json"
	"time"
)

const (
	// TokenDenom is the denomination of the game token
	TokenDenom = "token"

	// GameCreationCost is the cost in tokens to create a new game
	GameCreationCost = int64(1)
)

// Game represents a poker game
type Game struct {
	GameId     string    `json:"game_id"`
	Creator    string    `json:"creator"`
	MinBuyIn   uint64    `json:"min_buy_in"`
	MaxBuyIn   uint64    `json:"max_buy_in"`
	MinPlayers int64     `json:"min_players"`
	MaxPlayers int64     `json:"max_players"`
	SmallBlind uint64    `json:"small_blind"`
	BigBlind   uint64    `json:"big_blind"`
	Timeout    int64     `json:"timeout"`
	GameType   string    `json:"game_type"`
	Players    []string  `json:"players"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// Marshal implements the protobuf marshaling interface
func (g Game) Marshal() ([]byte, error) {
	return json.Marshal(g)
}

// Unmarshal implements the protobuf unmarshaling interface
func (g *Game) Unmarshal(data []byte) error {
	return json.Unmarshal(data, g)
}

// ProtoMessage implements the protobuf message interface
func (g *Game) ProtoMessage() {}

// Reset implements the protobuf message interface
func (g *Game) Reset() {
	*g = Game{}
}

// String implements the protobuf message interface
func (g *Game) String() string {
	data, _ := json.Marshal(g)
	return string(data)
}
