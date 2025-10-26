package simulation

import "sort"

// Card represents a playing card with integer values for rank and suit
// This is used for internal hand evaluation in the simulation package
type Card struct {
	Rank int // 2-14 (2-10, Jack=11, Queen=12, King=13, Ace=14)
	Suit int // 0=Clubs, 1=Diamonds, 2=Hearts, 3=Spades
}

// HandRank represents the ranking of a poker hand
type HandRank struct {
	Category int    // 0=High Card, 1=Pair, 2=Two Pair, 3=Three of a Kind, 4=Straight, 5=Flush, 6=Full House, 7=Four of a Kind, 8=Straight Flush
	Values   [5]int // Tiebreaker values
}

// Compare compares two hand ranks
// Returns: 1 if hr > other, -1 if hr < other, 0 if equal
func (hr HandRank) Compare(other HandRank) int {
	if hr.Category > other.Category {
		return 1
	}
	if hr.Category < other.Category {
		return -1
	}

	// Same category, compare values
	for i := 0; i < 5; i++ {
		if hr.Values[i] > other.Values[i] {
			return 1
		}
		if hr.Values[i] < other.Values[i] {
			return -1
		}
	}

	return 0
}

// EvaluateHand evaluates a 7-card hand and returns the best 5-card ranking
func EvaluateHand(cards []Card) HandRank {
	if len(cards) != 7 {
		panic("EvaluateHand requires exactly 7 cards")
	}

	// Sort cards by rank (descending)
	sorted := make([]Card, len(cards))
	copy(sorted, cards)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Rank > sorted[j].Rank
	})

	// Check for flush
	flushSuit := findFlush(sorted)

	// Check for straight
	straightHigh := findStraight(sorted)

	// If both flush and straight exist
	if flushSuit != -1 && straightHigh != -1 {
		// Check for straight flush
		flushCards := filterBySuit(sorted, flushSuit)
		sfHigh := findStraight(flushCards)
		if sfHigh != -1 {
			// Straight flush (category 8)
			return HandRank{
				Category: 8,
				Values:   [5]int{sfHigh, 0, 0, 0, 0},
			}
		}
	}

	// Count ranks
	rankCounts := make(map[int]int)
	for _, card := range sorted {
		rankCounts[card.Rank]++
	}

	// Convert to sorted pairs
	type rankCount struct {
		rank  int
		count int
	}
	counts := make([]rankCount, 0, len(rankCounts))
	for rank, count := range rankCounts {
		counts = append(counts, rankCount{rank, count})
	}
	sort.Slice(counts, func(i, j int) bool {
		if counts[i].count != counts[j].count {
			return counts[i].count > counts[j].count
		}
		return counts[i].rank > counts[j].rank
	})

	// Check for four of a kind
	if len(counts) > 0 && counts[0].count == 4 {
		kicker := 0
		for _, rc := range counts {
			if rc.count != 4 {
				kicker = rc.rank
				break
			}
		}
		return HandRank{
			Category: 7,
			Values:   [5]int{counts[0].rank, kicker, 0, 0, 0},
		}
	}

	// Check for full house
	if len(counts) >= 2 && counts[0].count == 3 && counts[1].count >= 2 {
		return HandRank{
			Category: 6,
			Values:   [5]int{counts[0].rank, counts[1].rank, 0, 0, 0},
		}
	}

	// Check for flush
	if flushSuit != -1 {
		flushCards := filterBySuit(sorted, flushSuit)
		topFive := make([]int, 5)
		for i := 0; i < 5; i++ {
			topFive[i] = flushCards[i].Rank
		}
		return HandRank{
			Category: 5,
			Values:   [5]int{topFive[0], topFive[1], topFive[2], topFive[3], topFive[4]},
		}
	}

	// Check for straight
	if straightHigh != -1 {
		return HandRank{
			Category: 4,
			Values:   [5]int{straightHigh, 0, 0, 0, 0},
		}
	}

	// Check for three of a kind
	if len(counts) > 0 && counts[0].count == 3 {
		kickers := make([]int, 0, 2)
		for _, rc := range counts {
			if rc.count != 3 {
				kickers = append(kickers, rc.rank)
				if len(kickers) == 2 {
					break
				}
			}
		}
		return HandRank{
			Category: 3,
			Values:   [5]int{counts[0].rank, kickers[0], kickers[1], 0, 0},
		}
	}

	// Check for two pair
	if len(counts) >= 2 && counts[0].count == 2 && counts[1].count == 2 {
		kicker := 0
		for _, rc := range counts {
			if rc.count == 1 {
				kicker = rc.rank
				break
			}
		}
		return HandRank{
			Category: 2,
			Values:   [5]int{counts[0].rank, counts[1].rank, kicker, 0, 0},
		}
	}

	// Check for pair
	if len(counts) > 0 && counts[0].count == 2 {
		kickers := make([]int, 0, 3)
		for _, rc := range counts {
			if rc.count == 1 {
				kickers = append(kickers, rc.rank)
				if len(kickers) == 3 {
					break
				}
			}
		}
		return HandRank{
			Category: 1,
			Values:   [5]int{counts[0].rank, kickers[0], kickers[1], kickers[2], 0},
		}
	}

	// High card
	return HandRank{
		Category: 0,
		Values:   [5]int{sorted[0].Rank, sorted[1].Rank, sorted[2].Rank, sorted[3].Rank, sorted[4].Rank},
	}
}

// findFlush returns the suit of a flush (5+ cards of same suit), or -1 if none
func findFlush(cards []Card) int {
	suitCounts := make(map[int]int)
	for _, card := range cards {
		suitCounts[card.Suit]++
		if suitCounts[card.Suit] >= 5 {
			return card.Suit
		}
	}
	return -1
}

// findStraight returns the high card of a straight, or -1 if none
func findStraight(cards []Card) int {
	// Get unique ranks in descending order
	rankSet := make(map[int]bool)
	for _, card := range cards {
		rankSet[card.Rank] = true
	}

	ranks := make([]int, 0, len(rankSet))
	for rank := range rankSet {
		ranks = append(ranks, rank)
	}
	sort.Slice(ranks, func(i, j int) bool {
		return ranks[i] > ranks[j]
	})

	// Check for 5 consecutive ranks
	for i := 0; i <= len(ranks)-5; i++ {
		isStraight := true
		for j := 0; j < 4; j++ {
			if ranks[i+j]-ranks[i+j+1] != 1 {
				isStraight = false
				break
			}
		}
		if isStraight {
			return ranks[i]
		}
	}

	// Check for wheel (A-2-3-4-5)
	if rankSet[14] && rankSet[5] && rankSet[4] && rankSet[3] && rankSet[2] {
		return 5 // In a wheel, the 5 is the high card
	}

	return -1
}

// filterBySuit returns cards of a specific suit
func filterBySuit(cards []Card, suit int) []Card {
	filtered := make([]Card, 0, 7)
	for _, card := range cards {
		if card.Suit == suit {
			filtered = append(filtered, card)
		}
	}
	return filtered
}

// GetHandName returns a human-readable name for a hand category
func GetHandName(category int) string {
	names := []string{
		"High Card",
		"Pair",
		"Two Pair",
		"Three of a Kind",
		"Straight",
		"Flush",
		"Full House",
		"Four of a Kind",
		"Straight Flush",
	}
	if category >= 0 && category < len(names) {
		return names[category]
	}
	return "Unknown"
}
