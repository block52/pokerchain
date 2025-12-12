package equity

import (
	"github.com/block52/pokerchain/x/poker/types"
)

// Fast 7-card poker hand evaluator using bit manipulation and lookup tables.
// This is ~100x faster than the combinatorial approach.

// Card bit representation:
// Each card is represented by its rank (0-12 for 2-A) and suit (0-3)
// We use separate 16-bit masks per suit for flush detection

// Precomputed lookup tables
var (
	// straightTable[bitmask] = high card of straight (0 if no straight)
	// bitmask is 13 bits representing ranks 2-A
	straightTable [8192]uint8

	// flushTable[bitmask] = hand rank value for flush hands
	// Only valid when exactly 5+ bits are set from same suit
	flushTable [8192]uint16

	// Rank lookup for non-flush hands based on rank counts
	// Indexed by a hash of the rank distribution
	uniqueRankTable [8192]uint16

	tablesInitialized bool
)

func init() {
	initLookupTables()
}

func initLookupTables() {
	if tablesInitialized {
		return
	}

	// Initialize straight table
	// Straight patterns (13 bits, A=bit 12, K=11, ..., 2=bit 0)
	straightPatterns := []struct {
		pattern uint16
		high    uint8
	}{
		{0x1F00, 14}, // A-K-Q-J-T (royal/broadway)
		{0x0F80, 13}, // K-Q-J-T-9
		{0x07C0, 12}, // Q-J-T-9-8
		{0x03E0, 11}, // J-T-9-8-7
		{0x01F0, 10}, // T-9-8-7-6
		{0x00F8, 9},  // 9-8-7-6-5
		{0x007C, 8},  // 8-7-6-5-4
		{0x003E, 7},  // 7-6-5-4-3
		{0x001F, 6},  // 6-5-4-3-2
		{0x100F, 5},  // A-5-4-3-2 (wheel) - A is high bit + low 4
	}

	for i := 0; i < 8192; i++ {
		mask := uint16(i)
		for _, sp := range straightPatterns {
			if mask&sp.pattern == sp.pattern {
				straightTable[i] = sp.high
				break
			}
		}
	}

	// Initialize flush ranking table (for 5-card flush hands)
	// This gives a relative ranking based on the high cards
	for i := 0; i < 8192; i++ {
		bits := popCount16(uint16(i))
		if bits >= 5 {
			// Calculate flush rank based on top 5 cards
			flushTable[i] = calculateFlushRank(uint16(i))
		}
	}

	// Initialize unique rank table for high card hands
	for i := 0; i < 8192; i++ {
		if popCount16(uint16(i)) == 5 {
			uniqueRankTable[i] = calculateHighCardRank(uint16(i))
		}
	}

	tablesInitialized = true
}

// calculateFlushRank calculates rank for a flush hand (top 5 cards matter)
func calculateFlushRank(mask uint16) uint16 {
	// Extract top 5 bits
	var rank uint16
	count := 0
	for i := 12; i >= 0 && count < 5; i-- {
		if mask&(1<<i) != 0 {
			rank = rank<<4 | uint16(i+2) // +2 because rank 0 = 2
			count++
		}
	}
	return rank
}

// calculateHighCardRank calculates rank for high card hands
func calculateHighCardRank(mask uint16) uint16 {
	var rank uint16
	for i := 12; i >= 0; i-- {
		if mask&(1<<i) != 0 {
			rank = rank<<4 | uint16(i+2)
		}
	}
	return rank
}

// popCount16 counts set bits in a 16-bit value
func popCount16(x uint16) int {
	x = x - ((x >> 1) & 0x5555)
	x = (x & 0x3333) + ((x >> 2) & 0x3333)
	x = (x + (x >> 4)) & 0x0F0F
	return int((x * 0x0101) >> 8)
}

// FastHandResult is a compact hand evaluation result
type FastHandResult struct {
	Category uint8  // 0=high card, 1=pair, ..., 8=straight flush
	Score    uint32 // Full comparable score
}

// EvaluateHandFast evaluates 5-7 cards using optimized lookup tables
func EvaluateHandFast(cards []types.Card) FastHandResult {
	if len(cards) < 5 || len(cards) > 7 {
		return FastHandResult{}
	}

	// Build bitmasks per suit and overall rank mask
	var suitMasks [4]uint16 // One mask per suit (bits 0-12 for ranks 2-A)
	var rankCounts [13]uint8
	var rankMask uint16

	for _, c := range cards {
		rank := c.Rank - 1 // Convert 1-13 to 0-12
		if c.Rank == 1 {
			rank = 12 // Ace is rank 12 (highest)
		} else {
			rank = c.Rank - 2 // 2=0, 3=1, ..., K=11
		}
		if c.Rank == 1 {
			rank = 12 // Ace
		}

		suitIdx := int(c.Suit) - 1 // Suits are 1-4, convert to 0-3
		bit := uint16(1) << rank
		suitMasks[suitIdx] |= bit
		rankMask |= bit
		rankCounts[rank]++
	}

	// Check for flush (5+ cards of same suit)
	flushSuit := -1
	for s := 0; s < 4; s++ {
		if popCount16(suitMasks[s]) >= 5 {
			flushSuit = s
			break
		}
	}

	// Check for straight
	straightHigh := straightTable[rankMask]

	// If we have a flush, check for straight flush
	if flushSuit >= 0 {
		flushMask := suitMasks[flushSuit]
		sfHigh := straightTable[flushMask]
		if sfHigh > 0 {
			// Straight flush!
			return FastHandResult{
				Category: 8,
				Score:    uint32(8)<<24 | uint32(sfHigh)<<16,
			}
		}
		// Regular flush - rank by top 5 cards
		flushRank := flushTable[flushMask]
		return FastHandResult{
			Category: 5,
			Score:    uint32(5)<<24 | uint32(flushRank),
		}
	}

	// Count rank frequencies
	var quads, trips, pairs uint8
	var quadRank, tripRank, highPairRank, lowPairRank uint8
	var kickers [5]uint8
	kickerCount := 0

	// Scan from high to low
	for r := 12; r >= 0; r-- {
		cnt := rankCounts[r]
		rankVal := uint8(r + 2) // Convert back to 2-14
		switch cnt {
		case 4:
			quads++
			quadRank = rankVal
		case 3:
			if trips == 0 {
				trips++
				tripRank = rankVal
			} else {
				// Second trips acts as a pair for full house
				pairs++
				if highPairRank == 0 {
					highPairRank = rankVal
				} else if lowPairRank == 0 {
					lowPairRank = rankVal
				}
			}
		case 2:
			pairs++
			if highPairRank == 0 {
				highPairRank = rankVal
			} else if lowPairRank == 0 {
				lowPairRank = rankVal
			}
		case 1:
			if kickerCount < 5 {
				kickers[kickerCount] = rankVal
				kickerCount++
			}
		}
	}

	// Determine hand category and score
	if quads > 0 {
		// Four of a kind
		kicker := kickers[0]
		if highPairRank > kicker {
			kicker = highPairRank
		}
		if tripRank > kicker {
			kicker = tripRank
		}
		return FastHandResult{
			Category: 7,
			Score:    uint32(7)<<24 | uint32(quadRank)<<16 | uint32(kicker)<<8,
		}
	}

	if trips > 0 && pairs > 0 {
		// Full house
		pairRank := highPairRank
		return FastHandResult{
			Category: 6,
			Score:    uint32(6)<<24 | uint32(tripRank)<<16 | uint32(pairRank)<<8,
		}
	}

	if straightHigh > 0 {
		// Straight
		return FastHandResult{
			Category: 4,
			Score:    uint32(4)<<24 | uint32(straightHigh)<<16,
		}
	}

	if trips > 0 {
		// Three of a kind
		return FastHandResult{
			Category: 3,
			Score:    uint32(3)<<24 | uint32(tripRank)<<16 | uint32(kickers[0])<<8 | uint32(kickers[1]),
		}
	}

	if pairs >= 2 {
		// Two pair
		kicker := kickers[0]
		if lowPairRank > 0 && pairs > 2 {
			// We have 3 pairs, use the third as potential kicker
			if lowPairRank > kicker {
				kicker = lowPairRank
			}
		}
		return FastHandResult{
			Category: 2,
			Score:    uint32(2)<<24 | uint32(highPairRank)<<16 | uint32(lowPairRank)<<8 | uint32(kicker),
		}
	}

	if pairs == 1 {
		// One pair
		return FastHandResult{
			Category: 1,
			Score:    uint32(1)<<24 | uint32(highPairRank)<<16 | uint32(kickers[0])<<8 | uint32(kickers[1])<<4 | uint32(kickers[2]),
		}
	}

	// High card
	return FastHandResult{
		Category: 0,
		Score:    uint32(kickers[0])<<16 | uint32(kickers[1])<<12 | uint32(kickers[2])<<8 | uint32(kickers[3])<<4 | uint32(kickers[4]),
	}
}

// EvaluateHandFastFromMnemonics is a convenience function
func EvaluateHandFastFromMnemonics(mnemonics []string) (FastHandResult, error) {
	cards, err := CardsFromMnemonics(mnemonics)
	if err != nil {
		return FastHandResult{}, err
	}
	return EvaluateHandFast(cards), nil
}

// CompareFastHands compares two fast hand results
// Returns 1 if h1 wins, -1 if h2 wins, 0 if tie
func CompareFastHands(h1, h2 FastHandResult) int {
	if h1.Score > h2.Score {
		return 1
	}
	if h1.Score < h2.Score {
		return -1
	}
	return 0
}
