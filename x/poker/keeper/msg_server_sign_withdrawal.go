package keeper

import (
	"context"
	"encoding/hex"
	"fmt"

	"github.com/ethereum/go-ethereum/crypto"

	"github.com/block52/pokerchain/x/poker/types"
)

// SignWithdrawal handles MsgSignWithdrawal transactions.
// Allows validators to manually sign pending withdrawal requests by providing their Ethereum private key.
// This is a manual workaround until automatic signing is configured in EndBlocker.
func (ms msgServer) SignWithdrawal(ctx context.Context, msg *types.MsgSignWithdrawal) (*types.MsgSignWithdrawalResponse, error) {
	// Validate message (basic validation is done in ValidateBasic)
	if msg.Nonce == "" {
		return nil, fmt.Errorf("nonce cannot be empty")
	}

	if msg.ValidatorEthKeyHex == "" {
		return nil, fmt.Errorf("validator Ethereum key cannot be empty")
	}

	// Parse the Ethereum private key from hex
	// Remove 0x prefix if present
	keyHex := msg.ValidatorEthKeyHex
	if len(keyHex) > 2 && keyHex[:2] == "0x" {
		keyHex = keyHex[2:]
	}

	// Validate key length (should be 64 hex characters = 32 bytes)
	if len(keyHex) != 64 {
		return nil, fmt.Errorf("invalid Ethereum private key length: expected 64 hex characters, got %d", len(keyHex))
	}

	// Decode hex to bytes
	keyBytes, err := hex.DecodeString(keyHex)
	if err != nil {
		return nil, fmt.Errorf("failed to decode Ethereum private key: %w", err)
	}

	// Convert to ECDSA private key
	validatorPrivKey, err := crypto.ToECDSA(keyBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse Ethereum private key: %w", err)
	}

	// Call keeper to sign the withdrawal
	err = ms.Keeper.SignWithdrawal(ctx, msg.Nonce, validatorPrivKey)
	if err != nil {
		return nil, err
	}

	// Get the withdrawal request to return the signature
	request, err := ms.Keeper.getWithdrawalRequest(ctx, msg.Nonce)
	if err != nil {
		return nil, fmt.Errorf("failed to get withdrawal request after signing: %w", err)
	}

	return &types.MsgSignWithdrawalResponse{
		Signature: request.Signature,
	}, nil
}
