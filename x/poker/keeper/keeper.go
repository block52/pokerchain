package keeper

import (
	"fmt"

	"cosmossdk.io/collections"
	"cosmossdk.io/core/address"
	corestore "cosmossdk.io/core/store"
	"github.com/cosmos/cosmos-sdk/codec"

	"github.com/block52/pokerchain/x/poker/types"
)

type Keeper struct {
	storeService corestore.KVStoreService
	cdc          codec.Codec
	addressCodec address.Codec
	// Address capable of executing a MsgUpdateParams message.
	// Typically, this should be the x/gov module account.
	authority []byte

	Schema collections.Schema
	Params collections.Item[types.Params]
	// ProcessedEthTxs tracks processed Ethereum transaction hashes to prevent double minting
	ProcessedEthTxs collections.KeySet[string]
	// Games stores all poker games
	Games collections.Map[string, types.Game]
	// GameStates stores game state data for frontend compatibility
	GameStates collections.Map[string, types.TexasHoldemStateDTO]
	// WithdrawalRequests stores pending and completed withdrawal requests
	WithdrawalRequests collections.Map[string, types.WithdrawalRequest]
	// WithdrawalNonce is a sequence for generating unique withdrawal IDs
	WithdrawalNonce collections.Sequence
	// LastDepositCheckTime stores the timestamp (Unix seconds) of the last deposit check
	// Used to enforce 10-minute interval between automatic deposit processing
	LastDepositCheckTime collections.Item[int64]
	// ProcessedDepositIndices maps deposit index -> L1 block number for determinism
	// Stores the Ethereum block number when each deposit was fetched
	ProcessedDepositIndices collections.Map[uint64, uint64]

	authKeeper    types.AuthKeeper
	bankKeeper    types.BankKeeper
	stakingKeeper types.StakingKeeper
	bridgeService *BridgeService

	// Bridge configuration for Ethereum verification
	ethRPCURL              string
	depositContractAddr    string
	validatorEthPrivateKey string // Hex-encoded Ethereum private key for withdrawal signing (without 0x prefix)
}

func NewKeeper(
	storeService corestore.KVStoreService,
	cdc codec.Codec,
	addressCodec address.Codec,
	authority []byte,

	authKeeper types.AuthKeeper,
	bankKeeper types.BankKeeper,
	stakingKeeper types.StakingKeeper,

	ethRPCURL string,
	depositContractAddr string,
) *Keeper {
	if _, err := addressCodec.BytesToString(authority); err != nil {
		panic(fmt.Sprintf("invalid authority address %s: %s", authority, err))
	}

	sb := collections.NewSchemaBuilder(storeService)

	k := &Keeper{
		storeService: storeService,
		cdc:          cdc,
		addressCodec: addressCodec,
		authority:    authority,

		authKeeper:          authKeeper,
		bankKeeper:          bankKeeper,
		stakingKeeper:       stakingKeeper,
		ethRPCURL:           ethRPCURL,
		depositContractAddr: depositContractAddr,
		Params:                  collections.NewItem(sb, types.ParamsKey, "params", codec.CollValue[types.Params](cdc)),
		ProcessedEthTxs:         collections.NewKeySet(sb, types.ProcessedEthTxsKey, "processed_eth_txs", collections.StringKey),
		Games:                   collections.NewMap(sb, types.GamesKey, "games", collections.StringKey, codec.CollValue[types.Game](cdc)),
		GameStates:              collections.NewMap(sb, types.GameStatesKey, "game_states", collections.StringKey, codec.CollValue[types.TexasHoldemStateDTO](cdc)),
		WithdrawalRequests:      collections.NewMap(sb, types.WithdrawalRequestsKey, "withdrawal_requests", collections.StringKey, codec.CollValue[types.WithdrawalRequest](cdc)),
		WithdrawalNonce:         collections.NewSequence(sb, types.WithdrawalNonceKey, "withdrawal_nonce"),
		LastDepositCheckTime:    collections.NewItem(sb, types.LastDepositCheckTimeKey, "last_deposit_check_time", collections.Int64Value),
		ProcessedDepositIndices: collections.NewMap(sb, types.ProcessedDepositIndicesKey, "processed_deposit_indices", collections.Uint64Key, collections.Uint64Value),
	}

	schema, err := sb.Build()
	if err != nil {
		panic(err)
	}
	k.Schema = schema

	return k
}

// GetAuthority returns the module's authority.
func (k Keeper) GetAuthority() []byte {
	return k.authority
}

// SetBridgeService sets the bridge service for this keeper instance
func (k *Keeper) SetBridgeService(bs *BridgeService) {
	k.bridgeService = bs
}

// GetBridgeService returns the bridge service for this keeper instance
func (k *Keeper) GetBridgeService() *BridgeService {
	return k.bridgeService
}

// SetBridgeConfig updates the bridge configuration for Ethereum verification
func (k *Keeper) SetBridgeConfig(ethRPCURL string, depositContractAddr string, validatorEthPrivateKey string) {
	k.ethRPCURL = ethRPCURL
	k.depositContractAddr = depositContractAddr
	k.validatorEthPrivateKey = validatorEthPrivateKey
}

// GetValidatorEthPrivateKey returns the configured validator Ethereum private key
func (k *Keeper) GetValidatorEthPrivateKey() string {
	return k.validatorEthPrivateKey
}
