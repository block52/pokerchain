package keeper_test

import (
	"testing"

	"github.com/block52/pokerchain/x/poker/types"
	"github.com/stretchr/testify/require"
)

func TestGenerateShuffleSeed(t *testing.T) {
	f := initFixture(t)
	k := f.keeper
	ctx := f.ctx

	// Generate seed
	seed := k.GenerateShuffleSeed(ctx)

	// Verify seed has exactly 52 values
	require.Equal(t, 52, len(seed), "Seed should have exactly 52 values")

	// Verify all values are in valid range (0-51)
	for i, val := range seed {
		require.GreaterOrEqual(t, val, 0, "Seed value at index %d should be >= 0", i)
		require.LessOrEqual(t, val, 51, "Seed value at index %d should be <= 51", i)
	}

	// Generate seed again - should be same in same block context
	seed2 := k.GenerateShuffleSeed(ctx)
	require.Equal(t, seed, seed2, "Same context should produce same seed (deterministic)")
}

func TestInitializeAndShuffleDeck(t *testing.T) {
	f := initFixture(t)
	k := f.keeper
	ctx := f.ctx

	// Initialize and shuffle deck
	deck, err := k.InitializeAndShuffleDeck(ctx)
	require.NoError(t, err, "Should successfully initialize deck")
	require.NotNil(t, deck, "Deck should not be nil")

	// Verify deck has hash (proves it was created properly)
	require.NotEmpty(t, deck.Hash, "Deck should have hash")

	// Verify deck has seed hash (proves it was shuffled)
	require.NotEmpty(t, deck.SeedHash, "Deck should have seed hash from shuffle")

	// Verify ToString produces valid string
	deckStr := deck.ToString()
	require.NotEmpty(t, deckStr, "Deck string should not be empty")
	require.Contains(t, deckStr, "-", "Deck string should contain card separators")

	// Initialize another deck - should be different due to shuffle
	deck2, err := k.InitializeAndShuffleDeck(ctx)
	require.NoError(t, err)

	// In same context, should produce same shuffled deck (deterministic)
	require.Equal(t, deck.ToString(), deck2.ToString(), "Same context should produce same shuffled deck")
}

func TestDeckRoundTripSerialization(t *testing.T) {
	f := initFixture(t)
	k := f.keeper
	ctx := f.ctx

	// Create and shuffle a deck
	originalDeck, err := k.InitializeAndShuffleDeck(ctx)
	require.NoError(t, err)

	// Serialize to string
	deckStr := k.SaveDeckToState(originalDeck)
	require.NotEmpty(t, deckStr, "Serialized deck should not be empty")

	// Deserialize back
	loadedDeck, err := k.LoadDeckFromState(deckStr)
	require.NoError(t, err, "Should successfully load deck from string")
	require.NotNil(t, loadedDeck, "Loaded deck should not be nil")

	// Verify deck hash matches (proves card order is preserved)
	require.Equal(t, originalDeck.Hash, loadedDeck.Hash, "Deck hashes should match")

	// Note: SeedHash is NOT preserved in string serialization
	// It's metadata about shuffle history, not deck state
	// After reload, SeedHash will be empty until next shuffle
	require.Empty(t, loadedDeck.SeedHash, "SeedHash should be empty after loading from string")

	// Verify serialized form matches
	require.Equal(t, deckStr, loadedDeck.ToString(), "Serialized strings should match")
}

func TestDeckStateWithTopPointer(t *testing.T) {
	f := initFixture(t)
	k := f.keeper
	ctx := f.ctx

	// Create and shuffle deck
	deck, err := k.InitializeAndShuffleDeck(ctx)
	require.NoError(t, err)

	// Deal some cards to advance top pointer
	card1 := deck.GetNext()
	require.NotNil(t, card1, "Should deal first card")

	card2 := deck.GetNext()
	require.NotNil(t, card2, "Should deal second card")

	// Cards should be different
	require.NotEqual(t, card1.Mnemonic, card2.Mnemonic, "Consecutive cards should be different")

	// Serialize with top pointer advanced
	deckStr := k.SaveDeckToState(deck)
	require.Contains(t, deckStr, "[", "Deck string should contain top pointer marker")

	// Load and verify top pointer preserved
	loadedDeck, err := k.LoadDeckFromState(deckStr)
	require.NoError(t, err)

	// Next card from loaded deck should match original deck's next card
	card3Original := deck.GetNext()
	card3Loaded := loadedDeck.GetNext()
	require.Equal(t, card3Original.Mnemonic, card3Loaded.Mnemonic, "Top pointer should be preserved")
}

func TestLoadDeckFromState_EmptyString(t *testing.T) {
	f := initFixture(t)
	k := f.keeper

	// Try to load empty deck string
	_, err := k.LoadDeckFromState("")
	require.Error(t, err, "Should error on empty deck string")
	require.Contains(t, err.Error(), "empty", "Error should mention empty deck")
}

func TestLoadDeckFromState_InvalidString(t *testing.T) {
	f := initFixture(t)
	k := f.keeper

	// Try to load invalid deck string
	_, err := k.LoadDeckFromState("invalid-deck-format")
	require.Error(t, err, "Should error on invalid deck string")
}

func TestDeckIntegrationWithGameState(t *testing.T) {
	f := initFixture(t)
	k := f.keeper
	ctx := f.ctx

	// Initialize deck
	deck, err := k.InitializeAndShuffleDeck(ctx)
	require.NoError(t, err)

	// Simulate storing in game state
	gameState := types.TexasHoldemStateDTO{
		Type:           types.GameTypeTexasHoldem,
		Address:        "test-game",
		HandNumber:     1,
		Round:          types.RoundAnte,
		Deck:           deck.ToString(),
		Players:        []types.PlayerDTO{},
		CommunityCards: []string{},
		Pots:           []string{"0"},
	}

	// Verify deck is properly stored
	require.NotEmpty(t, gameState.Deck, "Game state should have deck")

	// Load deck from game state
	loadedDeck, err := k.LoadDeckFromState(gameState.Deck)
	require.NoError(t, err, "Should load deck from game state")

	// Deal cards (simulating game progression)
	holeCards := loadedDeck.Deal(2)
	require.Equal(t, 2, len(holeCards), "Should deal 2 hole cards")

	flopCards := loadedDeck.Deal(3)
	require.Equal(t, 3, len(flopCards), "Should deal 3 flop cards")

	// Update game state with new deck position
	gameState.Deck = k.SaveDeckToState(loadedDeck)
	gameState.CommunityCards = []string{
		flopCards[0].Mnemonic,
		flopCards[1].Mnemonic,
		flopCards[2].Mnemonic,
	}

	// Reload and continue
	reloadedDeck, err := k.LoadDeckFromState(gameState.Deck)
	require.NoError(t, err)

	// Deal turn
	turnCard := reloadedDeck.GetNext()
	require.NotNil(t, turnCard, "Should deal turn card")

	// Verify turn card is not in flop
	for _, flopCard := range flopCards {
		require.NotEqual(t, turnCard.Mnemonic, flopCard.Mnemonic, "Turn card should be different from flop cards")
	}
}
