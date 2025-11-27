package types

import (
	"bytes"
	"testing"
)

func TestGenerateVRFKeypair(t *testing.T) {
	seed := []byte("test-seed-for-vrf-keypair-generation")

	keypair, err := GenerateVRFKeypair(seed)
	if err != nil {
		t.Fatalf("GenerateVRFKeypair failed: %v", err)
	}

	if keypair.PrivateKey == nil {
		t.Error("PrivateKey should not be nil")
	}

	if keypair.PublicKey == nil {
		t.Error("PublicKey should not be nil")
	}

	// Same seed should produce same keypair
	keypair2, _ := GenerateVRFKeypair(seed)
	if !bytes.Equal(keypair.PublicKey, keypair2.PublicKey) {
		t.Error("Same seed should produce same keypair")
	}

	// Different seed should produce different keypair
	keypair3, _ := GenerateVRFKeypair([]byte("different-seed"))
	if bytes.Equal(keypair.PublicKey, keypair3.PublicKey) {
		t.Error("Different seeds should produce different keypairs")
	}
}

func TestVRFProve(t *testing.T) {
	seed := []byte("test-vrf-seed")
	keypair, _ := GenerateVRFKeypair(seed)

	input := []byte("block-hash-input-data")

	proof, output, err := keypair.Prove(input)
	if err != nil {
		t.Fatalf("Prove failed: %v", err)
	}

	if proof.PublicKey == "" {
		t.Error("Proof PublicKey should not be empty")
	}

	if proof.Proof == "" {
		t.Error("Proof should not be empty")
	}

	if proof.Output == "" {
		t.Error("Proof Output should not be empty")
	}

	if len(output) != 32 {
		t.Errorf("VRF output should be 32 bytes, got %d", len(output))
	}

	// Same input should produce same output (deterministic)
	proof2, output2, _ := keypair.Prove(input)
	if proof.Output != proof2.Output {
		t.Error("Same input should produce same VRF output")
	}
	if !bytes.Equal(output, output2) {
		t.Error("Same input should produce same output bytes")
	}

	// Different input should produce different output
	proof3, _, _ := keypair.Prove([]byte("different-input"))
	if proof.Output == proof3.Output {
		t.Error("Different inputs should produce different VRF outputs")
	}
}

func TestVRFOutputToSeed(t *testing.T) {
	output := make([]byte, 32)
	for i := range output {
		output[i] = byte(i * 7)
	}

	seed := VRFOutputToSeed(output)

	if len(seed) != 52 {
		t.Errorf("Seed length = %d, want 52", len(seed))
	}

	// All values should be in range [0, 51]
	for i, v := range seed {
		if v < 0 || v >= 52 {
			t.Errorf("Seed[%d] = %d, should be in range [0, 51]", i, v)
		}
	}

	// Same output should produce same seed (deterministic)
	seed2 := VRFOutputToSeed(output)
	for i := range seed {
		if seed[i] != seed2[i] {
			t.Errorf("Seed not deterministic at position %d", i)
		}
	}
}

func TestShuffleWithVRF(t *testing.T) {
	zkDeck, _ := NewZKDeck("")

	seed := []byte("validator-vrf-seed")
	keypair, _ := GenerateVRFKeypair(seed)

	blockHash := []byte("mock-block-hash-for-testing")
	timestamp := int64(1234567890)

	err := zkDeck.ShuffleWithVRF(keypair, blockHash, timestamp)
	if err != nil {
		t.Fatalf("ShuffleWithVRF failed: %v", err)
	}

	// VRF proof should be set
	if zkDeck.VRF == nil {
		t.Fatal("VRF proof should be set")
	}

	if zkDeck.VRF.PublicKey == "" {
		t.Error("VRF PublicKey should not be empty")
	}

	if zkDeck.VRF.Proof == "" {
		t.Error("VRF Proof should not be empty")
	}

	if zkDeck.VRF.Output == "" {
		t.Error("VRF Output should not be empty")
	}

	// Commitments should be created
	if len(zkDeck.Commitments) != 52 {
		t.Errorf("Expected 52 commitments, got %d", len(zkDeck.Commitments))
	}

	// Commitment root should be set
	if zkDeck.CommitmentRoot == "" {
		t.Error("CommitmentRoot should not be empty")
	}
}

func TestVerifyShuffleVRF(t *testing.T) {
	zkDeck, _ := NewZKDeck("")

	seed := []byte("validator-seed")
	keypair, _ := GenerateVRFKeypair(seed)

	blockHash := []byte("block-hash")
	zkDeck.ShuffleWithVRF(keypair, blockHash, 0)

	// Verification with correct block hash should succeed
	valid, err := zkDeck.VerifyShuffleVRF(blockHash)
	if err != nil {
		t.Fatalf("VerifyShuffleVRF failed: %v", err)
	}
	if !valid {
		t.Error("VerifyShuffleVRF should return true for valid proof")
	}
}

func TestThresholdVRFShare(t *testing.T) {
	privateKeyShare := []byte("validator-private-key-share-32bytes")
	input := []byte("block-hash-input")
	shareIndex := 0

	share, err := GeneratePartialVRFProof(privateKeyShare, input, shareIndex)
	if err != nil {
		t.Fatalf("GeneratePartialVRFProof failed: %v", err)
	}

	if share.ShareIndex != shareIndex {
		t.Errorf("ShareIndex = %d, want %d", share.ShareIndex, shareIndex)
	}

	if share.PartialProof == "" {
		t.Error("PartialProof should not be empty")
	}

	if share.PublicKeyShare == "" {
		t.Error("PublicKeyShare should not be empty")
	}

	// Same inputs should produce same share
	share2, _ := GeneratePartialVRFProof(privateKeyShare, input, shareIndex)
	if share.PartialProof != share2.PartialProof {
		t.Error("Same inputs should produce same partial proof")
	}

	// Different index should produce different share
	share3, _ := GeneratePartialVRFProof(privateKeyShare, input, 1)
	if share.PartialProof == share3.PartialProof {
		t.Error("Different indices should produce different proofs")
	}
}

func TestCombineThresholdVRFShares(t *testing.T) {
	input := []byte("block-hash")
	threshold := 2

	// Generate shares from different validators
	shares := make([]ThresholdVRFShare, 3)
	for i := 0; i < 3; i++ {
		privateKeyShare := []byte("validator-" + string(rune('A'+i)) + "-private-key-share")
		share, _ := GeneratePartialVRFProof(privateKeyShare, input, i)
		share.ValidatorAddress = "validator" + string(rune('A'+i))
		shares[i] = *share
	}

	// Combine with threshold
	output, err := CombineThresholdVRFShares(shares, threshold)
	if err != nil {
		t.Fatalf("CombineThresholdVRFShares failed: %v", err)
	}

	if len(output) != 32 {
		t.Errorf("Combined output should be 32 bytes, got %d", len(output))
	}

	// Insufficient shares should fail
	_, err = CombineThresholdVRFShares(shares[:1], threshold)
	if err == nil {
		t.Error("Should fail with insufficient shares")
	}
}

func TestVRFDeterminism(t *testing.T) {
	// Same validator seed + same block hash = same shuffle
	validatorSeed := []byte("consistent-validator-seed")
	blockHash := []byte("consistent-block-hash")

	// First shuffle
	zkDeck1, _ := NewZKDeck("")
	keypair1, _ := GenerateVRFKeypair(validatorSeed)
	zkDeck1.ShuffleWithVRF(keypair1, blockHash, 1000)

	// Second shuffle with same inputs
	zkDeck2, _ := NewZKDeck("")
	keypair2, _ := GenerateVRFKeypair(validatorSeed)
	zkDeck2.ShuffleWithVRF(keypair2, blockHash, 1000)

	// VRF outputs should match
	if zkDeck1.VRF.Output != zkDeck2.VRF.Output {
		t.Error("Same inputs should produce same VRF output")
	}

	// Deck hashes should match
	if zkDeck1.Deck.Hash != zkDeck2.Deck.Hash {
		t.Error("Same VRF output should produce same deck shuffle")
	}

	// All cards should be in same positions
	for i := 0; i < 52; i++ {
		if zkDeck1.Deck.GetCards()[i].Value != zkDeck2.Deck.GetCards()[i].Value {
			t.Errorf("Card at position %d differs", i)
		}
	}
}

func TestAbsFunction(t *testing.T) {
	tests := []struct {
		input    int
		expected int
	}{
		{5, 5},
		{-5, 5},
		{0, 0},
		{-100, 100},
		{100, 100},
	}

	for _, tt := range tests {
		result := abs(tt.input)
		if result != tt.expected {
			t.Errorf("abs(%d) = %d, want %d", tt.input, result, tt.expected)
		}
	}
}
