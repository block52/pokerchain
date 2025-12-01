package keeper

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
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

// DepositData contains deposit information from Ethereum contract
type DepositData struct {
	Account        string
	Amount         *big.Int
	Index          uint64
	EthBlockHeight uint64 // The Ethereum block height used for the query
}

// GetDepositByIndex queries the Ethereum bridge contract for deposit data by index
// It calls the deposits(uint256) view function and returns the account and amount.
// If ethBlockHeight is 0, it queries at the latest block and returns the block height used.
// If ethBlockHeight is non-zero, it queries at that specific block for deterministic replay.
func (bv *BridgeVerifier) GetDepositByIndex(
	ctx context.Context,
	depositIndex uint64,
	ethBlockHeight uint64,
) (*DepositData, error) {
	// ABI for deposits(uint256) function
	// function deposits(uint256) external view returns (string memory account, uint256 amount)
	depositsABI := `[{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"deposits","outputs":[{"internalType":"string","name":"account","type":"string"},{"internalType":"uint256","name":"amount","type":"uint256"}],"stateMutability":"view","type":"function"}]`

	// Parse ABI
	parsedABI, err := abi.JSON(strings.NewReader(depositsABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ABI: %w", err)
	}

	// Pack function call data
	data, err := parsedABI.Pack("deposits", big.NewInt(int64(depositIndex)))
	if err != nil {
		return nil, fmt.Errorf("failed to pack function call: %w", err)
	}

	// Call contract
	msg := ethereum.CallMsg{
		To:   &bv.depositContract,
		Data: data,
	}

	// Determine block number for query
	var blockNum *big.Int
	var queryBlockHeight uint64

	if ethBlockHeight == 0 {
		// Get current block number for deterministic storage
		currentBlock, err := bv.ethClient.BlockNumber(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to get current block number: %w", err)
		}
		queryBlockHeight = currentBlock
		blockNum = big.NewInt(int64(currentBlock))
	} else {
		// Use specified block height for deterministic replay
		queryBlockHeight = ethBlockHeight
		blockNum = big.NewInt(int64(ethBlockHeight))
	}

	// Call contract at specific block height
	result, err := bv.ethClient.CallContract(ctx, msg, blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to call contract at block %d: %w", queryBlockHeight, err)
	}

	// Unpack result
	var out struct {
		Account string
		Amount  *big.Int
	}

	err = parsedABI.UnpackIntoInterface(&out, "deposits", result)
	if err != nil {
		return nil, fmt.Errorf("failed to unpack result: %w", err)
	}

	// Check if deposit exists (account will be empty if deposit doesn't exist)
	if out.Account == "" {
		return nil, fmt.Errorf("deposit index %d not found in contract at block %d", depositIndex, queryBlockHeight)
	}

	return &DepositData{
		Account:        out.Account,
		Amount:         out.Amount,
		Index:          depositIndex,
		EthBlockHeight: queryBlockHeight,
	}, nil
}

// Close closes the Ethereum client connection
func (bv *BridgeVerifier) Close() {
	if bv.ethClient != nil {
		bv.ethClient.Close()
	}
}
