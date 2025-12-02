package keeper

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/block52/pokerchain/x/poker/types"
)

// SignGameState signs a game state with the validator's Ethereum private key.
// Returns the game state with signature and validator address populated.
// If the validator is read-only (not producing blocks), returns the original state unsigned.
func (k Keeper) SignGameState(ctx context.Context, gameState *types.TexasHoldemStateDTO, gameId string) (*types.TexasHoldemStateDTO, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Check if this validator should sign (only active validators producing blocks should sign)
	shouldSign, err := k.shouldValidatorSign(sdkCtx)
	if err != nil {
		sdkCtx.Logger().Warn("Failed to determine if validator should sign", "error", err)
		return gameState, nil // Return unsigned state on error
	}

	if !shouldSign {
		sdkCtx.Logger().Debug("Validator is read-only, skipping signature")
		return gameState, nil
	}

	// Get validator's ETH private key from keeper config
	privKeyHex := k.GetValidatorEthPrivateKey()
	if privKeyHex == "" {
		sdkCtx.Logger().Debug("Validator ETH private key not configured, skipping signature")
		return gameState, nil
	}

	// Parse the private key
	privKeyBytes, err := hex.DecodeString(privKeyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid ETH private key format: %w", err)
	}

	if len(privKeyBytes) != 32 {
		return nil, fmt.Errorf("invalid ETH private key length: expected 32 bytes, got %d", len(privKeyBytes))
	}

	validatorPrivKey, err := crypto.ToECDSA(privKeyBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ETH private key: %w", err)
	}

	// Get validator's Ethereum address
	validatorAddr := crypto.PubkeyToAddress(validatorPrivKey.PublicKey)

	// Create canonical representation for signing
	message, err := k.createGameStateSignatureMessage(gameState, gameId)
	if err != nil {
		return nil, fmt.Errorf("failed to create signature message: %w", err)
	}

	messageHash := crypto.Keccak256Hash(message)

	// Add Ethereum signed message prefix (EIP-191)
	// This matches what Ethereum contracts expect: keccak256("\x19Ethereum Signed Message:\n32", messageHash)
	prefix := []byte("\x19Ethereum Signed Message:\n32")
	prefixedMessage := append(prefix, messageHash.Bytes()...)
	prefixedHash := crypto.Keccak256Hash(prefixedMessage)

	// Sign the hash
	signature, err := crypto.Sign(prefixedHash.Bytes(), validatorPrivKey)
	if err != nil {
		return nil, fmt.Errorf("failed to sign game state: %w", err)
	}

	// Adjust recovery ID for Ethereum compatibility (v = 27 + v)
	if signature[64] < 27 {
		signature[64] += 27
	}

	// Create signed copy
	signedState := *gameState
	signedState.ValidatorSignature = "0x" + hex.EncodeToString(signature)
	signedState.ValidatorAddress = validatorAddr.Hex()

	sdkCtx.Logger().Info("Game state signed",
		"gameId", gameId,
		"validator", validatorAddr.Hex(),
		"messageHash", messageHash.Hex(),
		"actionCount", gameState.ActionCount,
	)

	return &signedState, nil
}

// createGameStateSignatureMessage creates a canonical byte representation
// of the game state for signing. This must be deterministic across all validators.
func (k Keeper) createGameStateSignatureMessage(gameState *types.TexasHoldemStateDTO, gameId string) ([]byte, error) {
	// Create deterministic message from critical game state fields
	// Format: gameId (32 bytes) || actionCount (32 bytes) || pot (32 bytes) || round (32 bytes) || playersHash (32 bytes)
	var message []byte

	// Add game ID (32 bytes, right-padded)
	message = append(message, common.RightPadBytes([]byte(gameId), 32)...)

	// Add action count (32 bytes, big-endian uint64)
	actionCountBytes := make([]byte, 32)
	actionCount := uint64(gameState.ActionCount)
	for i := 0; i < 8; i++ {
		actionCountBytes[24+i] = byte(actionCount >> (8 * (7 - i)))
	}
	message = append(message, actionCountBytes...)

	// Add pot (first pot if available, otherwise "0")
	pot := "0"
	if len(gameState.Pots) > 0 {
		pot = gameState.Pots[0]
	}
	potBytes := common.RightPadBytes([]byte(pot), 32)
	message = append(message, potBytes...)

	// Add round (32 bytes, right-padded)
	roundBytes := common.RightPadBytes([]byte(gameState.Round), 32)
	message = append(message, roundBytes...)

	// Add players array hash (keccak256 of JSON-encoded players)
	// This ensures any player state changes affect the signature
	playersJson, err := json.Marshal(gameState.Players)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal players: %w", err)
	}
	playersHash := crypto.Keccak256Hash(playersJson)
	message = append(message, playersHash.Bytes()...)

	return message, nil
}

// shouldValidatorSign determines if this validator should sign game states.
// Returns true only if the validator is actively producing blocks (not read-only).
func (k Keeper) shouldValidatorSign(ctx sdk.Context) (bool, error) {
	// Get the validator set from consensus state
	validatorAddr := ctx.BlockHeader().ProposerAddress

	// If there's no proposer (e.g., in tests), don't sign
	if len(validatorAddr) == 0 {
		return false, nil
	}

	// Check if this node is the current proposer or part of the active validator set
	// For now, we determine signing eligibility by checking if we have a validator key configured
	// A read-only node would not have the validator ETH key configured

	// Additional check: Ensure we're not in replay mode
	// During state sync or replay, we shouldn't sign
	if ctx.BlockHeight() == 0 {
		return false, nil
	}

	// If validator ETH key is configured, this is an active validator
	if k.GetValidatorEthPrivateKey() != "" {
		return true, nil
	}

	return false, nil
}
