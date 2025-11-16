package keeper

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"strings"

	"cosmossdk.io/math"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/block52/pokerchain/x/poker/types"
)

// Withdrawal configuration constants
const (
	// WITHDRAWAL_FEE_PERCENT is the fee charged on withdrawals (0 = no fee, can be changed here)
	WITHDRAWAL_FEE_PERCENT = 0.0

	// USDC denomination for this chain
	USDC_DENOM = "usdc"

	// WithdrawalStatusPending means withdrawal request created, awaiting signature
	WithdrawalStatusPending = "pending"

	// WithdrawalStatusSigned means validator has signed, ready for Base completion
	WithdrawalStatusSigned = "signed"

	// WithdrawalStatusCompleted means withdrawal completed on Base chain
	WithdrawalStatusCompleted = "completed"
)

// InitiateWithdrawal burns USDC on Cosmos and creates a withdrawal request
// that can be completed on Base chain with a validator signature.
//
// Flow:
// 1. Validate inputs (amount, Base address format)
// 2. Check user has sufficient balance
// 3. Generate unique nonce
// 4. Burn USDC from user account
// 5. Create withdrawal request with "pending" status
// 6. Store in state
// 7. Return nonce for tracking
func (k Keeper) InitiateWithdrawal(ctx context.Context, creator string, baseAddress string, amount uint64) (string, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Validate Base/Ethereum address format
	if !strings.HasPrefix(baseAddress, "0x") || len(baseAddress) != 42 {
		return "", fmt.Errorf("invalid Base address format: must be 0x... (42 characters)")
	}

	// Validate it's a valid Ethereum address
	if !common.IsHexAddress(baseAddress) {
		return "", fmt.Errorf("invalid Base address: %s", baseAddress)
	}

	// Validate amount
	if amount == 0 {
		return "", fmt.Errorf("withdrawal amount must be greater than 0")
	}

	// Check user balance
	creatorAddr, err := k.addressCodec.StringToBytes(creator)
	if err != nil {
		return "", fmt.Errorf("invalid creator address: %w", err)
	}

	spendableCoins := k.bankKeeper.SpendableCoins(sdkCtx, creatorAddr)
	usdcBalance := spendableCoins.AmountOf(USDC_DENOM)
	if usdcBalance.Uint64() < amount {
		return "", fmt.Errorf("insufficient balance: have %d, need %d", usdcBalance.Uint64(), amount)
	}

	// Generate unique nonce
	// First, check current sequence value (for debugging)
	currentSeq, err := k.WithdrawalNonce.Peek(sdkCtx)
	if err != nil {
		sdkCtx.Logger().Info("⚠️ Could not peek at current nonce sequence", "error", err)
	} else {
		sdkCtx.Logger().Info("🔢 Current withdrawal nonce sequence (before Next)", "currentSeq", currentSeq)
	}

	nonceSeq, err := k.WithdrawalNonce.Next(sdkCtx)
	if err != nil {
		return "", fmt.Errorf("failed to generate nonce: %w", err)
	}

	// Sequences start at 0, but we want nonces to start at 1
	// This prevents the first withdrawal from having an all-zeros nonce
	nonceSeq = nonceSeq + 1

	// Log the nonce sequence for debugging
	sdkCtx.Logger().Info("🔢 Generated withdrawal nonce (after Next + 1)",
		"nonceSeq", nonceSeq,
		"creator", creator,
		"baseAddress", baseAddress,
		"amount", amount,
	)

	// Format nonce as hex string (32 bytes for Base contract compatibility)
	nonce := fmt.Sprintf("0x%064x", nonceSeq)

	sdkCtx.Logger().Info("🔢 Formatted nonce as hex", "nonce", nonce)

	// Burn USDC from creator
	burnCoins := sdk.NewCoins(sdk.NewCoin(USDC_DENOM, math.NewIntFromUint64(amount)))
	if err := k.bankKeeper.SendCoinsFromAccountToModule(sdkCtx, creatorAddr, types.ModuleName, burnCoins); err != nil {
		return "", fmt.Errorf("failed to transfer USDC: %w", err)
	}

	if err := k.bankKeeper.BurnCoins(sdkCtx, types.ModuleName, burnCoins); err != nil {
		return "", fmt.Errorf("failed to burn USDC: %w", err)
	}

	// Create withdrawal request
	withdrawalRequest := types.WithdrawalRequest{
		Nonce:         nonce,
		CosmosAddress: creator,
		BaseAddress:   baseAddress,
		Amount:        amount,
		Status:        WithdrawalStatusPending,
		Signature:     nil, // Will be filled by EndBlocker
		CreatedAt:     sdkCtx.BlockTime().Unix(),
		CompletedAt:   0,
	}

	// Store withdrawal request
	if err := k.WithdrawalRequests.Set(sdkCtx, nonce, withdrawalRequest); err != nil {
		return "", fmt.Errorf("failed to store withdrawal request: %w", err)
	}

	// Emit event
	sdkCtx.EventManager().EmitEvent(
		sdk.NewEvent(
			"withdrawal_initiated",
			sdk.NewAttribute("creator", creator),
			sdk.NewAttribute("nonce", nonce),
			sdk.NewAttribute("amount", fmt.Sprintf("%d", amount)),
			sdk.NewAttribute("base_address", baseAddress),
		),
	)

	return nonce, nil
}

// SignWithdrawal generates a validator signature for a withdrawal request.
// This is called automatically by EndBlocker for all pending withdrawals.
//
// Signature format (compatible with Base CosmosBridge contract):
// - Message: keccak256(abi.encodePacked(receiver, amount, nonce))
// - Signer: Validator's Ethereum private key
func (k Keeper) SignWithdrawal(ctx context.Context, nonce string, validatorPrivKey *ecdsa.PrivateKey) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Get withdrawal request
	request, err := k.WithdrawalRequests.Get(sdkCtx, nonce)
	if err != nil {
		return fmt.Errorf("withdrawal request not found: %w", err)
	}

	// Skip if already signed
	if request.Status == WithdrawalStatusSigned || request.Status == WithdrawalStatusCompleted {
		return nil
	}

	// Prepare message for signing (matches Solidity: keccak256(abi.encodePacked(receiver, amount, nonce)))
	// This must match the Base contract's withdraw() verification logic
	receiver := common.HexToAddress(request.BaseAddress)
	amountBytes := common.LeftPadBytes(math.NewIntFromUint64(request.Amount).BigInt().Bytes(), 32)
	nonceBytes := common.HexToHash(nonce)

	// Pack data like Solidity abi.encodePacked (no padding between fields for packed encoding)
	message := append(receiver.Bytes(), amountBytes...)
	message = append(message, nonceBytes.Bytes()...)

	// Hash the message with keccak256
	messageHash := crypto.Keccak256Hash(message)

	// Add Ethereum signed message prefix (to match Solidity's getEthSignedMessageHash)
	// The contract does: keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash))
	prefix := []byte("\x19Ethereum Signed Message:\n32")
	prefixedMessage := append(prefix, messageHash.Bytes()...)
	prefixedHash := crypto.Keccak256Hash(prefixedMessage)

	// Sign the prefixed hash with validator's Ethereum private key
	signature, err := crypto.Sign(prefixedHash.Bytes(), validatorPrivKey)
	if err != nil {
		return fmt.Errorf("failed to sign withdrawal: %w", err)
	}

	// Ethereum signatures need recovery id adjusted (v = 27 + v)
	if signature[64] < 27 {
		signature[64] += 27
	}

	// Update withdrawal request
	request.Status = WithdrawalStatusSigned
	request.Signature = signature

	if err := k.WithdrawalRequests.Set(sdkCtx, nonce, request); err != nil {
		return fmt.Errorf("failed to update withdrawal request: %w", err)
	}

	// Emit event
	sdkCtx.EventManager().EmitEvent(
		sdk.NewEvent(
			"withdrawal_signed",
			sdk.NewAttribute("nonce", nonce),
			sdk.NewAttribute("status", WithdrawalStatusSigned),
		),
	)

	return nil
}

// getWithdrawalRequest retrieves a withdrawal request by nonce (internal, lowercase)
func (k Keeper) getWithdrawalRequest(ctx context.Context, nonce string) (*types.WithdrawalRequest, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	request, err := k.WithdrawalRequests.Get(sdkCtx, nonce)
	if err != nil {
		return nil, fmt.Errorf("withdrawal request not found: %w", err)
	}

	return &request, nil
}

// ListWithdrawalRequestsInternal returns all withdrawal requests, optionally filtered by cosmos address
func (k Keeper) ListWithdrawalRequestsInternal(ctx context.Context, cosmosAddress string) ([]*types.WithdrawalRequest, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	var requests []*types.WithdrawalRequest

	// Iterate over all withdrawal requests
	err := k.WithdrawalRequests.Walk(sdkCtx, nil, func(nonce string, request types.WithdrawalRequest) (bool, error) {
		// Filter by cosmos address if provided
		if cosmosAddress != "" && request.CosmosAddress != cosmosAddress {
			return false, nil // Continue iteration, skip this one
		}

		requests = append(requests, &request)
		return false, nil // Continue iteration
	})

	if err != nil {
		return nil, fmt.Errorf("failed to iterate withdrawal requests: %w", err)
	}

	return requests, nil
}

// MarkWithdrawalCompleted marks a withdrawal as completed after it's been claimed on Base chain.
// This should be called when the user successfully calls withdraw() on the Base CosmosBridge contract.
func (k Keeper) MarkWithdrawalCompleted(ctx context.Context, nonce string, baseTxHash string) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Get withdrawal request
	request, err := k.WithdrawalRequests.Get(sdkCtx, nonce)
	if err != nil {
		return fmt.Errorf("withdrawal request not found: %w", err)
	}

	// Validate it's signed
	if request.Status != WithdrawalStatusSigned {
		return fmt.Errorf("withdrawal must be signed before completion (current status: %s)", request.Status)
	}

	// Update status
	request.Status = WithdrawalStatusCompleted
	request.CompletedAt = sdkCtx.BlockTime().Unix()

	if err := k.WithdrawalRequests.Set(sdkCtx, nonce, request); err != nil {
		return fmt.Errorf("failed to update withdrawal status: %w", err)
	}

	// Emit event
	sdkCtx.EventManager().EmitEvent(
		sdk.NewEvent(
			"withdrawal_completed",
			sdk.NewAttribute("nonce", nonce),
			sdk.NewAttribute("base_tx_hash", baseTxHash),
			sdk.NewAttribute("amount", fmt.Sprintf("%d", request.Amount)),
		),
	)

	return nil
}
