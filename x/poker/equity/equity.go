// Package equity provides Monte Carlo simulation for calculating poker hand equity
// at different stages: preflop, flop, turn, and river.
package equity

import (
	"fmt"
	"math/rand"
	"sync"
	"time"

	"github.com/block52/pokerchain/x/poker/types"
)

// Stage represents the current stage of the hand
type Stage int

const (
	Preflop Stage = iota
	Flop
	Turn
	River
)

// String returns the string representation of the stage
func (s Stage) String() string {
	names := []string{"Preflop", "Flop", "Turn", "River"}
	if int(s) < len(names) {
		return names[s]
	}
	return "Unknown"
}

// EquityResult represents the equity calculation result for a single hand
type EquityResult struct {
	HandIndex int
	Wins      int
	Ties      int
	Losses    int
	Equity    float64 // Win probability (0.0 - 1.0)
	TieEquity float64 // Equity from ties
	Total     float64 // Total equity (wins + tie share)
}

// CalculationResult represents the complete result of an equity calculation
type CalculationResult struct {
	Results      []EquityResult
	Simulations  int
	Stage        Stage
	Duration     time.Duration
	BoardCards   []string
	DeadCards    []string
	HandsPerSec  float64
}

// Calculator performs equity calculations using Monte Carlo simulation
type Calculator struct {
	rng         *rand.Rand
	simulations int
	workers     int
}

// Option is a functional option for configuring the Calculator
type Option func(*Calculator)

// WithSimulations sets the number of Monte Carlo simulations
func WithSimulations(n int) Option {
	return func(c *Calculator) {
		c.simulations = n
	}
}

// WithWorkers sets the number of parallel workers
func WithWorkers(n int) Option {
	return func(c *Calculator) {
		c.workers = n
	}
}

// WithSeed sets the random seed for reproducible results
func WithSeed(seed int64) Option {
	return func(c *Calculator) {
		c.rng = rand.New(rand.NewSource(seed))
	}
}

// NewCalculator creates a new equity calculator with the given options
func NewCalculator(opts ...Option) *Calculator {
	c := &Calculator{
		rng:         rand.New(rand.NewSource(time.Now().UnixNano())),
		simulations: 10000,
		workers:     4,
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// CalculateEquity calculates the equity for multiple hands at a given stage
// hands: slice of hole cards for each player (e.g., [["AS", "KS"], ["QH", "QD"]])
// board: community cards (0 for preflop, 3 for flop, 4 for turn, 5 for river)
// dead: cards that are dead/mucked and cannot appear
func (c *Calculator) CalculateEquity(hands [][]string, board []string, dead []string) (*CalculationResult, error) {
	if len(hands) < 2 || len(hands) > 9 {
		return nil, fmt.Errorf("must have 2-9 hands, got %d", len(hands))
	}

	// Parse all hole cards
	holeCards := make([][]types.Card, len(hands))
	usedCards := make(map[int]bool)

	for i, hand := range hands {
		if len(hand) != 2 {
			return nil, fmt.Errorf("hand %d must have exactly 2 cards, got %d", i, len(hand))
		}
		cards, err := CardsFromMnemonics(hand)
		if err != nil {
			return nil, fmt.Errorf("hand %d: %w", i, err)
		}
		for _, card := range cards {
			if usedCards[card.Value] {
				return nil, fmt.Errorf("duplicate card: %s", card.Mnemonic)
			}
			usedCards[card.Value] = true
		}
		holeCards[i] = cards
	}

	// Parse board cards
	boardCards, err := CardsFromMnemonics(board)
	if err != nil {
		return nil, fmt.Errorf("board: %w", err)
	}
	for _, card := range boardCards {
		if usedCards[card.Value] {
			return nil, fmt.Errorf("duplicate card on board: %s", card.Mnemonic)
		}
		usedCards[card.Value] = true
	}

	// Parse dead cards
	deadCards, err := CardsFromMnemonics(dead)
	if err != nil {
		return nil, fmt.Errorf("dead cards: %w", err)
	}
	for _, card := range deadCards {
		if usedCards[card.Value] {
			return nil, fmt.Errorf("duplicate dead card: %s", card.Mnemonic)
		}
		usedCards[card.Value] = true
	}

	// Determine stage
	var stage Stage
	switch len(boardCards) {
	case 0:
		stage = Preflop
	case 3:
		stage = Flop
	case 4:
		stage = Turn
	case 5:
		stage = River
	default:
		return nil, fmt.Errorf("invalid board size: %d (must be 0, 3, 4, or 5)", len(boardCards))
	}

	// Build deck of remaining cards
	remainingDeck := buildRemainingDeck(usedCards)
	cardsNeeded := 5 - len(boardCards)

	start := time.Now()

	// Run simulations
	var results []EquityResult
	if cardsNeeded == 0 {
		// River - just evaluate once
		results = evaluateOnce(holeCards, boardCards)
	} else {
		results = c.runSimulations(holeCards, boardCards, remainingDeck, cardsNeeded)
	}

	duration := time.Since(start)
	handsPerSec := float64(c.simulations*len(hands)) / duration.Seconds()

	return &CalculationResult{
		Results:     results,
		Simulations: c.simulations,
		Stage:       stage,
		Duration:    duration,
		BoardCards:  board,
		DeadCards:   dead,
		HandsPerSec: handsPerSec,
	}, nil
}

// runSimulations runs Monte Carlo simulations using multiple workers
func (c *Calculator) runSimulations(holeCards [][]types.Card, board []types.Card, deck []types.Card, cardsNeeded int) []EquityResult {
	numHands := len(holeCards)

	// Per-worker results
	type workerResult struct {
		wins []int
		ties []int
	}

	simsPerWorker := c.simulations / c.workers
	remainder := c.simulations % c.workers

	var wg sync.WaitGroup
	workerResults := make([]workerResult, c.workers)

	for w := 0; w < c.workers; w++ {
		wg.Add(1)
		workerSims := simsPerWorker
		if w < remainder {
			workerSims++
		}

		go func(workerID, sims int) {
			defer wg.Done()

			// Each worker gets its own RNG
			rng := rand.New(rand.NewSource(time.Now().UnixNano() + int64(workerID*1000)))

			wins := make([]int, numHands)
			ties := make([]int, numHands)
			deckCopy := make([]types.Card, len(deck))
			scores := make([]uint32, numHands)

			// Pre-allocate combined cards slice (reused each iteration)
			combined := make([]types.Card, 7)
			fullBoard := make([]types.Card, 5)

			for i := 0; i < sims; i++ {
				// Copy and shuffle deck
				copy(deckCopy, deck)
				shuffleDeck(deckCopy, rng)

				// Complete the board
				copy(fullBoard[:len(board)], board)
				copy(fullBoard[len(board):], deckCopy[:cardsNeeded])

				// Evaluate all hands using fast evaluator
				for h := 0; h < numHands; h++ {
					combined[0] = holeCards[h][0]
					combined[1] = holeCards[h][1]
					combined[2] = fullBoard[0]
					combined[3] = fullBoard[1]
					combined[4] = fullBoard[2]
					combined[5] = fullBoard[3]
					combined[6] = fullBoard[4]
					result := EvaluateHandFast(combined)
					scores[h] = result.Score
				}

				// Find winners
				maxScore := scores[0]
				for _, s := range scores[1:] {
					if s > maxScore {
						maxScore = s
					}
				}

				winnerCount := 0
				for _, s := range scores {
					if s == maxScore {
						winnerCount++
					}
				}

				// Record results
				for h, s := range scores {
					if s == maxScore {
						if winnerCount > 1 {
							ties[h]++
						} else {
							wins[h]++
						}
					}
				}
			}

			workerResults[workerID] = workerResult{wins: wins, ties: ties}
		}(w, workerSims)
	}

	wg.Wait()

	// Aggregate results
	totalWins := make([]int, numHands)
	totalTies := make([]int, numHands)

	for _, wr := range workerResults {
		for h := 0; h < numHands; h++ {
			totalWins[h] += wr.wins[h]
			totalTies[h] += wr.ties[h]
		}
	}

	// Calculate equity
	results := make([]EquityResult, numHands)
	for h := 0; h < numHands; h++ {
		wins := totalWins[h]
		ties := totalTies[h]
		losses := c.simulations - wins - ties

		equity := float64(wins) / float64(c.simulations)
		tieEquity := float64(ties) / float64(c.simulations) / 2.0 // Ties split the pot
		total := equity + tieEquity

		results[h] = EquityResult{
			HandIndex: h,
			Wins:      wins,
			Ties:      ties,
			Losses:    losses,
			Equity:    equity,
			TieEquity: tieEquity,
			Total:     total,
		}
	}

	return results
}

// evaluateOnce evaluates hands at the river (no simulation needed)
func evaluateOnce(holeCards [][]types.Card, board []types.Card) []EquityResult {
	numHands := len(holeCards)
	scores := make([]uint32, numHands)
	combined := make([]types.Card, 7)

	for h := 0; h < numHands; h++ {
		combined[0] = holeCards[h][0]
		combined[1] = holeCards[h][1]
		copy(combined[2:], board)
		result := EvaluateHandFast(combined)
		scores[h] = result.Score
	}

	// Find winners
	maxScore := scores[0]
	for _, s := range scores[1:] {
		if s > maxScore {
			maxScore = s
		}
	}

	winnerCount := 0
	for _, s := range scores {
		if s == maxScore {
			winnerCount++
		}
	}

	results := make([]EquityResult, numHands)
	for h, s := range scores {
		if s == maxScore {
			if winnerCount > 1 {
				results[h] = EquityResult{
					HandIndex: h,
					Ties:      1,
					TieEquity: 1.0 / float64(winnerCount),
					Total:     1.0 / float64(winnerCount),
				}
			} else {
				results[h] = EquityResult{
					HandIndex: h,
					Wins:      1,
					Equity:    1.0,
					Total:     1.0,
				}
			}
		} else {
			results[h] = EquityResult{
				HandIndex: h,
				Losses:    1,
			}
		}
	}

	return results
}

// buildRemainingDeck builds a deck of cards not in the used set
func buildRemainingDeck(used map[int]bool) []types.Card {
	deck := make([]types.Card, 0, 52-len(used))
	for suit := types.SuitClubs; suit <= types.SuitSpades; suit++ {
		for rank := 1; rank <= 13; rank++ {
			value := 13*(int(suit)-1) + (rank - 1)
			if !used[value] {
				deck = append(deck, types.Card{
					Suit:     suit,
					Rank:     rank,
					Value:    value,
					Mnemonic: types.GetCardMnemonic(suit, rank),
				})
			}
		}
	}
	return deck
}

// shuffleDeck shuffles a deck using Fisher-Yates algorithm
func shuffleDeck(deck []types.Card, rng *rand.Rand) {
	for i := len(deck) - 1; i > 0; i-- {
		j := rng.Intn(i + 1)
		deck[i], deck[j] = deck[j], deck[i]
	}
}

// QuickEquity is a convenience function for quick equity calculation
func QuickEquity(hands [][]string, board []string) (*CalculationResult, error) {
	calc := NewCalculator()
	return calc.CalculateEquity(hands, board, nil)
}

// PreflopEquity calculates preflop equity for multiple hands
func PreflopEquity(hands [][]string, opts ...Option) (*CalculationResult, error) {
	calc := NewCalculator(opts...)
	return calc.CalculateEquity(hands, nil, nil)
}

// FlopEquity calculates equity on the flop
func FlopEquity(hands [][]string, flop []string, opts ...Option) (*CalculationResult, error) {
	if len(flop) != 3 {
		return nil, fmt.Errorf("flop must have exactly 3 cards, got %d", len(flop))
	}
	calc := NewCalculator(opts...)
	return calc.CalculateEquity(hands, flop, nil)
}

// TurnEquity calculates equity on the turn
func TurnEquity(hands [][]string, board []string, opts ...Option) (*CalculationResult, error) {
	if len(board) != 4 {
		return nil, fmt.Errorf("turn board must have exactly 4 cards, got %d", len(board))
	}
	calc := NewCalculator(opts...)
	return calc.CalculateEquity(hands, board, nil)
}

// RiverEquity calculates equity on the river (deterministic, no simulation)
func RiverEquity(hands [][]string, board []string) (*CalculationResult, error) {
	if len(board) != 5 {
		return nil, fmt.Errorf("river board must have exactly 5 cards, got %d", len(board))
	}
	calc := NewCalculator(WithSimulations(1))
	return calc.CalculateEquity(hands, board, nil)
}
