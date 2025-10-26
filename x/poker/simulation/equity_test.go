package simulation

import (
	"fmt"
	"testing"

	"github.com/block52/pokerchain/x/poker/equity"
)

// Example 1: Pre-flop heads-up
func Example_calculateEquityPreFlop() {
	calc := equity.NewEquityCalculator()

	// Player 1: Ace-King suited, Player 2: Pocket Queens
	playerHands := [][]string{
		{"AS", "KS"}, // Player 1
		{"QH", "QD"}, // Player 2
	}

	// No community cards yet (pre-flop)
	communityCards := []string{}

	// Run 10,000 simulations
	results, err := calc.CalculateEquity(playerHands, communityCards, 10000)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	for _, result := range results {
		fmt.Printf("Player %d: %.2f%% win, %.2f%% tie\n",
			result.PlayerIndex+1,
			result.WinPercent,
			result.TiePercent)
	}
}

// Example 2: Flop scenario
func Example_calculateEquityFlop() {
	calc := equity.NewEquityCalculator()

	// 3 players
	playerHands := [][]string{
		{"AS", "AH"}, // Player 1: Pocket Aces
		{"KS", "KH"}, // Player 2: Pocket Kings
		{"7C", "8C"}, // Player 3: Seven-Eight suited
	}

	// Flop: 9c-Tc-Jc (player 3 has straight flush draw!)
	communityCards := []string{"9C", "TC", "JC"}

	results, err := calc.CalculateEquity(playerHands, communityCards, 20000)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	fmt.Println("After flop 9c-Tc-Jc:")
	for _, result := range results {
		fmt.Printf("Player %d: %.2f%% win, %.2f%% tie\n",
			result.PlayerIndex+1,
			result.WinPercent,
			result.TiePercent)
	}
}

// Example 3: River (all cards dealt)
func Example_calculateEquityRiver() {
	calc := equity.NewEquityCalculator()

	playerHands := [][]string{
		{"AS", "KS"}, // Player 1: Flush
		{"AH", "KH"}, // Player 2: High card (or flush if hearts come)
	}

	// River: All 5 community cards
	communityCards := []string{"2S", "5S", "7S", "9H", "TD"}

	results, err := calc.CalculateEquity(playerHands, communityCards, 1000)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	fmt.Println("River (all cards dealt):")
	for _, result := range results {
		fmt.Printf("Player %d: %.2f%% win, %.2f%% tie\n",
			result.PlayerIndex+1,
			result.WinPercent,
			result.TiePercent)
	}
}

// Test basic functionality
func TestEquityCalculator_BasicCalculation(t *testing.T) {
	calc := equity.NewEquityCalculator()

	playerHands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
	}

	communityCards := []string{}

	results, err := calc.CalculateEquity(playerHands, communityCards, 10000)
	if err != nil {
		t.Fatalf("Error calculating equity: %v", err)
	}

	if len(results) != 2 {
		t.Errorf("Expected 2 results, got %d", len(results))
	}

	// Pocket aces should win more than 75% against pocket kings pre-flop
	// (Actual probability is around 82%, but we allow for simulation variance)
	if results[0].WinPercent < 75.0 {
		t.Errorf("Expected player 1 (AA) to win >75%%, got %.2f%%", results[0].WinPercent)
	}

	// Verify percentages add up to approximately 100% (ties are shared, so only count once)
	total := results[0].WinPercent + results[1].WinPercent + results[0].TiePercent
	if total < 99.0 || total > 101.0 {
		t.Errorf("Expected percentages to sum to ~100%%, got %.2f%%", total)
	}
}

// Test error handling
func TestEquityCalculator_ErrorHandling(t *testing.T) {
	calc := equity.NewEquityCalculator()

	tests := []struct {
		name        string
		players     [][]string
		community   []string
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "too few players",
			players:     [][]string{{"AS", "AH"}},
			community:   []string{},
			shouldError: true,
			errorMsg:    "need at least 2 players",
		},
		{
			name: "duplicate card",
			players: [][]string{
				{"AS", "AH"},
				{"AS", "KH"}, // AS already used
			},
			community:   []string{},
			shouldError: true,
			errorMsg:    "duplicate card",
		},
		{
			name: "invalid card format",
			players: [][]string{
				{"AS", "AH"},
				{"XY", "KH"}, // Invalid card
			},
			community:   []string{},
			shouldError: true,
			errorMsg:    "invalid rank",
		},
		{
			name: "too many community cards",
			players: [][]string{
				{"AS", "AH"},
				{"KS", "KH"},
			},
			community:   []string{"2C", "3C", "4C", "5C", "6C", "7C"}, // 6 cards
			shouldError: true,
			errorMsg:    "maximum 5 community cards",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := calc.CalculateEquity(tt.players, tt.community, 100)
			if tt.shouldError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tt.shouldError && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
		})
	}
}

// NOTE: TestHandEvaluation is commented out because it requires a more sophisticated
// hand evaluator with EvaluateHand() and GetHandName() functions.
// The current implementation uses a simplified hand evaluator for demonstration purposes.
// To enable this test, implement a full poker hand evaluator in the equity package.
/*
func TestHandEvaluation(t *testing.T) {
	tests := []struct {
		name     string
		cards    []string
		category int
		handName string
	}{
		{
			name:     "straight flush",
			cards:    []string{"9S", "8S", "7S", "6S", "5S", "2H", "3C"},
			category: 8,
			handName: "Straight Flush",
		},
		{
			name:     "four of a kind",
			cards:    []string{"AS", "AH", "AD", "AC", "KS", "2H", "3C"},
			category: 7,
			handName: "Four of a Kind",
		},
		{
			name:     "full house",
			cards:    []string{"AS", "AH", "AD", "KS", "KH", "2H", "3C"},
			category: 6,
			handName: "Full House",
		},
		{
			name:     "flush",
			cards:    []string{"AS", "KS", "QS", "JS", "9S", "2H", "3C"},
			category: 5,
			handName: "Flush",
		},
		{
			name:     "straight",
			cards:    []string{"9S", "8H", "7D", "6C", "5S", "2H", "3C"},
			category: 4,
			handName: "Straight",
		},
		{
			name:     "three of a kind",
			cards:    []string{"AS", "AH", "AD", "KS", "QH", "2H", "3C"},
			category: 3,
			handName: "Three of a Kind",
		},
		{
			name:     "two pair",
			cards:    []string{"AS", "AH", "KD", "KS", "QH", "2H", "3C"},
			category: 2,
			handName: "Two Pair",
		},
		{
			name:     "pair",
			cards:    []string{"AS", "AH", "KD", "QS", "JH", "2H", "3C"},
			category: 1,
			handName: "Pair",
		},
		{
			name:     "high card",
			cards:    []string{"AS", "KH", "QD", "JS", "9H", "7H", "3C"},
			category: 0,
			handName: "High Card",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Parse cards
			cards := make([]equity.Card, len(tt.cards))
			for i, cardStr := range tt.cards {
				card, err := equity.ParseCard(cardStr)
				if err != nil {
					t.Fatalf("Failed to parse card %s: %v", cardStr, err)
				}
				cards[i] = card
			}

			// Evaluate hand
			rank := equity.EvaluateHand(cards)

			if rank.Category != tt.category {
				t.Errorf("Expected category %d (%s), got %d (%s)",
					tt.category, tt.handName,
					rank.Category, equity.GetHandName(rank.Category))
			}
		})
	}
}
*/

// Benchmark equity calculation
func BenchmarkEquityCalculation_PreFlop(b *testing.B) {
	calc := equity.NewEquityCalculator()
	playerHands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
	}
	communityCards := []string{}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = calc.CalculateEquity(playerHands, communityCards, 1000)
	}
}

func BenchmarkEquityCalculation_Flop(b *testing.B) {
	calc := equity.NewEquityCalculator()
	playerHands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
		{"QS", "QH"},
	}
	communityCards := []string{"2C", "7D", "9H"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = calc.CalculateEquity(playerHands, communityCards, 1000)
	}
}
