package keeper

import (
	"context"
	"encoding/hex"
	"fmt"

	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// InitializeZKDeck creates a new zero-knowledge deck with commitments and VRF proof
func (k Keeper) InitializeZKDeck(ctx context.Context) (*types.ZKDeck, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Create a new ZK deck
	zkDeck, err := types.NewZKDeck("")
	if err != nil {
		return nil, fmt.Errorf("failed to create ZK deck: %w", err)
	}

	// Get block hash for VRF input
	blockHash := k.GetBlockHashForVRF(ctx)

	// Generate VRF keypair from validator's key (in production, this would be threshold)
	// For now, we use block hash as seed for determinism
	vrfKeypair, err := types.GenerateVRFKeypair(blockHash)
	if err != nil {
		return nil, fmt.Errorf("failed to generate VRF keypair: %w", err)
	}

	// Shuffle with VRF and create commitments
	timestamp := sdkCtx.BlockTime().Unix()
	if err := zkDeck.ShuffleWithVRF(vrfKeypair, blockHash, timestamp); err != nil {
		return nil, fmt.Errorf("failed to shuffle with VRF: %w", err)
	}

	return zkDeck, nil
}

// GetBlockHashForVRF returns the block hash to use as VRF input
func (k Keeper) GetBlockHashForVRF(ctx context.Context) []byte {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Use AppHash from previous block
	blockHash := sdkCtx.BlockHeader().AppHash

	// Fallback to LastCommitHash
	if len(blockHash) == 0 {
		blockHash = sdkCtx.BlockHeader().LastCommitHash
	}

	// Final fallback to deterministic value
	if len(blockHash) == 0 {
		fallbackStr := fmt.Sprintf("block-%d-%d", sdkCtx.BlockHeight(), sdkCtx.BlockTime().Unix())
		blockHash = []byte(fallbackStr)
	}

	return blockHash
}

// DealHoleCardsZK deals encrypted hole cards to a player
// Returns the encrypted cards and their commitment proofs
func (k Keeper) DealHoleCardsZK(
	zkDeck *types.ZKDeck,
	playerAddress string,
	playerPubKey string,
	numCards int,
) ([]*types.EncryptedCard, []*types.CardCommitment, error) {
	encryptedCards := make([]*types.EncryptedCard, numCards)
	commitments := make([]*types.CardCommitment, numCards)

	for i := 0; i < numCards; i++ {
		// Get next card with proof
		card, commitment, err := zkDeck.GetNextWithProof()
		if err != nil {
			return nil, nil, fmt.Errorf("failed to deal card %d: %w", i, err)
		}

		// Encrypt card for player
		encryptedCard, err := zkDeck.EncryptCardForPlayer(
			commitment.Position,
			playerAddress,
			playerPubKey,
		)
		if err != nil {
			return nil, nil, fmt.Errorf("failed to encrypt card %d: %w", i, err)
		}

		encryptedCards[i] = encryptedCard
		commitments[i] = commitment

		_ = card // Card value is hidden in encrypted form
	}

	return encryptedCards, commitments, nil
}

// RevealCommunityCardsZK reveals community cards with commitment proofs
func (k Keeper) RevealCommunityCardsZK(
	zkDeck *types.ZKDeck,
	numCards int,
) ([]types.Card, []*types.CardCommitment, error) {
	cards := make([]types.Card, numCards)
	commitments := make([]*types.CardCommitment, numCards)

	for i := 0; i < numCards; i++ {
		card, commitment, err := zkDeck.GetNextWithProof()
		if err != nil {
			return nil, nil, fmt.Errorf("failed to reveal community card %d: %w", i, err)
		}

		cards[i] = *card
		commitments[i] = commitment
	}

	return cards, commitments, nil
}

// VerifyCardCommitment verifies a card matches its commitment
func (k Keeper) VerifyCardCommitment(
	commitment string,
	position int,
	cardValue int,
	salt string,
) bool {
	return types.VerifyCommitment(commitment, position, cardValue, salt)
}

// VerifyVRFShuffle verifies the deck was shuffled fairly
func (k Keeper) VerifyVRFShuffle(ctx context.Context, zkDeck *types.ZKDeck) (bool, error) {
	blockHash := k.GetBlockHashForVRF(ctx)
	return zkDeck.VerifyShuffleVRF(blockHash)
}

// ZKDeckState represents the public state of a ZK deck (for storage)
type ZKDeckState struct {
	CommitmentRoot   string                  `json:"commitment_root"`
	Commitments      []types.CardCommitment  `json:"commitments"`
	VRFProof         *types.VRFProof         `json:"vrf_proof"`
	TopPosition      int                     `json:"top_position"`
	DeckHash         string                  `json:"deck_hash"`
	SeedHash         string                  `json:"seed_hash"`
	ShuffleTimestamp int64                   `json:"shuffle_timestamp"`
	RevealedCards    []RevealedCardInfo      `json:"revealed_cards"`
}

// RevealedCardInfo contains public info about a revealed card
type RevealedCardInfo struct {
	Position   int    `json:"position"`
	CardValue  int    `json:"card_value"`
	Salt       string `json:"salt"`
	Commitment string `json:"commitment"`
	Purpose    string `json:"purpose"` // "hole_card", "flop", "turn", "river"
}

// SerializeZKDeck converts a ZK deck to storable state
func (k Keeper) SerializeZKDeck(zkDeck *types.ZKDeck) *ZKDeckState {
	state := &ZKDeckState{
		CommitmentRoot:   zkDeck.CommitmentRoot,
		Commitments:      zkDeck.Commitments,
		VRFProof:         zkDeck.VRF,
		TopPosition:      zkDeck.Deck.GetTop(),
		DeckHash:         zkDeck.Deck.Hash,
		SeedHash:         zkDeck.Deck.SeedHash,
		ShuffleTimestamp: zkDeck.ShuffleTimestamp,
		RevealedCards:    make([]RevealedCardInfo, 0),
	}

	// Collect revealed cards
	for _, c := range zkDeck.Commitments {
		if c.Revealed {
			state.RevealedCards = append(state.RevealedCards, RevealedCardInfo{
				Position:   c.Position,
				CardValue:  c.CardValue,
				Salt:       c.Salt,
				Commitment: c.Commitment,
			})
		}
	}

	return state
}

// GetCommitmentProof returns a Merkle proof for a card position
func (k Keeper) GetCommitmentProof(zkDeck *types.ZKDeck, position int) ([]string, error) {
	return zkDeck.GetMerkleProof(position)
}

// VerifyCommitmentProof verifies a card's commitment against the Merkle root
func (k Keeper) VerifyCommitmentProof(
	commitment string,
	proof []string,
	root string,
	position int,
) bool {
	return types.VerifyMerkleProof(commitment, proof, root, position)
}

// GeneratePlayerCardKey generates a deterministic Curve25519 keypair for a player
// This allows players to derive their key from their existing Cosmos key
func GeneratePlayerCardKey(cosmosPrivKey []byte) (privateKey []byte, publicKey []byte, error error) {
	if len(cosmosPrivKey) < 32 {
		return nil, nil, fmt.Errorf("private key too short")
	}

	// Derive card encryption key from Cosmos key
	// In production, use proper key derivation (HKDF)
	derivedKey := make([]byte, 32)
	copy(derivedKey, cosmosPrivKey[:32])

	// Clamp for Curve25519
	derivedKey[0] &= 248
	derivedKey[31] &= 127
	derivedKey[31] |= 64

	privateKey = derivedKey

	// Calculate public key
	// Note: In production, use curve25519.ScalarBaseMult
	publicKey = make([]byte, 32)
	copy(publicKey, derivedKey) // Placeholder - real implementation uses curve ops

	return privateKey, publicKey, nil
}

// PlayerKeyRegistration stores a player's card encryption public key
type PlayerKeyRegistration struct {
	PlayerAddress string `json:"player_address"`
	PublicKey     string `json:"public_key"` // Hex-encoded Curve25519 public key
	RegisteredAt  int64  `json:"registered_at"`
	Signature     string `json:"signature"` // Proof of key ownership
}

// VerifyPlayerKeyOwnership verifies a player owns the card encryption key
func VerifyPlayerKeyOwnership(registration *PlayerKeyRegistration) bool {
	// In production, verify the signature proves ownership
	// For now, just check the fields are present
	return registration.PlayerAddress != "" &&
		registration.PublicKey != "" &&
		len(registration.PublicKey) == 64 // 32 bytes hex-encoded
}

// ZKGameState holds the zero-knowledge state for a poker game
type ZKGameState struct {
	GameID           string                          `json:"game_id"`
	ZKDeckState      *ZKDeckState                    `json:"zk_deck_state"`
	PlayerKeys       map[string]*PlayerKeyRegistration `json:"player_keys"`
	EncryptedHoleCards map[string][]types.EncryptedCard `json:"encrypted_hole_cards"` // player -> cards
	CommunityCards   []RevealedCardInfo              `json:"community_cards"`
	ShowdownReveals  map[string][]RevealedCardInfo   `json:"showdown_reveals"` // player -> revealed cards
}

// NewZKGameState creates a new ZK game state
func NewZKGameState(gameID string) *ZKGameState {
	return &ZKGameState{
		GameID:             gameID,
		PlayerKeys:         make(map[string]*PlayerKeyRegistration),
		EncryptedHoleCards: make(map[string][]types.EncryptedCard),
		CommunityCards:     make([]RevealedCardInfo, 0),
		ShowdownReveals:    make(map[string][]RevealedCardInfo),
	}
}

// RegisterPlayerKey registers a player's card encryption key
func (zgs *ZKGameState) RegisterPlayerKey(reg *PlayerKeyRegistration) error {
	if !VerifyPlayerKeyOwnership(reg) {
		return fmt.Errorf("invalid key registration")
	}
	zgs.PlayerKeys[reg.PlayerAddress] = reg
	return nil
}

// AddEncryptedHoleCards adds encrypted hole cards for a player
func (zgs *ZKGameState) AddEncryptedHoleCards(playerAddress string, cards []types.EncryptedCard) {
	zgs.EncryptedHoleCards[playerAddress] = cards
}

// AddCommunityCard adds a revealed community card
func (zgs *ZKGameState) AddCommunityCard(card RevealedCardInfo) {
	zgs.CommunityCards = append(zgs.CommunityCards, card)
}

// RevealShowdownCards records a player's card reveal at showdown
func (zgs *ZKGameState) RevealShowdownCards(playerAddress string, cards []RevealedCardInfo) {
	zgs.ShowdownReveals[playerAddress] = cards
}

// VerifyShowdown verifies all revealed cards at showdown match their commitments
func (zgs *ZKGameState) VerifyShowdown() error {
	if zgs.ZKDeckState == nil {
		return fmt.Errorf("no deck state")
	}

	// Verify each player's revealed cards
	for player, cards := range zgs.ShowdownReveals {
		for _, card := range cards {
			if !types.VerifyCommitment(card.Commitment, card.Position, card.CardValue, card.Salt) {
				return fmt.Errorf("player %s: card at position %d failed verification", player, card.Position)
			}
		}
	}

	return nil
}

// GetPublicState returns the publicly visible state (no secrets)
func (zgs *ZKGameState) GetPublicState() map[string]interface{} {
	publicKeys := make(map[string]string)
	for addr, reg := range zgs.PlayerKeys {
		publicKeys[addr] = reg.PublicKey
	}

	encryptedCardCounts := make(map[string]int)
	for addr, cards := range zgs.EncryptedHoleCards {
		encryptedCardCounts[addr] = len(cards)
	}

	return map[string]interface{}{
		"game_id":                zgs.GameID,
		"commitment_root":        zgs.ZKDeckState.CommitmentRoot,
		"vrf_proof":              zgs.ZKDeckState.VRFProof,
		"player_public_keys":     publicKeys,
		"encrypted_card_counts":  encryptedCardCounts,
		"community_cards":        zgs.CommunityCards,
		"deck_hash":              zgs.ZKDeckState.DeckHash,
	}
}

// Helper function to convert card value to Card struct
func CardFromValue(value int) types.Card {
	suit := types.Suit((value / 13) + 1)
	rank := (value % 13) + 1
	mnemonic := types.GetCardMnemonic(suit, rank)

	return types.Card{
		Suit:     suit,
		Rank:     rank,
		Value:    value,
		Mnemonic: mnemonic,
	}
}

// VerifyCardValueToMnemonic verifies a card value produces the expected mnemonic
func VerifyCardValueToMnemonic(value int, expectedMnemonic string) bool {
	card := CardFromValue(value)
	return card.Mnemonic == expectedMnemonic
}

// CreateCardRevealProof creates a proof that a card was legitimately dealt
type CardRevealProof struct {
	Position       int      `json:"position"`
	CardValue      int      `json:"card_value"`
	CardMnemonic   string   `json:"card_mnemonic"`
	Salt           string   `json:"salt"`
	Commitment     string   `json:"commitment"`
	CommitmentRoot string   `json:"commitment_root"`
	MerkleProof    []string `json:"merkle_proof"`
	VRFProof       *types.VRFProof `json:"vrf_proof"`
}

// CreateFullCardRevealProof creates a complete proof for a revealed card
func CreateFullCardRevealProof(
	zkDeck *types.ZKDeck,
	position int,
) (*CardRevealProof, error) {
	if position < 0 || position >= len(zkDeck.Commitments) {
		return nil, fmt.Errorf("invalid position")
	}

	commitment := zkDeck.Commitments[position]
	if !commitment.Revealed {
		return nil, fmt.Errorf("card not revealed")
	}

	merkleProof, err := zkDeck.GetMerkleProof(position)
	if err != nil {
		return nil, err
	}

	card := CardFromValue(commitment.CardValue)

	return &CardRevealProof{
		Position:       position,
		CardValue:      commitment.CardValue,
		CardMnemonic:   card.Mnemonic,
		Salt:           commitment.Salt,
		Commitment:     commitment.Commitment,
		CommitmentRoot: zkDeck.CommitmentRoot,
		MerkleProof:    merkleProof,
		VRFProof:       zkDeck.VRF,
	}, nil
}

// VerifyFullCardRevealProof verifies a complete card reveal proof
func VerifyFullCardRevealProof(proof *CardRevealProof, blockHash []byte) bool {
	// 1. Verify card value matches mnemonic
	if !VerifyCardValueToMnemonic(proof.CardValue, proof.CardMnemonic) {
		return false
	}

	// 2. Verify commitment
	saltBytes, err := hex.DecodeString(proof.Salt)
	if err != nil {
		return false
	}
	expectedCommitment := types.CreateCommitment(proof.Position, proof.CardValue, saltBytes)
	if expectedCommitment != proof.Commitment {
		return false
	}

	// 3. Verify Merkle proof
	if !types.VerifyMerkleProof(proof.Commitment, proof.MerkleProof, proof.CommitmentRoot, proof.Position) {
		return false
	}

	// 4. Verify VRF proof (if block hash provided)
	if blockHash != nil && proof.VRFProof != nil {
		valid, _, err := types.VerifyVRFProof(proof.VRFProof, blockHash)
		if err != nil || !valid {
			return false
		}
	}

	return true
}
