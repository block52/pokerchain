package types

import (
	"crypto/rand"
	"encoding/hex"
	"testing"
)

func TestGenerateSalt(t *testing.T) {
	salt, err := GenerateSalt()
	if err != nil {
		t.Fatalf("GenerateSalt failed: %v", err)
	}

	if len(salt) != SaltLength {
		t.Errorf("Salt length = %d, want %d", len(salt), SaltLength)
	}

	// Test uniqueness
	salt2, _ := GenerateSalt()
	if hex.EncodeToString(salt) == hex.EncodeToString(salt2) {
		t.Error("Two generated salts should not be identical")
	}
}

func TestCreateAndVerifyCommitment(t *testing.T) {
	salt, _ := GenerateSalt()
	position := 5
	cardValue := 42

	commitment := CreateCommitment(position, cardValue, salt)

	// Verify correct values
	if !VerifyCommitment(commitment, position, cardValue, hex.EncodeToString(salt)) {
		t.Error("VerifyCommitment failed for correct values")
	}

	// Verify wrong position fails
	if VerifyCommitment(commitment, position+1, cardValue, hex.EncodeToString(salt)) {
		t.Error("VerifyCommitment should fail for wrong position")
	}

	// Verify wrong card value fails
	if VerifyCommitment(commitment, position, cardValue+1, hex.EncodeToString(salt)) {
		t.Error("VerifyCommitment should fail for wrong card value")
	}

	// Verify wrong salt fails
	wrongSalt, _ := GenerateSalt()
	if VerifyCommitment(commitment, position, cardValue, hex.EncodeToString(wrongSalt)) {
		t.Error("VerifyCommitment should fail for wrong salt")
	}
}

func TestNewZKDeck(t *testing.T) {
	zkDeck, err := NewZKDeck("")
	if err != nil {
		t.Fatalf("NewZKDeck failed: %v", err)
	}

	if zkDeck.Deck == nil {
		t.Error("ZKDeck.Deck should not be nil")
	}

	if len(zkDeck.Commitments) != 0 {
		t.Error("Initial commitments should be empty")
	}
}

func TestShuffleWithCommitments(t *testing.T) {
	zkDeck, _ := NewZKDeck("")

	// Create deterministic seed for testing
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 7 % 52
	}

	timestamp := int64(1234567890)
	err := zkDeck.ShuffleWithCommitments(seed, timestamp)
	if err != nil {
		t.Fatalf("ShuffleWithCommitments failed: %v", err)
	}

	// Verify commitments were created
	if len(zkDeck.Commitments) != 52 {
		t.Errorf("Expected 52 commitments, got %d", len(zkDeck.Commitments))
	}

	// Verify each commitment has a salt
	for i, c := range zkDeck.Commitments {
		if c.Salt == "" {
			t.Errorf("Card %d has empty salt", i)
		}
		if c.Commitment == "" {
			t.Errorf("Card %d has empty commitment", i)
		}
		if c.Revealed {
			t.Errorf("Card %d should not be revealed initially", i)
		}
	}

	// Verify commitment root was created
	if zkDeck.CommitmentRoot == "" {
		t.Error("CommitmentRoot should not be empty")
	}

	// Verify timestamp was set
	if zkDeck.ShuffleTimestamp != timestamp {
		t.Errorf("ShuffleTimestamp = %d, want %d", zkDeck.ShuffleTimestamp, timestamp)
	}
}

func TestRevealCard(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 7 % 52
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	// Reveal a card
	position := 10
	card, commitment, err := zkDeck.RevealCard(position)
	if err != nil {
		t.Fatalf("RevealCard failed: %v", err)
	}

	if card == nil {
		t.Fatal("Revealed card should not be nil")
	}

	if commitment == nil {
		t.Fatal("Commitment should not be nil")
	}

	if !commitment.Revealed {
		t.Error("Commitment should be marked as revealed")
	}

	if commitment.CardValue != card.Value {
		t.Errorf("Commitment card value = %d, want %d", commitment.CardValue, card.Value)
	}

	// Verify the commitment
	if !VerifyCommitment(commitment.Commitment, position, card.Value, commitment.Salt) {
		t.Error("Revealed card should verify against its commitment")
	}
}

func TestGetNextWithProof(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 7 % 52
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	// Deal several cards
	for i := 0; i < 5; i++ {
		card, commitment, err := zkDeck.GetNextWithProof()
		if err != nil {
			t.Fatalf("GetNextWithProof failed on card %d: %v", i, err)
		}

		// Verify commitment matches
		if !VerifyCommitment(commitment.Commitment, i, card.Value, commitment.Salt) {
			t.Errorf("Card %d failed commitment verification", i)
		}
	}

	// Verify top position advanced
	if zkDeck.Deck.GetTop() != 5 {
		t.Errorf("Deck top = %d, want 5", zkDeck.Deck.GetTop())
	}
}

func TestGetCommitmentsOnly(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	commitments := zkDeck.GetCommitmentsOnly()

	if len(commitments) != 52 {
		t.Errorf("Expected 52 commitments, got %d", len(commitments))
	}

	// Verify no salts are leaked
	for i, c := range commitments {
		// Commitment is a 64-char hex string (32 bytes)
		if len(c) != 64 {
			t.Errorf("Commitment %d has wrong length: %d", i, len(c))
		}
	}
}

func TestVerifyDeckIntegrity(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 3 % 52
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	// Reveal some cards
	for i := 0; i < 10; i++ {
		zkDeck.GetNextWithProof()
	}

	// Verify integrity
	err := zkDeck.VerifyDeckIntegrity()
	if err != nil {
		t.Errorf("VerifyDeckIntegrity failed: %v", err)
	}
}

func TestMerkleProof(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	// Get Merkle proof for a position
	position := 25
	proof, err := zkDeck.GetMerkleProof(position)
	if err != nil {
		t.Fatalf("GetMerkleProof failed: %v", err)
	}

	// Proof should have log2(52) ≈ 6 elements
	if len(proof) < 5 || len(proof) > 7 {
		t.Errorf("Merkle proof has unexpected length: %d", len(proof))
	}

	// Verify the proof
	commitment := zkDeck.Commitments[position].Commitment
	verified := VerifyMerkleProof(commitment, proof, zkDeck.CommitmentRoot, position)
	if !verified {
		t.Error("Merkle proof verification failed")
	}
}

func TestEncryptCardForPlayer(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i
	}
	zkDeck.ShuffleWithCommitments(seed, 0)

	// Generate a test keypair
	privateKey := make([]byte, 32)
	rand.Read(privateKey)

	// Clamp for Curve25519
	privateKey[0] &= 248
	privateKey[31] &= 127
	privateKey[31] |= 64

	// For testing, use the private key as public key (not cryptographically correct)
	// In production, use curve25519.ScalarBaseMult
	publicKey := make([]byte, 32)
	copy(publicKey, privateKey)

	playerAddress := "cosmos1abc123"
	position := 0

	encryptedCard, err := zkDeck.EncryptCardForPlayer(position, playerAddress, hex.EncodeToString(publicKey))
	if err != nil {
		t.Fatalf("EncryptCardForPlayer failed: %v", err)
	}

	if encryptedCard.PlayerAddress != playerAddress {
		t.Errorf("Player address = %s, want %s", encryptedCard.PlayerAddress, playerAddress)
	}

	if encryptedCard.Position != position {
		t.Errorf("Position = %d, want %d", encryptedCard.Position, position)
	}

	if encryptedCard.EncryptedValue == "" {
		t.Error("EncryptedValue should not be empty")
	}

	if encryptedCard.EphemeralPubKey == "" {
		t.Error("EphemeralPubKey should not be empty")
	}
}

func TestZKDeckDeterminism(t *testing.T) {
	// Two decks with same seed should have same shuffle
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i * 11 % 52
	}

	zkDeck1, _ := NewZKDeck("")
	zkDeck2, _ := NewZKDeck("")

	zkDeck1.ShuffleWithCommitments(seed, 1000)
	zkDeck2.ShuffleWithCommitments(seed, 1000)

	// Deck hashes should match
	if zkDeck1.Deck.Hash != zkDeck2.Deck.Hash {
		t.Error("Decks with same seed should have same hash")
	}

	// Cards should be in same order
	for i := 0; i < 52; i++ {
		if zkDeck1.Deck.GetCards()[i].Value != zkDeck2.Deck.GetCards()[i].Value {
			t.Errorf("Card %d differs between decks", i)
		}
	}

	// Commitments will differ due to random salts (this is expected and desired)
	if zkDeck1.CommitmentRoot == zkDeck2.CommitmentRoot {
		t.Error("Commitment roots should differ due to different random salts")
	}
}

func TestToZKString(t *testing.T) {
	zkDeck, _ := NewZKDeck("")
	seed := make([]int, 52)
	for i := range seed {
		seed[i] = i
	}
	zkDeck.ShuffleWithCommitments(seed, 12345)

	// Reveal some cards
	zkDeck.GetNextWithProof()
	zkDeck.GetNextWithProof()

	str := zkDeck.ToZKString()

	// Should contain key fields
	if str == "" {
		t.Error("ZKString should not be empty")
	}

	// Should contain root
	if !contains(str, "root:") {
		t.Error("ZKString should contain commitment root")
	}

	// Should contain timestamp
	if !contains(str, "timestamp:12345") {
		t.Error("ZKString should contain timestamp")
	}

	// Should contain revealed cards info
	if !contains(str, "revealed:") {
		t.Error("ZKString should contain revealed cards")
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
