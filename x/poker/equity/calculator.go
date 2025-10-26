package equity

import (
	"fmt"
	"math/rand"
	"strings"
	"time"
)

// Card represents a playing card
type Card struct {
	Rank string // "2", "3", ..., "9", "T", "J", "Q", "K", "A"
	Suit string // "C" (clubs), "D" (diamonds), "H" (hearts), "S" (spades)
}

// EquityResult contains the equity calculation results for one player
type EquityResult struct {
	PlayerIndex int     // 0-based player index
	WinPercent  float64 // Percentage of hands won
	TiePercent  float64 // Percentage of hands tied
	Hands       int     // Number of hands simulated
}

// EquityCalculator handles poker equity calculations
type EquityCalculator struct {
	rand *rand.Rand
}

// NewEquityCalculator creates a new equity calculator
func NewEquityCalculator() *EquityCalculator {
	return &EquityCalculator{
		rand: rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// ParseCard parses a card string like "AS" into a Card
func ParseCard(s string) (Card, error) {
	s = strings.ToUpper(strings.TrimSpace(s))
	if len(s) != 2 {
		return Card{}, fmt.Errorf("invalid card format: %s", s)
	}

	rank := string(s[0])
	suit := string(s[1])

	// Validate rank
	validRanks := map[string]bool{
		"2": true, "3": true, "4": true, "5": true, "6": true,
		"7": true, "8": true, "9": true, "T": true, "J": true,
		"Q": true, "K": true, "A": true,
	}
	if !validRanks[rank] {
		return Card{}, fmt.Errorf("invalid rank: %s", rank)
	}

	// Validate suit
	validSuits := map[string]bool{"C": true, "D": true, "H": true, "S": true}
	if !validSuits[suit] {
		return Card{}, fmt.Errorf("invalid suit: %s", suit)
	}

	return Card{Rank: rank, Suit: suit}, nil
}

// CalculateEquity calculates the equity for each player using Monte Carlo simulation
func (ec *EquityCalculator) CalculateEquity(
	playerHands [][]string,
	communityCards []string,
	simulations int,
) ([]EquityResult, error) {
	// Validate input
	if len(playerHands) < 2 {
		return nil, fmt.Errorf("need at least 2 players")
	}

	// Parse all cards and check for duplicates
	usedCards := make(map[string]bool)
	parsedPlayerHands := make([][]Card, len(playerHands))

	for i, hand := range playerHands {
		if len(hand) != 2 {
			return nil, fmt.Errorf("player %d must have exactly 2 cards", i)
		}
		parsedHand := make([]Card, 2)
		for j, cardStr := range hand {
			card, err := ParseCard(cardStr)
			if err != nil {
				return nil, fmt.Errorf("player %d card %d: %w", i, j, err)
			}
			cardKey := card.Rank + card.Suit
			if usedCards[cardKey] {
				return nil, fmt.Errorf("duplicate card: %s", cardKey)
			}
			usedCards[cardKey] = true
			parsedHand[j] = card
		}
		parsedPlayerHands[i] = parsedHand
	}

	// Parse community cards
	parsedCommunity := make([]Card, len(communityCards))
	for i, cardStr := range communityCards {
		card, err := ParseCard(cardStr)
		if err != nil {
			return nil, fmt.Errorf("community card %d: %w", i, err)
		}
		cardKey := card.Rank + card.Suit
		if usedCards[cardKey] {
			return nil, fmt.Errorf("duplicate card: %s", cardKey)
		}
		usedCards[cardKey] = true
		parsedCommunity[i] = card
	}

	if len(parsedCommunity) > 5 {
		return nil, fmt.Errorf("too many community cards: %d (max 5)", len(parsedCommunity))
	}

	// Create deck of remaining cards
	remainingDeck := ec.createDeck(usedCards)

	// Run simulations
	wins := make([]int, len(playerHands))
	ties := make([]int, len(playerHands))

	for sim := 0; sim < simulations; sim++ {
		// Shuffle remaining deck
		ec.shuffle(remainingDeck)

		// Complete community cards if needed
		fullCommunity := make([]Card, len(parsedCommunity))
		copy(fullCommunity, parsedCommunity)

		cardsNeeded := 5 - len(parsedCommunity)
		for i := 0; i < cardsNeeded; i++ {
			fullCommunity = append(fullCommunity, remainingDeck[i])
		}

		// Evaluate all hands
		scores := make([]int, len(parsedPlayerHands))
		for i, hand := range parsedPlayerHands {
			scores[i] = ec.evaluateHand(hand, fullCommunity)
		}

		// Find winner(s)
		maxScore := scores[0]
		for _, score := range scores {
			if score > maxScore {
				maxScore = score
			}
		}

		// Count winners
		winnerCount := 0
		for _, score := range scores {
			if score == maxScore {
				winnerCount++
			}
		}

		// Record results
		if winnerCount == 1 {
			for i, score := range scores {
				if score == maxScore {
					wins[i]++
				}
			}
		} else {
			// Tie
			for i, score := range scores {
				if score == maxScore {
					ties[i]++
				}
			}
		}
	}

	// Calculate percentages
	results := make([]EquityResult, len(playerHands))
	for i := range results {
		results[i] = EquityResult{
			PlayerIndex: i,
			WinPercent:  float64(wins[i]) / float64(simulations) * 100.0,
			TiePercent:  float64(ties[i]) / float64(simulations) * 100.0,
			Hands:       simulations,
		}
	}

	return results, nil
}

// createDeck creates a deck of cards excluding the used cards
func (ec *EquityCalculator) createDeck(usedCards map[string]bool) []Card {
	ranks := []string{"2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"}
	suits := []string{"C", "D", "H", "S"}

	var deck []Card
	for _, rank := range ranks {
		for _, suit := range suits {
			cardKey := rank + suit
			if !usedCards[cardKey] {
				deck = append(deck, Card{Rank: rank, Suit: suit})
			}
		}
	}
	return deck
}

// shuffle randomizes the order of cards in the deck
func (ec *EquityCalculator) shuffle(deck []Card) {
	for i := len(deck) - 1; i > 0; i-- {
		j := ec.rand.Intn(i + 1)
		deck[i], deck[j] = deck[j], deck[i]
	}
}

// evaluateHand evaluates a poker hand (2 hole cards + 5 community cards)
// Returns a score where higher is better
func (ec *EquityCalculator) evaluateHand(holeCards []Card, communityCards []Card) int {
	// Combine hole cards and community cards
	allCards := make([]Card, len(holeCards)+len(communityCards))
	copy(allCards, holeCards)
	copy(allCards[len(holeCards):], communityCards)

	// For a full poker evaluation, you would check for:
	// - Royal Flush
	// - Straight Flush
	// - Four of a Kind
	// - Full House
	// - Flush
	// - Straight
	// - Three of a Kind
	// - Two Pair
	// - Pair
	// - High Card

	// Simplified evaluation (for demonstration)
	// In production, use a proper poker hand evaluator
	return ec.simpleHandEval(allCards)
}

// simpleHandEval is a simplified hand evaluator
// In production, replace this with a proper poker hand evaluator library
func (ec *EquityCalculator) simpleHandEval(cards []Card) int {
	rankValues := map[string]int{
		"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8,
		"9": 9, "T": 10, "J": 11, "Q": 12, "K": 13, "A": 14,
	}

	// Count ranks and suits
	rankCounts := make(map[string]int)
	suitCounts := make(map[string]int)
	for _, card := range cards {
		rankCounts[card.Rank]++
		suitCounts[card.Suit]++
	}

	// Check for flush
	hasFlush := false
	for _, count := range suitCounts {
		if count >= 5 {
			hasFlush = true
			break
		}
	}

	// Check for pairs, trips, quads
	maxRankCount := 0
	secondMaxRankCount := 0
	highestRank := 0

	for rank, count := range rankCounts {
		if count > maxRankCount {
			secondMaxRankCount = maxRankCount
			maxRankCount = count
		} else if count > secondMaxRankCount {
			secondMaxRankCount = count
		}
		if rankValues[rank] > highestRank {
			highestRank = rankValues[rank]
		}
	}

	// Score calculation (simplified)
	score := 0

	if hasFlush {
		score += 5000000 // Flush base score
	}

	if maxRankCount == 4 {
		score += 7000000 // Four of a kind
	} else if maxRankCount == 3 && secondMaxRankCount >= 2 {
		score += 6000000 // Full house
	} else if maxRankCount == 3 {
		score += 3000000 // Three of a kind
	} else if maxRankCount == 2 && secondMaxRankCount == 2 {
		score += 2000000 // Two pair
	} else if maxRankCount == 2 {
		score += 1000000 // One pair
	}

	// Add high card value
	score += highestRank

	return score
}
