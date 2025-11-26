package poker

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"

	"cosmossdk.io/core/appmodule"
	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	"google.golang.org/grpc"

	"github.com/block52/pokerchain/x/poker/keeper"
	"github.com/block52/pokerchain/x/poker/types"
)

var (
	_ module.AppModuleBasic = (*AppModule)(nil)
	_ module.AppModule      = (*AppModule)(nil)
	_ module.HasGenesis     = (*AppModule)(nil)

	_ appmodule.AppModule       = (*AppModule)(nil)
	_ appmodule.HasBeginBlocker = (*AppModule)(nil)
	_ appmodule.HasEndBlocker   = (*AppModule)(nil)
)

// AppModule implements the AppModule interface that defines the inter-dependent methods that modules need to implement
type AppModule struct {
	cdc        codec.Codec
	keeper     *keeper.Keeper
	authKeeper types.AuthKeeper
	bankKeeper types.BankKeeper
}

func NewAppModule(
	cdc codec.Codec,
	keeper *keeper.Keeper,
	authKeeper types.AuthKeeper,
	bankKeeper types.BankKeeper,
) AppModule {
	return AppModule{
		cdc:        cdc,
		keeper:     keeper,
		authKeeper: authKeeper,
		bankKeeper: bankKeeper,
	}
}

// IsAppModule implements the appmodule.AppModule interface.
func (AppModule) IsAppModule() {}

// Name returns the name of the module as a string.
func (AppModule) Name() string {
	return types.ModuleName
}

// RegisterLegacyAminoCodec registers the amino codec
func (AppModule) RegisterLegacyAminoCodec(*codec.LegacyAmino) {}

// RegisterGRPCGatewayRoutes registers the gRPC Gateway routes for the module.
func (AppModule) RegisterGRPCGatewayRoutes(clientCtx client.Context, mux *runtime.ServeMux) {
	if err := types.RegisterQueryHandlerClient(clientCtx.CmdContext, mux, types.NewQueryClient(clientCtx)); err != nil {
		panic(err)
	}
}

// RegisterInterfaces registers a module's interface types and their concrete implementations as proto.Message.
func (AppModule) RegisterInterfaces(registrar codectypes.InterfaceRegistry) {
	types.RegisterInterfaces(registrar)
}

// RegisterServices registers a gRPC query service to respond to the module-specific gRPC queries
func (am AppModule) RegisterServices(registrar grpc.ServiceRegistrar) error {
	types.RegisterMsgServer(registrar, keeper.NewMsgServerImpl(am.keeper))
	types.RegisterQueryServer(registrar, keeper.NewQueryServerImpl(am.keeper))

	return nil
}

// DefaultGenesis returns a default GenesisState for the module, marshalled to json.RawMessage.
// The default GenesisState need to be defined by the module developer and is primarily used for testing.
func (am AppModule) DefaultGenesis(codec.JSONCodec) json.RawMessage {
	return am.cdc.MustMarshalJSON(types.DefaultGenesis())
}

// ValidateGenesis used to validate the GenesisState, given in its json.RawMessage form.
func (am AppModule) ValidateGenesis(_ codec.JSONCodec, _ client.TxEncodingConfig, bz json.RawMessage) error {
	var genState types.GenesisState
	if err := am.cdc.UnmarshalJSON(bz, &genState); err != nil {
		return fmt.Errorf("failed to unmarshal %s genesis state: %w", types.ModuleName, err)
	}

	return genState.Validate()
}

// InitGenesis performs the module's genesis initialization. It returns no validator updates.
func (am AppModule) InitGenesis(ctx sdk.Context, _ codec.JSONCodec, gs json.RawMessage) {
	var genState types.GenesisState
	// Initialize global index to index in genesis state
	if err := am.cdc.UnmarshalJSON(gs, &genState); err != nil {
		panic(fmt.Errorf("failed to unmarshal %s genesis state: %w", types.ModuleName, err))
	}

	if err := am.keeper.InitGenesis(ctx, genState); err != nil {
		panic(fmt.Errorf("failed to initialize %s genesis state: %w", types.ModuleName, err))
	}
}

// ExportGenesis returns the module's exported genesis state as raw JSON bytes.
func (am AppModule) ExportGenesis(ctx sdk.Context, _ codec.JSONCodec) json.RawMessage {
	genState, err := am.keeper.ExportGenesis(ctx)
	if err != nil {
		panic(fmt.Errorf("failed to export %s genesis state: %w", types.ModuleName, err))
	}

	bz, err := am.cdc.MarshalJSON(genState)
	if err != nil {
		panic(fmt.Errorf("failed to marshal %s genesis state: %w", types.ModuleName, err))
	}

	return bz
}

// ConsensusVersion is a sequence number for state-breaking change of the module.
// It should be incremented on each consensus-breaking change introduced by the module.
// To avoid wrong/empty versions, the initial version should be set to 1.
func (AppModule) ConsensusVersion() uint64 { return 1 }

// BeginBlock contains the logic that is automatically triggered at the beginning of each block.
// The begin block implementation is optional.
func (am AppModule) BeginBlock(_ context.Context) error {
	return nil
}

// EndBlock contains the logic that is automatically triggered at the end of each block.
// The end block implementation is optional.
func (am AppModule) EndBlock(ctx context.Context) error {
	// AUTOMATIC DEPOSIT PROCESSING:
	// Check for missing deposits from Ethereum bridge contract every 10 minutes
	// This is deterministic because:
	// 1. All validators query the same Ethereum contract state
	// 2. Deposit indices are processed sequentially (no gaps)
	// 3. L1 block number is stored with each deposit for verification
	// 4. Time-based checks use block time (consensus time, not local time)
	//
	// Rate limiting:
	// - Only checks every 10 minutes (not every block)
	// - Processes maximum 10 deposits per batch
	// - Prevents Ethereum RPC rate limit issues
	if err := am.keeper.ProcessPendingDeposits(ctx); err != nil {
		// Log error but don't halt chain
		// In production, monitoring should alert on repeated failures
	}

	// WITHDRAWAL AUTO-SIGNING:
	// Unlike deposits, withdrawal signing CAN be done in EndBlocker because:
	// 1. Withdrawal data is already in consensus state (from MsgInitiateWithdrawal)
	// 2. Signing is deterministic IF all validators use the same signing approach
	// 3. Only pending withdrawals (already in state) are signed
	//
	// IMPORTANT: For production, configure validator signing key properly.
	// For now, this is a placeholder - actual signing requires validator key configuration.
	//
	// TODO: Add proper validator key management for withdrawal signing
	// Options:
	// - Environment variable with validator Ethereum private key
	// - Keyring integration
	// - External signing service
	//
	// For testing/development: Withdrawal signing is currently disabled in EndBlocker.
	// Use a separate MsgSignWithdrawal transaction or off-chain signing process.

	// Check for pending withdrawals that need signing
	pendingWithdrawals, err := am.keeper.ListWithdrawalRequestsInternal(ctx, "")
	if err != nil {
		return nil // Don't halt the chain for this
	}

	// Count pending withdrawals
	pendingCount := 0
	for _, wr := range pendingWithdrawals {
		if wr.Status == "pending" {
			pendingCount++
		}
	}

	if pendingCount > 0 {
		// Get validator Ethereum private key from keeper config
		// This key is set via bridge.validator_eth_private_key in config.yml
		validatorEthKeyHex := am.keeper.GetValidatorEthPrivateKey()

		if validatorEthKeyHex != "" {
			// Parse the private key
			keyHex := validatorEthKeyHex
			if len(keyHex) > 2 && keyHex[:2] == "0x" {
				keyHex = keyHex[2:]
			}

			keyBytes, err := hex.DecodeString(keyHex)
			if err == nil && len(keyBytes) == 32 {
				validatorPrivKey, err := crypto.ToECDSA(keyBytes)
				if err == nil {
					// Sign all pending withdrawals automatically
					for _, wr := range pendingWithdrawals {
						if wr.Status == "pending" {
							if err := am.keeper.SignWithdrawal(ctx, wr.Nonce, validatorPrivKey); err != nil {
								// Log error but don't halt chain
								// In production, consider more sophisticated error handling
							}
						}
					}
				}
			}
		}
		// If no validator key configured, pending withdrawals must be signed manually via MsgSignWithdrawal
	}

	return nil
}
