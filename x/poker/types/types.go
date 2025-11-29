package types

import (
	"encoding/json"
	"time"
)

const (
	// TokenDenom is the denomination of the game token
	TokenDenom = "usdc"

	// GameCreationCost is the cost in tokens to create a new game
	GameCreationCost = int64(1)
)

// GameType represents the type of poker game
type GameType string

const (
	GameTypeTexasHoldem GameType = "texas-holdem"
	GameTypeOmaha       GameType = "omaha"
	GameTypeSevenCard   GameType = "seven-card-stud"
	GameTypeCash        GameType = "cash"
	GameTypeSitAndGo    GameType = "sit-and-go"
	GameTypeTournament  GameType = "tournament"
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
	// Synced with poker-vm/sdk/src/types/game.ts PlayerStatus enum
	StatusActive     PlayerStatus = "active"
	StatusBusted     PlayerStatus = "busted"
	StatusFolded     PlayerStatus = "folded"
	StatusAllIn      PlayerStatus = "all-in"
	StatusSeated     PlayerStatus = "seated"
	StatusSittingOut PlayerStatus = "sitting-out"
	StatusSittingIn  PlayerStatus = "sitting-in"
	StatusShowing    PlayerStatus = "showing"
)

// GameOptionsDTO represents the game configuration options
type GameOptionsDTO struct {
	MinBuyIn     *string                `json:"minBuyIn,omitempty"`
	MaxBuyIn     *string                `json:"maxBuyIn,omitempty"`
	MinPlayers   *int                   `json:"minPlayers,omitempty"`
	MaxPlayers   *int                   `json:"maxPlayers,omitempty"`
	SmallBlind   *string                `json:"smallBlind,omitempty"`
	BigBlind     *string                `json:"bigBlind,omitempty"`
	Timeout      *int                   `json:"timeout,omitempty"`
	Type         *GameType              `json:"type,omitempty"`
	OtherOptions map[string]interface{} `json:"otherOptions,omitempty"`
}

// PlayerDTO represents a player in the game
type PlayerDTO struct {
	Address      string           `json:"address"`
	Seat         int              `json:"seat"`
	Stack        string           `json:"stack"`
	IsSmallBlind bool             `json:"isSmallBlind"`
	IsBigBlind   bool             `json:"isBigBlind"`
	IsDealer     bool             `json:"isDealer"`
	HoleCards    *[]string        `json:"holeCards,omitempty"`
	Status       PlayerStatus     `json:"status"`
	LastAction   *ActionDTO       `json:"lastAction,omitempty"`
	LegalActions []LegalActionDTO `json:"legalActions"`
	SumOfBets    string           `json:"sumOfBets"`
	Timeout      int              `json:"timeout"`
	Signature    string           `json:"signature"`
}

// ActionDTO represents a player action
type ActionDTO struct {
	PlayerId  string           `json:"playerId"`
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
	PlayerId string `json:"playerId"`
	Payout   string `json:"payout"`
}

// TexasHoldemStateDTO represents the complete game state
type TexasHoldemStateDTO struct {
	Type            GameType         `json:"type"`
	Address         string           `json:"address"`
	GameOptions     GameOptionsDTO   `json:"gameOptions"`
	Players         []PlayerDTO      `json:"players"`
	CommunityCards  []string         `json:"communityCards"`
	Deck            string           `json:"deck"`
	Pots            []string         `json:"pots"`
	NextToAct       int              `json:"nextToAct"`
	PreviousActions []ActionDTO      `json:"previousActions"`
	ActionCount     int              `json:"actionCount"`
	HandNumber      int              `json:"handNumber"`
	Round           TexasHoldemRound `json:"round"`
	Winners         []WinnerDTO      `json:"winners"`
	Results         []ResultDTO      `json:"results"`
	Signature       string           `json:"signature"`
}

// Game represents a poker game
type Game struct {
	GameId     string    `json:"gameId"`
	Creator    string    `json:"creator"`
	MinBuyIn   uint64    `json:"minBuyIn"`
	MaxBuyIn   uint64    `json:"maxBuyIn"`
	MinPlayers int64     `json:"minPlayers"`
	MaxPlayers int64     `json:"maxPlayers"`
	SmallBlind uint64    `json:"smallBlind"`
	BigBlind   uint64    `json:"bigBlind"`
	Timeout    int64     `json:"timeout"`
	GameType   string    `json:"gameType"`
	Players    []string  `json:"players"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
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
