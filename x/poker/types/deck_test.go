package types

import (
	"strings"
	"testing"
)

func TestNewDeck_Standard52(t *testing.T) {
	deck, err := NewDeck("")
	if err != nil {
		t.Fatalf("Failed to create standard deck: %v", err)
	}

	if len(deck.cards) != 52 {
		t.Errorf("Expected 52 cards, got %d", len(deck.cards))
	}

	if deck.top != 0 {
		t.Errorf("Expected top to be 0, got %d", deck.top)
	}

	if deck.Hash == "" {
		t.Error("Expected hash to be set")
	}
}

func TestNewDeck_FromString(t *testing.T) {
	deckStr := "AC-2C-3C-4C-5C-6C-7C-8C-9C-TC-JC-QC-KC-AD-[2D]-3D-4D-5D-6D-7D-8D-9D-TD-JD-QD-KD-AH-2H-3H-4H-5H-6H-7H-8H-9H-TH-JH-QH-KH-AS-2S-3S-4S-5S-6S-7S-8S-9S-TS-JS-QS-KS"

	deck, err := NewDeck(deckStr)
	if err != nil {
		t.Fatalf("Failed to create deck from string: %v", err)
	}

	if len(deck.cards) != 52 {
		t.Errorf("Expected 52 cards, got %d", len(deck.cards))
	}

	// Check that top is at position 14 (where [2D] was)
	if deck.top != 14 {
		t.Errorf("Expected top to be 14, got %d", deck.top)
	}

	// Check first card
	if deck.cards[0].Mnemonic != "AC" {
		t.Errorf("Expected first card to be AC, got %s", deck.cards[0].Mnemonic)
	}

	// Check card at top position
	if deck.cards[14].Mnemonic != "2D" {
		t.Errorf("Expected card at position 14 to be 2D, got %s", deck.cards[14].Mnemonic)
	}
}

func TestDeck_ToString(t *testing.T) {
	originalStr := "AC-2C-3C-4C-5C-6C-7C-8C-9C-TC-JC-QC-KC-AD-[2D]-3D-4D-5D-6D-7D-8D-9D-TD-JD-QD-KD-AH-2H-3H-4H-5H-6H-7H-8H-9H-TH-JH-QH-KH-AS-2S-3S-4S-5S-6S-7S-8S-9S-TS-JS-QS-KS"

	deck, err := NewDeck(originalStr)
	if err != nil {
		t.Fatalf("Failed to create deck: %v", err)
	}

	resultStr := deck.ToString()
	if resultStr != originalStr {
		t.Errorf("ToString() didn't match original.\nExpected: %s\nGot: %s", originalStr, resultStr)
	}
}

func TestCardFromString(t *testing.T) {
	tests := []struct {
		mnemonic     string
		expectedRank int
		expectedSuit Suit
	}{
		{"AC", 1, SuitClubs},
		{"2D", 2, SuitDiamonds},
		{"TH", 10, SuitHearts},
		{"JS", 11, SuitSpades},
		{"QC", 12, SuitClubs},
		{"KD", 13, SuitDiamonds},
		{"9H", 9, SuitHearts},
	}

	for _, tt := range tests {
		card, err := CardFromString(tt.mnemonic)
		if err != nil {
			t.Errorf("Failed to parse card %s: %v", tt.mnemonic, err)
			continue
		}

		if card.Rank != tt.expectedRank {
			t.Errorf("Card %s: expected rank %d, got %d", tt.mnemonic, tt.expectedRank, card.Rank)
		}

		if card.Suit != tt.expectedSuit {
			t.Errorf("Card %s: expected suit %d, got %d", tt.mnemonic, tt.expectedSuit, card.Suit)
		}

		if card.Mnemonic != tt.mnemonic {
			t.Errorf("Card %s: expected mnemonic %s, got %s", tt.mnemonic, tt.mnemonic, card.Mnemonic)
		}
	}
}

func TestGetCardMnemonic(t *testing.T) {
	tests := []struct {
		suit     Suit
		rank     int
		expected string
	}{
		{SuitClubs, 1, "AC"},
		{SuitDiamonds, 2, "2D"},
		{SuitHearts, 10, "TH"},
		{SuitSpades, 11, "JS"},
		{SuitClubs, 12, "QC"},
		{SuitDiamonds, 13, "KD"},
		{SuitHearts, 9, "9H"},
	}

	for _, tt := range tests {
		result := GetCardMnemonic(tt.suit, tt.rank)
		if result != tt.expected {
			t.Errorf("GetCardMnemonic(%d, %d): expected %s, got %s", tt.suit, tt.rank, tt.expected, result)
		}
	}
}

func TestDeck_GetNext(t *testing.T) {
	deck, err := NewDeck("")
	if err != nil {
		t.Fatalf("Failed to create deck: %v", err)
	}

	// Get first card (should be AC)
	card := deck.GetNext()
	if card.Mnemonic != "AC" {
		t.Errorf("Expected first card to be AC, got %s", card.Mnemonic)
	}

	if deck.top != 1 {
		t.Errorf("Expected top to be 1 after GetNext, got %d", deck.top)
	}

	// Get second card (should be 2C)
	card = deck.GetNext()
	if card.Mnemonic != "2C" {
		t.Errorf("Expected second card to be 2C, got %s", card.Mnemonic)
	}

	if deck.top != 2 {
		t.Errorf("Expected top to be 2 after second GetNext, got %d", deck.top)
	}
}

func TestDeck_Deal(t *testing.T) {
	deck, err := NewDeck("")
	if err != nil {
		t.Fatalf("Failed to create deck: %v", err)
	}

	// Deal 5 cards
	cards := deck.Deal(5)
	if len(cards) != 5 {
		t.Errorf("Expected 5 cards, got %d", len(cards))
	}

	// Check first card is AC
	if cards[0].Mnemonic != "AC" {
		t.Errorf("Expected first card to be AC, got %s", cards[0].Mnemonic)
	}

	// Check top moved to position 5
	if deck.top != 5 {
		t.Errorf("Expected top to be 5, got %d", deck.top)
	}
}

func TestDeck_Shuffle(t *testing.T) {
	deck, err := NewDeck("")
	if err != nil {
		t.Fatalf("Failed to create deck: %v", err)
	}

	originalHash := deck.Hash
	originalFirstCard := deck.cards[0].Mnemonic

	// Create a seed with 52 values
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 7 % 52 // Some pseudo-random values
	}

	deck.Shuffle(seed)

	// Hash should change after shuffle
	if deck.Hash == originalHash {
		t.Error("Hash should change after shuffle")
	}

	// SeedHash should be set
	if deck.SeedHash == "" {
		t.Error("SeedHash should be set after shuffle")
	}

	// First card likely changed (not guaranteed, but very likely)
	// Just verify the deck still has 52 cards
	if len(deck.cards) != 52 {
		t.Errorf("Expected 52 cards after shuffle, got %d", len(deck.cards))
	}

	// Verify first card changed (statistically almost certain)
	if deck.cards[0].Mnemonic == originalFirstCard {
		t.Logf("Warning: First card didn't change after shuffle (unlikely but possible)")
	}
}

func TestDeck_Hash(t *testing.T) {
	deck1, _ := NewDeck("")
	deck2, _ := NewDeck("")

	// Two standard decks should have the same hash
	if deck1.Hash != deck2.Hash {
		t.Error("Two standard decks should have the same hash")
	}

	// After shuffling, hash should be different
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 7 % 52 // Use pseudo-random values that will actually shuffle
	}
	deck1.Shuffle(seed)

	if deck1.Hash == deck2.Hash {
		t.Error("Shuffled deck should have different hash than standard deck")
	}
}

func TestDeck_RoundTrip(t *testing.T) {
	// Create a standard deck, convert to string, parse back, compare
	deck1, err := NewDeck("")
	if err != nil {
		t.Fatalf("Failed to create deck: %v", err)
	}

	// Deal a few cards to move the top
	deck1.Deal(5)

	// Convert to string
	deckStr := deck1.ToString()

	// Parse back
	deck2, err := NewDeck(deckStr)
	if err != nil {
		t.Fatalf("Failed to parse deck from string: %v", err)
	}

	// Should have same top position
	if deck1.top != deck2.top {
		t.Errorf("Top positions don't match: %d vs %d", deck1.top, deck2.top)
	}

	// Should have same hash
	if deck1.Hash != deck2.Hash {
		t.Error("Hashes don't match after round trip")
	}

	// ToString should be identical
	if deck1.ToString() != deck2.ToString() {
		t.Error("ToString results don't match after round trip")
	}
}

func TestDeck_InvalidInput(t *testing.T) {
	// Test with wrong number of cards
	_, err := NewDeck("AC-2C-3C")
	if err == nil {
		t.Error("Expected error for deck with wrong number of cards")
	}
	if !strings.Contains(err.Error(), "52 cards") {
		t.Errorf("Expected error message about 52 cards, got: %v", err)
	}

	// Test invalid card mnemonic
	_, err = CardFromString("XY")
	if err == nil {
		t.Error("Expected error for invalid card mnemonic")
	}

	// Test invalid rank
	_, err = CardFromString("0C")
	if err != nil && !strings.Contains(err.Error(), "invalid rank") {
		t.Logf("Got error for invalid rank: %v", err)
	}
}
