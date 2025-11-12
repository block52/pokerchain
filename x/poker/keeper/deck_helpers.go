package keeper

import (
	"context"
	"fmt"

	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// GenerateShuffleSeed creates a deterministic 52-number seed array from the block hash
// This provides verifiable randomness for deck shuffling based on blockchain state
func (k Keeper) GenerateShuffleSeed(ctx context.Context) []int {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Use block hash for deterministic randomness
	// AppHash provides deterministic state from previous block
	blockHash := sdkCtx.BlockHeader().AppHash

	// If AppHash is empty (e.g., genesis block), use LastCommitHash
	if len(blockHash) == 0 {
		blockHash = sdkCtx.BlockHeader().LastCommitHash
	}

	// If still empty, use a fallback based on block height and time
	if len(blockHash) == 0 {
		fallbackStr := fmt.Sprintf("%d-%d", sdkCtx.BlockHeight(), sdkCtx.BlockTime().Unix())
		blockHash = []byte(fallbackStr)
	}

	// Generate 52 seed values from the block hash
	seed := make([]int, 52)
	for i := 0; i < 52; i++ {
		// Use modulo on hash bytes to create values in range 0-51
		// Cycle through hash bytes if we need more than hash length
		hashIndex := i % len(blockHash)
		seed[i] = int(blockHash[hashIndex]) % 52
	}

	return seed
}

// InitializeAndShuffleDeck creates a new standard 52-card deck and shuffles it
// using a seed generated from the current block hash
func (k Keeper) InitializeAndShuffleDeck(ctx context.Context) (*types.Deck, error) {
	// Create a new standard deck
	deck, err := types.NewDeck("")
	if err != nil {
		return nil, fmt.Errorf("failed to create new deck: %w", err)
	}

	// Generate shuffle seed from block state
	seed := k.GenerateShuffleSeed(ctx)

	// Shuffle the deck with the deterministic seed
	deck.Shuffle(seed)

	return deck, nil
}

// LoadDeckFromState parses a deck from its string representation
// Returns error if the deck string is invalid
func (k Keeper) LoadDeckFromState(deckStr string) (*types.Deck, error) {
	if deckStr == "" {
		return nil, fmt.Errorf("deck string is empty")
	}

	deck, err := types.NewDeck(deckStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse deck from state: %w", err)
	}

	return deck, nil
}

// SaveDeckToState serializes a deck to its string representation
func (k Keeper) SaveDeckToState(deck *types.Deck) string {
	return deck.ToString()
}
