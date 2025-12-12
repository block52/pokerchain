package equity

import (
	"fmt"
	"testing"
	"time"

	"github.com/block52/pokerchain/x/poker/types"
)

// =============================================================================
// Hand Evaluator Tests
// =============================================================================

func TestEvaluateHand_HighCard(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"2H", "5D", "8C", "JS", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != HighCard {
		t.Errorf("expected HighCard, got %v", result.Rank)
	}
}

func TestEvaluateHand_OnePair(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "5D", "8C", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != OnePair {
		t.Errorf("expected OnePair, got %v", result.Rank)
	}
}

func TestEvaluateHand_TwoPair(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "KD", "KC", "5H"})
	result := EvaluateHand(cards)

	if result.Rank != TwoPair {
		t.Errorf("expected TwoPair, got %v", result.Rank)
	}
}

func TestEvaluateHand_ThreeOfAKind(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "AD", "8C", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != ThreeOfAKind {
		t.Errorf("expected ThreeOfAKind, got %v", result.Rank)
	}
}

func TestEvaluateHand_Straight(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"5H", "6D", "7C", "8S", "9H"})
	result := EvaluateHand(cards)

	if result.Rank != Straight {
		t.Errorf("expected Straight, got %v", result.Rank)
	}
}

func TestEvaluateHand_Wheel(t *testing.T) {
	// A-2-3-4-5 wheel straight
	cards, _ := CardsFromMnemonics([]string{"AH", "2D", "3C", "4S", "5H"})
	result := EvaluateHand(cards)

	if result.Rank != Straight {
		t.Errorf("expected Straight (wheel), got %v", result.Rank)
	}
}

func TestEvaluateHand_Flush(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"2H", "5H", "8H", "JH", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != Flush {
		t.Errorf("expected Flush, got %v", result.Rank)
	}
}

func TestEvaluateHand_FullHouse(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "AD", "KC", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != FullHouse {
		t.Errorf("expected FullHouse, got %v", result.Rank)
	}
}

func TestEvaluateHand_FourOfAKind(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "AD", "AC", "KH"})
	result := EvaluateHand(cards)

	if result.Rank != FourOfAKind {
		t.Errorf("expected FourOfAKind, got %v", result.Rank)
	}
}

func TestEvaluateHand_StraightFlush(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"5H", "6H", "7H", "8H", "9H"})
	result := EvaluateHand(cards)

	if result.Rank != StraightFlush {
		t.Errorf("expected StraightFlush, got %v", result.Rank)
	}
}

func TestEvaluateHand_RoyalFlush(t *testing.T) {
	cards, _ := CardsFromMnemonics([]string{"TH", "JH", "QH", "KH", "AH"})
	result := EvaluateHand(cards)

	if result.Rank != StraightFlush {
		t.Errorf("expected StraightFlush (royal), got %v", result.Rank)
	}
}

func TestEvaluateHand_7Cards(t *testing.T) {
	// 7 cards with a full house hidden
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "AD", "KC", "KH", "2D", "3C"})
	result := EvaluateHand(cards)

	if result.Rank != FullHouse {
		t.Errorf("expected FullHouse from 7 cards, got %v", result.Rank)
	}
}

func TestCompareHands(t *testing.T) {
	tests := []struct {
		name     string
		hand1    []string
		hand2    []string
		expected int // 1 = hand1 wins, -1 = hand2 wins, 0 = tie
	}{
		{
			name:     "pair beats high card",
			hand1:    []string{"AS", "AH", "5D", "8C", "KH"},
			hand2:    []string{"2H", "5D", "8C", "JS", "KH"},
			expected: 1,
		},
		{
			name:     "higher pair wins",
			hand1:    []string{"AS", "AH", "5D", "8C", "KH"},
			hand2:    []string{"KS", "KD", "5H", "8S", "JH"},
			expected: 1,
		},
		{
			name:     "same pair kicker decides",
			hand1:    []string{"AS", "AH", "KD", "8C", "5H"},
			hand2:    []string{"AD", "AC", "QS", "8S", "5D"},
			expected: 1,
		},
		{
			name:     "flush beats straight",
			hand1:    []string{"2H", "5H", "8H", "JH", "KH"},
			hand2:    []string{"5D", "6C", "7S", "8H", "9D"},
			expected: 1,
		},
		{
			name:     "identical hands tie",
			hand1:    []string{"AS", "KS", "QS", "JS", "9S"},
			hand2:    []string{"AH", "KH", "QH", "JH", "9H"},
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cards1, _ := CardsFromMnemonics(tt.hand1)
			cards2, _ := CardsFromMnemonics(tt.hand2)

			result1 := EvaluateHand(cards1)
			result2 := EvaluateHand(cards2)

			cmp := CompareHands(result1, result2)
			if cmp != tt.expected {
				t.Errorf("expected %d, got %d (hand1: %v=%d, hand2: %v=%d)",
					tt.expected, cmp, result1.Rank, result1.Score, result2.Rank, result2.Score)
			}
		})
	}
}

// =============================================================================
// Equity Calculator Tests
// =============================================================================

func TestPreflopEquity_AAvsKK(t *testing.T) {
	hands := [][]string{
		{"AS", "AH"}, // AA
		{"KS", "KH"}, // KK
	}

	result, err := PreflopEquity(hands, WithSimulations(10000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// AA vs KK should be approximately 82% vs 18%
	aaEquity := result.Results[0].Total
	kkEquity := result.Results[1].Total

	if aaEquity < 0.75 || aaEquity > 0.88 {
		t.Errorf("AA equity %.2f%% outside expected range (75-88%%)", aaEquity*100)
	}
	if kkEquity < 0.12 || kkEquity > 0.25 {
		t.Errorf("KK equity %.2f%% outside expected range (12-25%%)", kkEquity*100)
	}

	t.Logf("AA vs KK: %.2f%% vs %.2f%% (%d simulations)",
		aaEquity*100, kkEquity*100, result.Simulations)
}

func TestPreflopEquity_CoinFlip(t *testing.T) {
	hands := [][]string{
		{"AS", "KS"}, // AKs
		{"QH", "QD"}, // QQ
	}

	result, err := PreflopEquity(hands, WithSimulations(10000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// AKs vs QQ should be approximately 46% vs 54%
	aksEquity := result.Results[0].Total
	qqEquity := result.Results[1].Total

	if aksEquity < 0.40 || aksEquity > 0.52 {
		t.Errorf("AKs equity %.2f%% outside expected range (40-52%%)", aksEquity*100)
	}
	if qqEquity < 0.48 || qqEquity > 0.60 {
		t.Errorf("QQ equity %.2f%% outside expected range (48-60%%)", qqEquity*100)
	}

	t.Logf("AKs vs QQ: %.2f%% vs %.2f%% (%d simulations)",
		aksEquity*100, qqEquity*100, result.Simulations)
}

func TestFlopEquity(t *testing.T) {
	hands := [][]string{
		{"AS", "KS"}, // AK
		{"QH", "QD"}, // QQ
	}
	flop := []string{"KH", "7C", "2D"} // K high flop - AK has top pair

	result, err := FlopEquity(hands, flop, WithSimulations(10000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// AK flopped top pair, should be ahead
	akEquity := result.Results[0].Total
	qqEquity := result.Results[1].Total

	if akEquity < 0.60 {
		t.Errorf("AK equity %.2f%% should be > 60%% with top pair", akEquity*100)
	}

	t.Logf("AK vs QQ on %v: %.2f%% vs %.2f%%",
		flop, akEquity*100, qqEquity*100)
}

func TestTurnEquity(t *testing.T) {
	hands := [][]string{
		{"AS", "KS"}, // AK with flush draw
		{"QH", "QD"}, // QQ
	}
	board := []string{"2S", "7S", "QC", "3H"} // QQ has set, AK has flush draw

	result, err := TurnEquity(hands, board, WithSimulations(10000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// QQ has a set, but AK has flush draw (about 9 outs)
	akEquity := result.Results[0].Total
	qqEquity := result.Results[1].Total

	t.Logf("AK (flush draw) vs QQ (set) on %v: %.2f%% vs %.2f%%",
		board, akEquity*100, qqEquity*100)

	// QQ should be well ahead with a set
	if qqEquity < 0.70 {
		t.Errorf("QQ equity %.2f%% should be > 70%% with a set", qqEquity*100)
	}
}

func TestRiverEquity(t *testing.T) {
	hands := [][]string{
		{"AS", "KS"}, // AK made flush
		{"QH", "QD"}, // QQ has set
	}
	board := []string{"2S", "7S", "QC", "3H", "9S"} // Spade river - AK makes flush

	result, err := RiverEquity(hands, board)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// AK made a flush, QQ only has a set
	akEquity := result.Results[0].Total
	qqEquity := result.Results[1].Total

	if akEquity != 1.0 {
		t.Errorf("AK with flush should have 100%% equity, got %.2f%%", akEquity*100)
	}
	if qqEquity != 0.0 {
		t.Errorf("QQ with set should have 0%% equity vs flush, got %.2f%%", qqEquity*100)
	}

	t.Logf("AK (flush) vs QQ (set) on river: %.2f%% vs %.2f%%",
		akEquity*100, qqEquity*100)
}

func TestMultipleHands(t *testing.T) {
	hands := [][]string{
		{"AS", "AH"}, // AA
		{"KS", "KH"}, // KK
		{"QS", "QH"}, // QQ
		{"JC", "TC"}, // JTs
	}

	result, err := PreflopEquity(hands, WithSimulations(10000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify all equities sum to approximately 1.0
	totalEquity := 0.0
	for _, r := range result.Results {
		totalEquity += r.Total
	}

	if totalEquity < 0.98 || totalEquity > 1.02 {
		t.Errorf("total equity %.4f should be ~1.0", totalEquity)
	}

	t.Logf("4-way: AA=%.2f%%, KK=%.2f%%, QQ=%.2f%%, JTs=%.2f%%",
		result.Results[0].Total*100,
		result.Results[1].Total*100,
		result.Results[2].Total*100,
		result.Results[3].Total*100)
}

func TestMaxHands(t *testing.T) {
	// Test with 9 hands (maximum)
	hands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
		{"QS", "QH"},
		{"JS", "JH"},
		{"TS", "TH"},
		{"9S", "9H"},
		{"8S", "8H"},
		{"7C", "7D"},
		{"6C", "6D"},
	}

	result, err := PreflopEquity(hands, WithSimulations(5000), WithSeed(42))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify equities sum to approximately 1.0
	totalEquity := 0.0
	for _, r := range result.Results {
		totalEquity += r.Total
	}

	if totalEquity < 0.98 || totalEquity > 1.02 {
		t.Errorf("total equity %.4f should be ~1.0", totalEquity)
	}

	t.Logf("9-way pot: AA=%.2f%%, other hands have %.2f%% combined",
		result.Results[0].Total*100, (totalEquity-result.Results[0].Total)*100)
}

func TestDuplicateCardError(t *testing.T) {
	hands := [][]string{
		{"AS", "AH"},
		{"AS", "KH"}, // Duplicate AS
	}

	_, err := PreflopEquity(hands)
	if err == nil {
		t.Error("expected error for duplicate cards")
	}
}

func TestInvalidHandSize(t *testing.T) {
	hands := [][]string{
		{"AS", "AH", "KH"}, // 3 cards - invalid
		{"KS", "KH"},
	}

	_, err := PreflopEquity(hands)
	if err == nil {
		t.Error("expected error for invalid hand size")
	}
}

// =============================================================================
// Speed Diagnostics / Benchmarks
// =============================================================================

func BenchmarkEvaluateHand5Cards(b *testing.B) {
	cards, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "TS"})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		EvaluateHand(cards)
	}
}

func BenchmarkEvaluateHand7Cards(b *testing.B) {
	cards, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "TS", "2H", "3D"})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		EvaluateHand(cards)
	}
}

func BenchmarkEvaluateHandFast7Cards(b *testing.B) {
	cards, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "TS", "2H", "3D"})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		EvaluateHandFast(cards)
	}
}

func BenchmarkEvaluateHandFast7Cards_Flush(b *testing.B) {
	cards, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "9S", "2H", "3D"})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		EvaluateHandFast(cards)
	}
}

func BenchmarkEvaluateHandFast7Cards_FullHouse(b *testing.B) {
	cards, _ := CardsFromMnemonics([]string{"AS", "AH", "AD", "KS", "KH", "2C", "3D"})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		EvaluateHandFast(cards)
	}
}

func BenchmarkPreflopEquity2Hands(b *testing.B) {
	hands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		PreflopEquity(hands, WithSimulations(1000))
	}
}

func BenchmarkPreflopEquity9Hands(b *testing.B) {
	hands := [][]string{
		{"AS", "AH"}, {"KS", "KH"}, {"QS", "QH"},
		{"JS", "JH"}, {"TS", "TH"}, {"9S", "9H"},
		{"8S", "8H"}, {"7C", "7D"}, {"6C", "6D"},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		PreflopEquity(hands, WithSimulations(1000))
	}
}

func BenchmarkFlopEquity(b *testing.B) {
	hands := [][]string{
		{"AS", "AH"},
		{"KS", "KH"},
	}
	flop := []string{"2D", "7C", "JH"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FlopEquity(hands, flop, WithSimulations(1000))
	}
}

// TestSpeedDiagnostics runs comprehensive speed tests and prints results
func TestSpeedDiagnostics(t *testing.T) {
	fmt.Println("")
	fmt.Println("=== EQUITY CALCULATOR SPEED DIAGNOSTICS ===")

	// Test hand evaluator speed
	fmt.Println("Hand Evaluator Performance:")
	fmt.Println("----------------------------")

	cards5, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "TS"})
	cards7, _ := CardsFromMnemonics([]string{"AS", "KS", "QS", "JS", "TS", "2H", "3D"})

	iterations := 100000

	start := time.Now()
	for i := 0; i < iterations; i++ {
		EvaluateHand(cards5)
	}
	duration := time.Since(start)
	fmt.Printf("  5-card evaluation: %d evals in %v (%.0f evals/sec)\n",
		iterations, duration, float64(iterations)/duration.Seconds())

	start = time.Now()
	for i := 0; i < iterations; i++ {
		EvaluateHand(cards7)
	}
	duration = time.Since(start)
	fmt.Printf("  7-card evaluation: %d evals in %v (%.0f evals/sec)\n",
		iterations, duration, float64(iterations)/duration.Seconds())

	// Test equity calculation speed at different stages
	fmt.Println("\nEquity Calculation Performance:")
	fmt.Println("-------------------------------")

	hands2 := [][]string{{"AS", "AH"}, {"KS", "KH"}}
	hands4 := [][]string{{"AS", "AH"}, {"KS", "KH"}, {"QS", "QH"}, {"JS", "JH"}}
	hands9 := [][]string{
		{"AS", "AH"}, {"KS", "KH"}, {"QS", "QH"},
		{"JS", "JH"}, {"TS", "TH"}, {"9S", "9H"},
		{"8S", "8H"}, {"7C", "7D"}, {"6C", "6D"},
	}

	simCounts := []int{1000, 10000, 50000}

	for _, sims := range simCounts {
		fmt.Printf("\n  Simulations: %d\n", sims)

		// 2-way preflop
		start = time.Now()
		result, _ := PreflopEquity(hands2, WithSimulations(sims))
		fmt.Printf("    2-way Preflop: %v (%.0f hands/sec)\n",
			result.Duration, result.HandsPerSec)

		// 4-way preflop
		start = time.Now()
		result, _ = PreflopEquity(hands4, WithSimulations(sims))
		fmt.Printf("    4-way Preflop: %v (%.0f hands/sec)\n",
			result.Duration, result.HandsPerSec)

		// 9-way preflop
		start = time.Now()
		result, _ = PreflopEquity(hands9, WithSimulations(sims))
		fmt.Printf("    9-way Preflop: %v (%.0f hands/sec)\n",
			result.Duration, result.HandsPerSec)

		// Flop
		flop := []string{"2D", "7C", "JH"}
		result, _ = FlopEquity(hands2, flop, WithSimulations(sims))
		fmt.Printf("    2-way Flop:    %v (%.0f hands/sec)\n",
			result.Duration, result.HandsPerSec)

		// Turn
		turn := []string{"2D", "7C", "JH", "4S"}
		result, _ = TurnEquity(hands2, turn, WithSimulations(sims))
		fmt.Printf("    2-way Turn:    %v (%.0f hands/sec)\n",
			result.Duration, result.HandsPerSec)
	}

	// Memory-efficient test
	fmt.Println("\nParallel Worker Scaling:")
	fmt.Println("-------------------------")

	workerCounts := []int{1, 2, 4, 8}
	for _, workers := range workerCounts {
		result, _ := PreflopEquity(hands2, WithSimulations(50000), WithWorkers(workers))
		fmt.Printf("  %d workers: %v (%.0f hands/sec)\n",
			workers, result.Duration, result.HandsPerSec)
	}

	fmt.Println("")
	fmt.Println("=== END SPEED DIAGNOSTICS ===")
	fmt.Println("")
}

// TestAccuracyVsKnownEquities tests against known preflop equities
func TestAccuracyVsKnownEquities(t *testing.T) {
	tests := []struct {
		name           string
		hand1          []string
		hand2          []string
		expectedEquity float64 // hand1's expected equity
		tolerance      float64
	}{
		{
			name:           "AA vs KK",
			hand1:          []string{"AS", "AH"},
			hand2:          []string{"KS", "KH"},
			expectedEquity: 0.82,
			tolerance:      0.03,
		},
		{
			name:           "AA vs 72o",
			hand1:          []string{"AS", "AH"},
			hand2:          []string{"7D", "2C"},
			expectedEquity: 0.88,
			tolerance:      0.03,
		},
		{
			name:           "AKs vs QQ (coinflip)",
			hand1:          []string{"AS", "KS"},
			hand2:          []string{"QH", "QD"},
			expectedEquity: 0.46,
			tolerance:      0.03,
		},
		{
			name:           "KK vs AKo (dominated)",
			hand1:          []string{"KS", "KH"},
			hand2:          []string{"AD", "KC"},
			expectedEquity: 0.70,
			tolerance:      0.03,
		},
		{
			name:           "22 vs AKo (small pair vs overcards)",
			hand1:          []string{"2S", "2H"},
			hand2:          []string{"AD", "KC"},
			expectedEquity: 0.52,
			tolerance:      0.03,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hands := [][]string{tt.hand1, tt.hand2}
			result, err := PreflopEquity(hands, WithSimulations(50000), WithSeed(42))
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			actualEquity := result.Results[0].Total
			diff := actualEquity - tt.expectedEquity
			if diff < 0 {
				diff = -diff
			}

			if diff > tt.tolerance {
				t.Errorf("%s: expected %.2f%%, got %.2f%% (diff: %.2f%%)",
					tt.name, tt.expectedEquity*100, actualEquity*100, diff*100)
			}

			t.Logf("%s: %.2f%% vs %.2f%% (expected ~%.0f%%)",
				tt.name, actualEquity*100, result.Results[1].Total*100, tt.expectedEquity*100)
		})
	}
}

// =============================================================================
// Fast Evaluator Tests
// =============================================================================

func TestFastEvaluator_AllHandTypes(t *testing.T) {
	tests := []struct {
		name     string
		cards    []string
		category uint8
	}{
		{"High Card", []string{"2H", "5D", "8C", "JS", "KH", "3C", "7D"}, 0},
		{"One Pair", []string{"AS", "AH", "5D", "8C", "KH", "2D", "3C"}, 1},
		{"Two Pair", []string{"AS", "AH", "KD", "KC", "5H", "2D", "3C"}, 2},
		{"Three of a Kind", []string{"AS", "AH", "AD", "8C", "KH", "2D", "3C"}, 3},
		{"Straight", []string{"5H", "6D", "7C", "8S", "9H", "2D", "3C"}, 4},
		{"Flush", []string{"2H", "5H", "8H", "JH", "KH", "3D", "4C"}, 5},
		{"Full House", []string{"AS", "AH", "AD", "KC", "KH", "2D", "3C"}, 6},
		{"Four of a Kind", []string{"AS", "AH", "AD", "AC", "KH", "2D", "3C"}, 7},
		{"Straight Flush", []string{"5H", "6H", "7H", "8H", "9H", "2D", "3C"}, 8},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cards, _ := CardsFromMnemonics(tt.cards)
			result := EvaluateHandFast(cards)

			if result.Category != tt.category {
				t.Errorf("expected category %d (%s), got %d", tt.category, tt.name, result.Category)
			}
		})
	}
}

func TestFastEvaluator_CompareToOriginal(t *testing.T) {
	// Test many random hands to ensure fast evaluator agrees with original
	testHands := [][]string{
		{"AS", "KS", "QS", "JS", "TS", "2H", "3D"}, // Royal flush
		{"5H", "6H", "7H", "8H", "9H", "2D", "3C"}, // Straight flush
		{"AS", "AH", "AD", "AC", "KH", "2D", "3C"}, // Quads
		{"AS", "AH", "AD", "KC", "KH", "2D", "3C"}, // Full house
		{"2H", "5H", "8H", "JH", "KH", "3D", "4C"}, // Flush
		{"5H", "6D", "7C", "8S", "9H", "2D", "3C"}, // Straight
		{"AH", "2D", "3C", "4S", "5H", "KD", "QC"}, // Wheel
		{"AS", "AH", "AD", "8C", "KH", "2D", "3C"}, // Trips
		{"AS", "AH", "KD", "KC", "5H", "2D", "3C"}, // Two pair
		{"AS", "AH", "5D", "8C", "KH", "2D", "3C"}, // Pair
		{"2H", "5D", "8C", "JS", "KH", "3C", "7D"}, // High card
	}

	for _, hand := range testHands {
		cards, _ := CardsFromMnemonics(hand)

		origResult := EvaluateHand(cards)
		fastResult := EvaluateHandFast(cards)

		// Categories should match (with mapping)
		categoryMap := map[HandRank]uint8{
			HighCard:      0,
			OnePair:       1,
			TwoPair:       2,
			ThreeOfAKind:  3,
			Straight:      4,
			Flush:         5,
			FullHouse:     6,
			FourOfAKind:   7,
			StraightFlush: 8,
		}

		expectedCat := categoryMap[origResult.Rank]
		if fastResult.Category != expectedCat {
			t.Errorf("hand %v: original=%v (cat %d), fast cat=%d",
				hand, origResult.Rank, expectedCat, fastResult.Category)
		}
	}
}

func TestFastEvaluator_Ordering(t *testing.T) {
	// Verify hand ordering is correct
	hands := [][]string{
		{"2H", "5D", "8C", "JS", "KH", "3C", "7D"}, // High card
		{"AS", "AH", "5D", "8C", "KH", "2D", "3C"}, // Pair
		{"AS", "AH", "KD", "KC", "5H", "2D", "3C"}, // Two pair
		{"AS", "AH", "AD", "8C", "KH", "2D", "3C"}, // Trips
		{"5H", "6D", "7C", "8S", "9H", "2D", "3C"}, // Straight
		{"2H", "5H", "8H", "JH", "KH", "3D", "4C"}, // Flush
		{"AS", "AH", "AD", "KC", "KH", "2D", "3C"}, // Full house
		{"AS", "AH", "AD", "AC", "KH", "2D", "3C"}, // Quads
		{"5H", "6H", "7H", "8H", "9H", "2D", "3C"}, // Straight flush
	}

	var lastScore uint32
	for i, hand := range hands {
		cards, _ := CardsFromMnemonics(hand)
		result := EvaluateHandFast(cards)

		if result.Score <= lastScore && i > 0 {
			t.Errorf("hand %d (%v) score %d should be > hand %d score %d",
				i, hand, result.Score, i-1, lastScore)
		}
		lastScore = result.Score
	}
}

// =============================================================================
// Card Parsing Tests
// =============================================================================

func TestCardsFromMnemonics(t *testing.T) {
	mnemonics := []string{"AS", "KH", "QD", "JC", "TH"}
	cards, err := CardsFromMnemonics(mnemonics)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected := []struct {
		rank int
		suit types.Suit
	}{
		{1, types.SuitSpades},
		{13, types.SuitHearts},
		{12, types.SuitDiamonds},
		{11, types.SuitClubs},
		{10, types.SuitHearts},
	}

	for i, exp := range expected {
		if cards[i].Rank != exp.rank || cards[i].Suit != exp.suit {
			t.Errorf("card %d: expected rank=%d suit=%d, got rank=%d suit=%d",
				i, exp.rank, exp.suit, cards[i].Rank, cards[i].Suit)
		}
	}
}

func TestCardsFromMnemonics_InvalidCard(t *testing.T) {
	mnemonics := []string{"AS", "XX"} // XX is invalid
	_, err := CardsFromMnemonics(mnemonics)
	if err == nil {
		t.Error("expected error for invalid card mnemonic")
	}
}
