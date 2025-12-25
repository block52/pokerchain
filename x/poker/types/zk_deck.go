package types

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"

	"golang.org/x/crypto/curve25519"
)

const (
	// SaltLength is the length of random salt for commitments (32 bytes)
	SaltLength = 32
	// CommitmentPrefix is used to domain-separate commitments
	CommitmentPrefix = "pokerchain-card-commitment-v1"
)

// CardCommitment represents a cryptographic commitment to a card
// Commitment = SHA256(prefix || position || card_value || salt)
type CardCommitment struct {
	Position   int    `json:"position"`   // Position in the shuffled deck (0-51)
	Commitment string `json:"commitment"` // Hex-encoded SHA256 hash
	Salt       string `json:"salt"`       // Hex-encoded 32-byte random salt (revealed when card is dealt)
	Revealed   bool   `json:"revealed"`   // Whether this card has been revealed
	CardValue  int    `json:"card_value"` // Only set when revealed (-1 until revealed)
}

// VRFProof represents a Verifiable Random Function proof for shuffle fairness
type VRFProof struct {
	PublicKey  string `json:"public_key"`  // Hex-encoded VRF public key
	Proof      string `json:"proof"`       // Hex-encoded VRF proof
	Output     string `json:"output"`      // Hex-encoded VRF output (used as shuffle seed)
	InputHash  string `json:"input_hash"`  // The input to VRF (block hash)
	Verified   bool   `json:"verified"`    // Whether the proof has been verified
}

// EncryptedCard represents a card encrypted for a specific player
type EncryptedCard struct {
	Position         int    `json:"position"`          // Position in deck
	PlayerAddress    string `json:"player_address"`    // Cosmos address of the player
	EncryptedValue   string `json:"encrypted_value"`   // Hex-encoded encrypted card value
	Nonce            string `json:"nonce"`             // Hex-encoded encryption nonce
	EphemeralPubKey  string `json:"ephemeral_pub_key"` // Hex-encoded ephemeral public key for ECDH
}

// ZKDeck extends Deck with zero-knowledge properties
type ZKDeck struct {
	*Deck
	Commitments      []CardCommitment  `json:"commitments"`       // Commitments for all 52 cards
	VRF              *VRFProof         `json:"vrf,omitempty"`     // VRF proof for shuffle fairness
	EncryptedCards   []EncryptedCard   `json:"encrypted_cards"`   // Player-specific encrypted cards
	CommitmentRoot   string            `json:"commitment_root"`   // Merkle root of all commitments
	ShuffleTimestamp int64             `json:"shuffle_timestamp"` // When the deck was shuffled
}

// NewZKDeck creates a new zero-knowledge deck
func NewZKDeck(deckStr string) (*ZKDeck, error) {
	deck, err := NewDeck(deckStr)
	if err != nil {
		return nil, err
	}

	return &ZKDeck{
		Deck:           deck,
		Commitments:    make([]CardCommitment, 0),
		EncryptedCards: make([]EncryptedCard, 0),
	}, nil
}

// GenerateSalt generates a cryptographically secure random salt
func GenerateSalt() ([]byte, error) {
	salt := make([]byte, SaltLength)
	_, err := rand.Read(salt)
	if err != nil {
		return nil, fmt.Errorf("failed to generate random salt: %w", err)
	}
	return salt, nil
}

// CreateCommitment creates a commitment for a card at a given position
// Commitment = SHA256(prefix || position || card_value || salt)
func CreateCommitment(position int, cardValue int, salt []byte) string {
	data := fmt.Sprintf("%s:%d:%d:%s", CommitmentPrefix, position, cardValue, hex.EncodeToString(salt))
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

// VerifyCommitment verifies that a revealed card matches its commitment
func VerifyCommitment(commitment string, position int, cardValue int, salt string) bool {
	saltBytes, err := hex.DecodeString(salt)
	if err != nil {
		return false
	}

	expectedCommitment := CreateCommitment(position, cardValue, saltBytes)
	return commitment == expectedCommitment
}

// ShuffleWithCommitments shuffles the deck and creates commitments for all cards
func (zk *ZKDeck) ShuffleWithCommitments(seed []int, timestamp int64) error {
	// First, perform the standard shuffle
	zk.Deck.Shuffle(seed)
	zk.ShuffleTimestamp = timestamp

	// Generate commitments for all 52 cards
	zk.Commitments = make([]CardCommitment, 52)

	for i := 0; i < 52; i++ {
		salt, err := GenerateSalt()
		if err != nil {
			return fmt.Errorf("failed to generate salt for card %d: %w", i, err)
		}

		cardValue := zk.Deck.cards[i].Value
		commitment := CreateCommitment(i, cardValue, salt)

		zk.Commitments[i] = CardCommitment{
			Position:   i,
			Commitment: commitment,
			Salt:       hex.EncodeToString(salt),
			Revealed:   false,
			CardValue:  -1, // Not revealed yet
		}
	}

	// Create Merkle root of all commitments
	zk.CommitmentRoot = zk.computeCommitmentRoot()

	return nil
}

// computeCommitmentRoot computes a Merkle root of all card commitments
func (zk *ZKDeck) computeCommitmentRoot() string {
	if len(zk.Commitments) == 0 {
		return ""
	}

	// Collect all commitment hashes
	hashes := make([]string, len(zk.Commitments))
	for i, c := range zk.Commitments {
		hashes[i] = c.Commitment
	}

	// Build Merkle tree
	for len(hashes) > 1 {
		var newLevel []string
		for i := 0; i < len(hashes); i += 2 {
			var combined string
			if i+1 < len(hashes) {
				combined = hashes[i] + hashes[i+1]
			} else {
				combined = hashes[i] + hashes[i] // Duplicate last if odd
			}
			hash := sha256.Sum256([]byte(combined))
			newLevel = append(newLevel, hex.EncodeToString(hash[:]))
		}
		hashes = newLevel
	}

	return hashes[0]
}

// RevealCard reveals a card at the given position, returning the card and proof
func (zk *ZKDeck) RevealCard(position int) (*Card, *CardCommitment, error) {
	if position < 0 || position >= 52 {
		return nil, nil, fmt.Errorf("invalid card position: %d", position)
	}

	if position >= len(zk.Commitments) {
		return nil, nil, fmt.Errorf("no commitment for position %d", position)
	}

	// Mark as revealed
	zk.Commitments[position].Revealed = true
	zk.Commitments[position].CardValue = zk.Deck.cards[position].Value

	card := zk.Deck.cards[position]
	commitment := zk.Commitments[position]

	return &card, &commitment, nil
}

// GetNextWithProof deals the next card and returns its commitment proof
func (zk *ZKDeck) GetNextWithProof() (*Card, *CardCommitment, error) {
	position := zk.Deck.top
	if position >= 52 {
		return nil, nil, fmt.Errorf("deck exhausted")
	}

	card, commitment, err := zk.RevealCard(position)
	if err != nil {
		return nil, nil, err
	}

	zk.Deck.top++
	return card, commitment, nil
}

// GetCommitmentsOnly returns only the commitments without salts (for public viewing)
func (zk *ZKDeck) GetCommitmentsOnly() []string {
	commitments := make([]string, len(zk.Commitments))
	for i, c := range zk.Commitments {
		commitments[i] = c.Commitment
	}
	return commitments
}

// VerifyDeckIntegrity verifies that all revealed cards match their commitments
func (zk *ZKDeck) VerifyDeckIntegrity() error {
	for i, c := range zk.Commitments {
		if c.Revealed {
			if !VerifyCommitment(c.Commitment, c.Position, c.CardValue, c.Salt) {
				return fmt.Errorf("card at position %d failed commitment verification", i)
			}
		}
	}
	return nil
}

// EncryptCardForPlayer encrypts a card for a specific player using ECDH
// playerPubKey should be a 32-byte Curve25519 public key (hex-encoded)
func (zk *ZKDeck) EncryptCardForPlayer(position int, playerAddress string, playerPubKey string) (*EncryptedCard, error) {
	if position < 0 || position >= 52 {
		return nil, fmt.Errorf("invalid card position: %d", position)
	}

	pubKeyBytes, err := hex.DecodeString(playerPubKey)
	if err != nil {
		return nil, fmt.Errorf("invalid player public key: %w", err)
	}

	if len(pubKeyBytes) != 32 {
		return nil, fmt.Errorf("public key must be 32 bytes, got %d", len(pubKeyBytes))
	}

	// Generate ephemeral keypair for ECDH
	var ephemeralPrivate, ephemeralPublic [32]byte
	if _, err := rand.Read(ephemeralPrivate[:]); err != nil {
		return nil, fmt.Errorf("failed to generate ephemeral key: %w", err)
	}
	curve25519.ScalarBaseMult(&ephemeralPublic, &ephemeralPrivate)

	// Perform ECDH to get shared secret
	var sharedSecret [32]byte
	var playerPubKeyArr [32]byte
	copy(playerPubKeyArr[:], pubKeyBytes)
	curve25519.ScalarMult(&sharedSecret, &ephemeralPrivate, &playerPubKeyArr)

	// Derive encryption key from shared secret
	encryptionKey := sha256.Sum256(append(sharedSecret[:], []byte("pokerchain-card-encryption")...))

	// Generate nonce
	nonce := make([]byte, 12)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("failed to generate nonce: %w", err)
	}

	// Encrypt card value (simple XOR with derived key for demo - use AES-GCM in production)
	cardValue := zk.Deck.cards[position].Value
	cardBytes := []byte(fmt.Sprintf("%02d", cardValue))
	encrypted := make([]byte, len(cardBytes))
	for i := range cardBytes {
		encrypted[i] = cardBytes[i] ^ encryptionKey[i%32]
	}

	encryptedCard := &EncryptedCard{
		Position:        position,
		PlayerAddress:   playerAddress,
		EncryptedValue:  hex.EncodeToString(encrypted),
		Nonce:           hex.EncodeToString(nonce),
		EphemeralPubKey: hex.EncodeToString(ephemeralPublic[:]),
	}

	zk.EncryptedCards = append(zk.EncryptedCards, *encryptedCard)
	return encryptedCard, nil
}

// DecryptCard decrypts a card using the player's private key
// playerPrivKey should be a 32-byte Curve25519 private key
func DecryptCard(encryptedCard *EncryptedCard, playerPrivKey []byte) (int, error) {
	if len(playerPrivKey) != 32 {
		return -1, fmt.Errorf("private key must be 32 bytes")
	}

	ephemeralPubKeyBytes, err := hex.DecodeString(encryptedCard.EphemeralPubKey)
	if err != nil {
		return -1, fmt.Errorf("invalid ephemeral public key: %w", err)
	}

	// Perform ECDH to recover shared secret
	var sharedSecret [32]byte
	var privKeyArr, ephemeralPubKeyArr [32]byte
	copy(privKeyArr[:], playerPrivKey)
	copy(ephemeralPubKeyArr[:], ephemeralPubKeyBytes)
	curve25519.ScalarMult(&sharedSecret, &privKeyArr, &ephemeralPubKeyArr)

	// Derive decryption key
	decryptionKey := sha256.Sum256(append(sharedSecret[:], []byte("pokerchain-card-encryption")...))

	// Decrypt
	encryptedBytes, err := hex.DecodeString(encryptedCard.EncryptedValue)
	if err != nil {
		return -1, fmt.Errorf("invalid encrypted value: %w", err)
	}

	decrypted := make([]byte, len(encryptedBytes))
	for i := range encryptedBytes {
		decrypted[i] = encryptedBytes[i] ^ decryptionKey[i%32]
	}

	// Parse card value
	var cardValue int
	_, err = fmt.Sscanf(string(decrypted), "%02d", &cardValue)
	if err != nil {
		return -1, fmt.Errorf("failed to parse decrypted card value: %w", err)
	}

	return cardValue, nil
}

// ToZKString serializes the ZK deck state (without secrets)
func (zk *ZKDeck) ToZKString() string {
	var parts []string

	// Add basic deck info
	parts = append(parts, fmt.Sprintf("root:%s", zk.CommitmentRoot))
	parts = append(parts, fmt.Sprintf("hash:%s", zk.Deck.Hash))
	parts = append(parts, fmt.Sprintf("seed_hash:%s", zk.Deck.SeedHash))
	parts = append(parts, fmt.Sprintf("top:%d", zk.Deck.top))
	parts = append(parts, fmt.Sprintf("timestamp:%d", zk.ShuffleTimestamp))

	// Add revealed cards only
	var revealed []string
	for _, c := range zk.Commitments {
		if c.Revealed {
			revealed = append(revealed, fmt.Sprintf("%d:%d:%s", c.Position, c.CardValue, c.Salt))
		}
	}
	parts = append(parts, fmt.Sprintf("revealed:[%s]", strings.Join(revealed, ",")))

	return strings.Join(parts, "|")
}

// GetMerkleProof returns a Merkle proof for a card at the given position
func (zk *ZKDeck) GetMerkleProof(position int) ([]string, error) {
	if position < 0 || position >= len(zk.Commitments) {
		return nil, fmt.Errorf("invalid position: %d", position)
	}

	// Collect all commitment hashes
	hashes := make([]string, len(zk.Commitments))
	for i, c := range zk.Commitments {
		hashes[i] = c.Commitment
	}

	var proof []string
	currentIndex := position

	// Build proof path up the tree
	for len(hashes) > 1 {
		var newLevel []string
		for i := 0; i < len(hashes); i += 2 {
			siblingIndex := -1
			if i == currentIndex || i+1 == currentIndex {
				// This pair contains our target
				if currentIndex%2 == 0 && i+1 < len(hashes) {
					siblingIndex = i + 1
				} else if currentIndex%2 == 1 {
					siblingIndex = i
				}
			}

			if siblingIndex >= 0 && siblingIndex < len(hashes) {
				proof = append(proof, fmt.Sprintf("%d:%s", siblingIndex%2, hashes[siblingIndex]))
			}

			var combined string
			if i+1 < len(hashes) {
				combined = hashes[i] + hashes[i+1]
			} else {
				combined = hashes[i] + hashes[i]
			}
			hash := sha256.Sum256([]byte(combined))
			newLevel = append(newLevel, hex.EncodeToString(hash[:]))
		}
		hashes = newLevel
		currentIndex = currentIndex / 2
	}

	return proof, nil
}

// VerifyMerkleProof verifies a card's commitment against the Merkle root
func VerifyMerkleProof(commitment string, proof []string, root string, position int) bool {
	current := commitment

	for _, p := range proof {
		var side int
		var sibling string
		_, err := fmt.Sscanf(p, "%d:%s", &side, &sibling)
		if err != nil {
			return false
		}

		var combined string
		if side == 0 {
			combined = sibling + current
		} else {
			combined = current + sibling
		}
		hash := sha256.Sum256([]byte(combined))
		current = hex.EncodeToString(hash[:])
	}

	return current == root
}
