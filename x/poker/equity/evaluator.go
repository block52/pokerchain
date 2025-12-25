package equity

import (
	"fmt"
	"sort"

	"github.com/block52/pokerchain/x/poker/types"
)

// HandRank represents the ranking of a poker hand
type HandRank int

const (
	HighCard HandRank = iota
	OnePair
	TwoPair
	ThreeOfAKind
	Straight
	Flush
	FullHouse
	FourOfAKind
	StraightFlush
)

// HandResult represents the evaluated result of a hand
type HandResult struct {
	Rank      HandRank
	Score     uint32 // Higher is better, allows direct comparison
	BestCards []types.Card
}

// String returns the string representation of the hand rank
func (r HandRank) String() string {
	names := []string{
		"High Card",
		"One Pair",
		"Two Pair",
		"Three of a Kind",
		"Straight",
		"Flush",
		"Full House",
		"Four of a Kind",
		"Straight Flush",
	}
	if int(r) < len(names) {
		return names[r]
	}
	return "Unknown"
}

// EvaluateHand evaluates 5-7 cards and returns the best 5-card hand
func EvaluateHand(cards []types.Card) HandResult {
	if len(cards) < 5 {
		return HandResult{Rank: HighCard, Score: 0}
	}

	if len(cards) == 5 {
		return evaluate5Cards(cards)
	}

	// For 6-7 cards, find the best 5-card combination
	var best HandResult
	combinations := generateCombinations(len(cards), 5)

	for _, combo := range combinations {
		hand := make([]types.Card, 5)
		for i, idx := range combo {
			hand[i] = cards[idx]
		}
		result := evaluate5Cards(hand)
		if result.Score > best.Score {
			best = result
		}
	}

	return best
}

// evaluate5Cards evaluates exactly 5 cards
func evaluate5Cards(cards []types.Card) HandResult {
	// Sort cards by rank (Ace high = 14 for comparison)
	sorted := make([]types.Card, len(cards))
	copy(sorted, cards)
	sort.Slice(sorted, func(i, j int) bool {
		ri := aceHighRank(sorted[i].Rank)
		rj := aceHighRank(sorted[j].Rank)
		return ri > rj
	})

	isFlush := checkFlush(sorted)
	isStraight, straightHigh := checkStraight(sorted)

	// Count ranks
	rankCounts := make(map[int]int)
	for _, c := range sorted {
		rankCounts[c.Rank]++
	}

	// Get counts sorted by frequency then rank
	type rankCount struct {
		rank  int
		count int
	}
	counts := make([]rankCount, 0, len(rankCounts))
	for r, c := range rankCounts {
		counts = append(counts, rankCount{r, c})
	}
	sort.Slice(counts, func(i, j int) bool {
		if counts[i].count != counts[j].count {
			return counts[i].count > counts[j].count
		}
		return aceHighRank(counts[i].rank) > aceHighRank(counts[j].rank)
	})

	// Determine hand rank and score
	var result HandResult
	result.BestCards = sorted

	if isStraight && isFlush {
		result.Rank = StraightFlush
		result.Score = makeScore(StraightFlush, straightHigh, 0, 0, 0, 0)
	} else if counts[0].count == 4 {
		result.Rank = FourOfAKind
		kicker := aceHighRank(counts[1].rank)
		result.Score = makeScore(FourOfAKind, aceHighRank(counts[0].rank), kicker, 0, 0, 0)
	} else if counts[0].count == 3 && counts[1].count == 2 {
		result.Rank = FullHouse
		result.Score = makeScore(FullHouse, aceHighRank(counts[0].rank), aceHighRank(counts[1].rank), 0, 0, 0)
	} else if isFlush {
		result.Rank = Flush
		kickers := getKickers(sorted, nil, 5)
		result.Score = makeScore(Flush, kickers[0], kickers[1], kickers[2], kickers[3], kickers[4])
	} else if isStraight {
		result.Rank = Straight
		result.Score = makeScore(Straight, straightHigh, 0, 0, 0, 0)
	} else if counts[0].count == 3 {
		result.Rank = ThreeOfAKind
		kickers := getKickers(sorted, map[int]bool{counts[0].rank: true}, 2)
		result.Score = makeScore(ThreeOfAKind, aceHighRank(counts[0].rank), kickers[0], kickers[1], 0, 0)
	} else if counts[0].count == 2 && counts[1].count == 2 {
		result.Rank = TwoPair
		highPair := aceHighRank(counts[0].rank)
		lowPair := aceHighRank(counts[1].rank)
		if lowPair > highPair {
			highPair, lowPair = lowPair, highPair
		}
		kicker := getKickers(sorted, map[int]bool{counts[0].rank: true, counts[1].rank: true}, 1)
		result.Score = makeScore(TwoPair, highPair, lowPair, kicker[0], 0, 0)
	} else if counts[0].count == 2 {
		result.Rank = OnePair
		kickers := getKickers(sorted, map[int]bool{counts[0].rank: true}, 3)
		result.Score = makeScore(OnePair, aceHighRank(counts[0].rank), kickers[0], kickers[1], kickers[2], 0)
	} else {
		result.Rank = HighCard
		kickers := getKickers(sorted, nil, 5)
		result.Score = makeScore(HighCard, kickers[0], kickers[1], kickers[2], kickers[3], kickers[4])
	}

	return result
}

// aceHighRank converts rank to ace-high value (Ace = 14)
func aceHighRank(rank int) int {
	if rank == 1 {
		return 14
	}
	return rank
}

// checkFlush checks if all cards are the same suit
func checkFlush(cards []types.Card) bool {
	suit := cards[0].Suit
	for _, c := range cards[1:] {
		if c.Suit != suit {
			return false
		}
	}
	return true
}

// checkStraight checks for a straight, returns (isStraight, highCard)
func checkStraight(cards []types.Card) (bool, int) {
	// Get unique ranks as ace-high values
	ranks := make([]int, len(cards))
	for i, c := range cards {
		ranks[i] = aceHighRank(c.Rank)
	}
	sort.Slice(ranks, func(i, j int) bool { return ranks[i] > ranks[j] })

	// Check for regular straight
	isSequential := true
	for i := 0; i < len(ranks)-1; i++ {
		if ranks[i]-ranks[i+1] != 1 {
			isSequential = false
			break
		}
	}
	if isSequential {
		return true, ranks[0]
	}

	// Check for wheel (A-2-3-4-5)
	hasAce := false
	for _, c := range cards {
		if c.Rank == 1 {
			hasAce = true
			break
		}
	}
	if hasAce {
		lowRanks := make([]int, len(cards))
		for i, c := range cards {
			if c.Rank == 1 {
				lowRanks[i] = 1 // Ace low
			} else {
				lowRanks[i] = c.Rank
			}
		}
		sort.Slice(lowRanks, func(i, j int) bool { return lowRanks[i] > lowRanks[j] })

		isWheel := true
		for i := 0; i < len(lowRanks)-1; i++ {
			if lowRanks[i]-lowRanks[i+1] != 1 {
				isWheel = false
				break
			}
		}
		if isWheel && lowRanks[0] == 5 {
			return true, 5 // 5-high straight (wheel)
		}
	}

	return false, 0
}

// getKickers returns the top N kickers excluding specified ranks
func getKickers(cards []types.Card, exclude map[int]bool, n int) []int {
	kickers := make([]int, 0, n)
	for _, c := range cards {
		if exclude != nil && exclude[c.Rank] {
			continue
		}
		kickers = append(kickers, aceHighRank(c.Rank))
		if len(kickers) == n {
			break
		}
	}
	// Pad with zeros if needed
	for len(kickers) < n {
		kickers = append(kickers, 0)
	}
	return kickers
}

// makeScore creates a comparable score from hand rank and kickers
// Score format: [HandRank(4 bits)][k1(4)][k2(4)][k3(4)][k4(4)][k5(4)] = 24 bits
func makeScore(rank HandRank, k1, k2, k3, k4, k5 int) uint32 {
	return uint32(rank)<<20 | uint32(k1)<<16 | uint32(k2)<<12 | uint32(k3)<<8 | uint32(k4)<<4 | uint32(k5)
}

// generateCombinations generates all combinations of n items taken r at a time
func generateCombinations(n, r int) [][]int {
	if r > n {
		return nil
	}

	result := make([][]int, 0)
	combo := make([]int, r)
	var generate func(start, idx int)
	generate = func(start, idx int) {
		if idx == r {
			c := make([]int, r)
			copy(c, combo)
			result = append(result, c)
			return
		}
		for i := start; i <= n-(r-idx); i++ {
			combo[idx] = i
			generate(i+1, idx+1)
		}
	}
	generate(0, 0)
	return result
}

// CompareHands compares two hand results, returns:
// 1 if hand1 wins, -1 if hand2 wins, 0 if tie
func CompareHands(hand1, hand2 HandResult) int {
	if hand1.Score > hand2.Score {
		return 1
	}
	if hand1.Score < hand2.Score {
		return -1
	}
	return 0
}

// CardsFromMnemonics parses a slice of mnemonic strings to Cards
func CardsFromMnemonics(mnemonics []string) ([]types.Card, error) {
	cards := make([]types.Card, len(mnemonics))
	for i, m := range mnemonics {
		card, err := types.CardFromString(m)
		if err != nil {
			return nil, fmt.Errorf("invalid card %q at position %d: %w", m, i, err)
		}
		cards[i] = card
	}
	return cards, nil
}
