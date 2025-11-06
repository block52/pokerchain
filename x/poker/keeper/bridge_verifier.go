package keeper

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

// BridgeVerifier handles verification of Ethereum deposits
type BridgeVerifier struct {
	ethClient       *ethclient.Client
	depositContract common.Address
}

// DepositVerification contains verified deposit information
type DepositVerification struct {
	Recipient string
	Amount    uint64
	Nonce     uint64
	Verified  bool
}

// NewBridgeVerifier creates a new bridge verifier
func NewBridgeVerifier(ethRPCURL string, depositContractAddr string) (*BridgeVerifier, error) {
	client, err := ethclient.Dial(ethRPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum client: %w", err)
	}

	return &BridgeVerifier{
		ethClient:       client,
		depositContract: common.HexToAddress(depositContractAddr),
	}, nil
}

// VerifyDeposit verifies an Ethereum deposit transaction
// It checks that the transaction exists, was sent to the correct contract,
// and that the event data matches the provided parameters
func (bv *BridgeVerifier) VerifyDeposit(
	ctx context.Context,
	ethTxHash string,
	expectedRecipient string,
	expectedAmount uint64,
	expectedNonce uint64,
) (*DepositVerification, error) {
	// Parse transaction hash
	txHash := common.HexToHash(ethTxHash)

	// Get transaction
	tx, isPending, err := bv.ethClient.TransactionByHash(ctx, txHash)
	if err != nil {
		return nil, fmt.Errorf("failed to get transaction: %w", err)
	}

	if isPending {
		return nil, fmt.Errorf("transaction is still pending")
	}

	// Verify transaction was sent to the deposit contract
	if tx.To() == nil || tx.To().Hex() != bv.depositContract.Hex() {
		return nil, fmt.Errorf("transaction was not sent to deposit contract (expected: %s, got: %s)",
			bv.depositContract.Hex(), tx.To().Hex())
	}

	// Get transaction receipt to access logs/events
	receipt, err := bv.ethClient.TransactionReceipt(ctx, txHash)
	if err != nil {
		return nil, fmt.Errorf("failed to get transaction receipt: %w", err)
	}

	// Verify transaction was successful
	if receipt.Status != types.ReceiptStatusSuccessful {
		return nil, fmt.Errorf("transaction failed on Ethereum")
	}

	// Parse the Deposited event from logs
	// Event signature: Deposited(string indexed account, uint256 amount, uint256 index)
	// Topic[0] = event signature hash
	// Topic[1] = indexed account (hashed)
	// Data = amount (32 bytes) + index/nonce (32 bytes)
	depositedEventSig := common.HexToHash("0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2")

	var depositEvent *types.Log
	for _, log := range receipt.Logs {
		if len(log.Topics) > 0 && log.Topics[0] == depositedEventSig {
			depositEvent = log
			break
		}
	}

	if depositEvent == nil {
		return nil, fmt.Errorf("deposit event not found in transaction logs")
	}

	// Parse event data
	if len(depositEvent.Data) < 64 {
		return nil, fmt.Errorf("invalid event data length: expected at least 64 bytes, got %d", len(depositEvent.Data))
	}

	// Amount is first 32 bytes
	amountBytes := depositEvent.Data[0:32]
	amount := new(big.Int).SetBytes(amountBytes).Uint64()

	// Nonce is second 32 bytes
	nonceBytes := depositEvent.Data[32:64]
	nonce := new(big.Int).SetBytes(nonceBytes).Uint64()

	// Extract recipient from transaction input data
	// Function signature for depositUnderlying(uint256 amount, string calldata receiver)
	recipient, err := bv.parseRecipientFromTxData(tx.Data())
	if err != nil {
		return nil, fmt.Errorf("failed to parse recipient from tx data: %w", err)
	}

	// Verify parameters match
	if recipient != expectedRecipient {
		return nil, fmt.Errorf("recipient mismatch: expected %s, got %s", expectedRecipient, recipient)
	}

	if amount != expectedAmount {
		return nil, fmt.Errorf("amount mismatch: expected %d, got %d", expectedAmount, amount)
	}

	if nonce != expectedNonce {
		return nil, fmt.Errorf("nonce mismatch: expected %d, got %d", expectedNonce, nonce)
	}

	return &DepositVerification{
		Recipient: recipient,
		Amount:    amount,
		Nonce:     nonce,
		Verified:  true,
	}, nil
}

// parseRecipientFromTxData extracts the Cosmos recipient address from transaction call data
func (bv *BridgeVerifier) parseRecipientFromTxData(txData []byte) (string, error) {
	if len(txData) < 4 {
		return "", fmt.Errorf("transaction data too short")
	}

	// Skip function selector (first 4 bytes)
	// depositUnderlying(uint256 amount, string calldata receiver)
	// Layout: selector (4) + amount (32) + string offset (32) + string length (32) + string data

	if len(txData) < 100 {
		return "", fmt.Errorf("transaction data too short for recipient extraction")
	}

	// String length is at bytes 68-100
	strLenBytes := txData[68:100]
	strLen := new(big.Int).SetBytes(strLenBytes).Uint64()

	// String data starts at byte 100
	if len(txData) < int(100+strLen) {
		return "", fmt.Errorf("transaction data too short for recipient string")
	}

	recipientStr := string(txData[100 : 100+strLen])

	if recipientStr == "" {
		return "", fmt.Errorf("empty recipient string")
	}

	return recipientStr, nil
}

// Close closes the Ethereum client connection
func (bv *BridgeVerifier) Close() {
	if bv.ethClient != nil {
		bv.ethClient.Close()
	}
}

