package types

import (
	"encoding/json"
	"time"
)

const (
	// TokenDenom is the denomination of the game token
	TokenDenom = "uusdc"

	// GameCreationCost is the cost in tokens to create a new game
	GameCreationCost = int64(1)
)

// GameType represents the type of poker game
type GameType string

const (
	GameTypeTexasHoldem GameType = "texas-holdem"
	GameTypeOmaha       GameType = "omaha"
	GameTypeSevenCard   GameType = "seven-card-stud"
)

// TexasHoldemRound represents the current round of a Texas Hold'em game
type TexasHoldemRound string

const (
	RoundAnte     TexasHoldemRound = "ante"
	RoundPreflop  TexasHoldemRound = "preflop"
	RoundFlop     TexasHoldemRound = "flop"
	RoundTurn     TexasHoldemRound = "turn"
	RoundRiver    TexasHoldemRound = "river"
	RoundShowdown TexasHoldemRound = "showdown"
)

// PlayerActionType represents actions that players can take
type PlayerActionType string

const (
	ActionFold  PlayerActionType = "fold"
	ActionCheck PlayerActionType = "check"
	ActionCall  PlayerActionType = "call"
	ActionBet   PlayerActionType = "bet"
	ActionRaise PlayerActionType = "raise"
	ActionAllIn PlayerActionType = "all-in"
)

// NonPlayerActionType represents system/non-player actions
type NonPlayerActionType string

const (
	ActionDeal     NonPlayerActionType = "deal"
	ActionReveal   NonPlayerActionType = "reveal"
	ActionShuffle  NonPlayerActionType = "shuffle"
	ActionTimeout  NonPlayerActionType = "timeout"
	ActionShowdown NonPlayerActionType = "showdown"
)

// PlayerStatus represents the status of a player in the game
type PlayerStatus string

const (
	StatusActive       PlayerStatus = "active"
	StatusFolded       PlayerStatus = "folded"
	StatusAllIn        PlayerStatus = "all-in"
	StatusSitOut       PlayerStatus = "sit-out"
	StatusDisconnected PlayerStatus = "disconnected"
)

// GameOptionsDTO represents the game configuration options
type GameOptionsDTO struct {
	MinBuyIn     *string                `json:"min_buy_in,omitempty"`
	MaxBuyIn     *string                `json:"max_buy_in,omitempty"`
	MinPlayers   *int                   `json:"min_players,omitempty"`
	MaxPlayers   *int                   `json:"max_players,omitempty"`
	SmallBlind   *string                `json:"small_blind,omitempty"`
	BigBlind     *string                `json:"big_blind,omitempty"`
	Timeout      *int                   `json:"timeout,omitempty"`
	Type         *GameType              `json:"type,omitempty"`
	OtherOptions map[string]interface{} `json:"other_options,omitempty"`
}

// PlayerDTO represents a player in the game
type PlayerDTO struct {
	Address      string           `json:"address"`
	Seat         int              `json:"seat"`
	Stack        string           `json:"stack"`
	IsSmallBlind bool             `json:"is_small_blind"`
	IsBigBlind   bool             `json:"is_big_blind"`
	IsDealer     bool             `json:"is_dealer"`
	HoleCards    *[]string        `json:"hole_cards,omitempty"`
	Status       PlayerStatus     `json:"status"`
	LastAction   *ActionDTO       `json:"last_action,omitempty"`
	LegalActions []LegalActionDTO `json:"legal_actions"`
	SumOfBets    string           `json:"sum_of_bets"`
	Timeout      int              `json:"timeout"`
	Signature    string           `json:"signature"`
}

// ActionDTO represents a player action
type ActionDTO struct {
	PlayerId  string           `json:"player_id"`
	Seat      int              `json:"seat"`
	Action    string           `json:"action"` // Can be PlayerActionType or NonPlayerActionType
	Amount    string           `json:"amount"`
	Round     TexasHoldemRound `json:"round"`
	Index     int              `json:"index"`
	Timestamp int64            `json:"timestamp"`
}

// LegalActionDTO represents a legal action available to a player
type LegalActionDTO struct {
	Action string  `json:"action"` // Can be PlayerActionType or NonPlayerActionType
	Min    *string `json:"min,omitempty"`
	Max    *string `json:"max,omitempty"`
	Index  int     `json:"index"`
}

// WinnerDTO represents a game winner
type WinnerDTO struct {
	Address     string    `json:"address"`
	Amount      string    `json:"amount"`
	Cards       *[]string `json:"cards,omitempty"`
	Name        *string   `json:"name,omitempty"`
	Description *string   `json:"description,omitempty"`
}

// ResultDTO represents game results
type ResultDTO struct {
	Place    int    `json:"place"`
	PlayerId string `json:"player_id"`
	Payout   string `json:"payout"`
}

// TexasHoldemStateDTO represents the complete game state
type TexasHoldemStateDTO struct {
	Type            GameType         `json:"type"`
	Address         string           `json:"address"`
	GameOptions     GameOptionsDTO   `json:"game_options"`
	Players         []PlayerDTO      `json:"players"`
	CommunityCards  []string         `json:"community_cards"`
	Deck            string           `json:"deck"`
	Pots            []string         `json:"pots"`
	NextToAct       int              `json:"next_to_act"`
	PreviousActions []ActionDTO      `json:"previous_actions"`
	ActionCount     int              `json:"action_count"`
	HandNumber      int              `json:"hand_number"`
	Round           TexasHoldemRound `json:"round"`
	Winners         []WinnerDTO      `json:"winners"`
	Results         []ResultDTO      `json:"results"`
	Signature       string           `json:"signature"`
}

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

// Marshal implements the protobuf marshaling interface for TexasHoldemStateDTO
func (t TexasHoldemStateDTO) Marshal() ([]byte, error) {
	return json.Marshal(t)
}

// Unmarshal implements the protobuf unmarshaling interface for TexasHoldemStateDTO
func (t *TexasHoldemStateDTO) Unmarshal(data []byte) error {
	return json.Unmarshal(data, t)
}

// ProtoMessage implements the protobuf message interface for TexasHoldemStateDTO
func (t *TexasHoldemStateDTO) ProtoMessage() {}

// Reset implements the protobuf message interface for TexasHoldemStateDTO
func (t *TexasHoldemStateDTO) Reset() {
	*t = TexasHoldemStateDTO{}
}

// String implements the protobuf message interface for TexasHoldemStateDTO
func (t *TexasHoldemStateDTO) String() string {
	data, _ := json.Marshal(t)
	return string(data)
}
