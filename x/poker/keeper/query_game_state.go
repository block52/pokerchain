package keeper

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/bech32"
	"github.com/ethereum/go-ethereum/crypto"
	"golang.org/x/crypto/ripemd160"

	"github.com/block52/pokerchain/x/poker/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) GameState(ctx context.Context, req *types.QueryGameStateRequest) (*types.QueryGameStateResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	if req.GameId == "" {
		return nil, status.Error(codes.InvalidArgument, "game ID cannot be empty")
	}

	if req.PlayerAddress == "" {
		return nil, status.Error(codes.InvalidArgument, "player address cannot be empty")
	}

	if req.Timestamp == 0 {
		return nil, status.Error(codes.InvalidArgument, "timestamp cannot be empty")
	}

	if req.Signature == "" {
		return nil, status.Error(codes.InvalidArgument, "signature cannot be empty")
	}

	// Get the SDK context to access block time
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	blockTime := sdkCtx.BlockTime()

	// Validate timestamp is within 1 hour of block time
	requestTime := time.Unix(req.Timestamp, 0)
	timeDiff := blockTime.Sub(requestTime)
	if timeDiff < 0 {
		timeDiff = -timeDiff
	}
	if timeDiff > time.Hour {
		return nil, status.Errorf(codes.InvalidArgument, "timestamp must be within 1 hour of block time (block time: %s, request time: %s, diff: %s)",
			blockTime.Format(time.RFC3339), requestTime.Format(time.RFC3339), timeDiff)
	}

	// Verify the signature
	err := verifyCosmosSignature(req.PlayerAddress, req.Timestamp, req.Signature)
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "signature verification failed: %v", err)
	}

	// Get game state from keeper
	gameState, err := q.k.GameStates.Get(ctx, req.GameId)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "game state with ID %s not found", req.GameId)
	}

	// Mask cards that don't belong to the requesting player
	maskedGameState := maskOtherPlayersCards(gameState, req.PlayerAddress)

	// Convert game state to JSON string for response
	gameStateBytes, err := json.Marshal(maskedGameState)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize game state data")
	}

	return &types.QueryGameStateResponse{
		GameState: string(gameStateBytes),
	}, nil
}

// verifyCosmosSignature verifies that the signature was created by signing the timestamp
// with the private key corresponding to the given Cosmos address
func verifyCosmosSignature(cosmosAddress string, timestamp int64, signatureHex string) error {
	// Decode the Cosmos address to get the address bytes
	_, addressBytes, err := bech32.DecodeAndConvert(cosmosAddress)
	if err != nil {
		return fmt.Errorf("invalid cosmos address: %w", err)
	}

	// Remove 0x prefix if present in signature
	if len(signatureHex) > 2 && signatureHex[:2] == "0x" {
		signatureHex = signatureHex[2:]
	}

	// Decode signature from hex
	signatureBytes, err := hex.DecodeString(signatureHex)
	if err != nil {
		return fmt.Errorf("invalid signature hex: %w", err)
	}

	// Ethereum signatures are 65 bytes (r: 32, s: 32, v: 1)
	if len(signatureBytes) != 65 {
		return fmt.Errorf("invalid signature length: expected 65 bytes, got %d", len(signatureBytes))
	}

	// Create the message that should have been signed
	// Format: "pokerchain-query:<timestamp>"
	message := fmt.Sprintf("pokerchain-query:%d", timestamp)

	// Add Ethereum signed message prefix
	prefixedMessage := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(message), message)
	prefixedHash := crypto.Keccak256Hash([]byte(prefixedMessage))

	// Recover the public key from the signature
	// Note: The last byte (v) should be 0 or 1 for recovery
	if signatureBytes[64] >= 27 {
		signatureBytes[64] -= 27
	}

	recoveredPubKey, err := crypto.SigToPub(prefixedHash.Bytes(), signatureBytes)
	if err != nil {
		return fmt.Errorf("failed to recover public key: %w", err)
	}

	// Convert the recovered ECDSA public key to Cosmos address
	// Cosmos uses: RIPEMD160(SHA256(compressed_pubkey))
	// First, get the compressed public key bytes (33 bytes)
	compressedPubKey := crypto.CompressPubkey(recoveredPubKey)

	// Hash with SHA256
	sha256Hash := sha256.Sum256(compressedPubKey)

	// Hash with RIPEMD160
	ripemd160Hasher := ripemd160.New()
	ripemd160Hasher.Write(sha256Hash[:])
	recoveredCosmosAddress := ripemd160Hasher.Sum(nil)

	// Compare the Cosmos addresses
	if !bytesEqual(addressBytes, recoveredCosmosAddress) {
		return fmt.Errorf("signature does not match the provided address")
	}

	return nil
}

// bytesEqual compares two byte slices
func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// maskOtherPlayersCards replaces cards that don't belong to the requesting player with "X"
func maskOtherPlayersCards(gameState types.TexasHoldemStateDTO, playerAddress string) types.TexasHoldemStateDTO {
	// Create a copy of the game state to avoid modifying the original
	maskedState := gameState

	// Mask hole cards for all players except the requesting player
	maskedPlayers := make([]types.PlayerDTO, len(gameState.Players))
	for i, player := range gameState.Players {
		maskedPlayers[i] = player

		// If this is not the requesting player and they have hole cards, mask them
		if player.Address != playerAddress && player.HoleCards != nil {
			maskedCards := make([]string, len(*player.HoleCards))
			for j := range maskedCards {
				maskedCards[j] = "X"
			}
			maskedPlayers[i].HoleCards = &maskedCards
		}
	}

	maskedState.Players = maskedPlayers

	// Mask the deck (should never be visible to any player)
	maskedState.Deck = "X"

	return maskedState
}
