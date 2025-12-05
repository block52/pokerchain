package types

import "cosmossdk.io/collections"

const (
	// ModuleName defines the module name
	ModuleName = "poker"

	// StoreKey defines the primary module store key
	StoreKey = ModuleName

	// GovModuleName duplicates the gov module's name to avoid a dependency with x/gov.
	// It should be synced with the gov module's name if it is ever changed.
	// See: https://github.com/cosmos/cosmos-sdk/blob/v0.52.0-beta.2/x/gov/types/keys.go#L9
	GovModuleName = "gov"
)

// ParamsKey is the prefix to retrieve all Params
var ParamsKey = collections.NewPrefix("p_poker")

// ProcessedEthTxsKey is the prefix to store processed Ethereum transaction hashes
var ProcessedEthTxsKey = collections.NewPrefix("processed_eth_txs")

// GamesKey is the prefix to store games
var GamesKey = collections.NewPrefix("games")

// GameStatesKey is the prefix to store game states
var GameStatesKey = collections.NewPrefix("game_states")

// WithdrawalRequestsKey is the prefix to store withdrawal requests
var WithdrawalRequestsKey = collections.NewPrefix("withdrawal_requests")

// WithdrawalNonceKey is the prefix for withdrawal nonce sequence
var WithdrawalNonceKey = collections.NewPrefix("withdrawal_nonce")

// DepositSyncStateKey is the prefix for deposit sync state
var DepositSyncStateKey = collections.NewPrefix("deposit_sync_state")
