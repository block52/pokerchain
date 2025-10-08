package poker

import (
	"context"
	"encoding/json"
	"fmt"

	"cosmossdk.io/core/appmodule"
	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"
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
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	logger := sdkCtx.Logger().With("module", "poker/endblocker")

	logger.Info("🔍 trackMint: EndBlocker called")

	// Process pending bridge deposits
	bridgeService := am.keeper.GetBridgeService()
	if bridgeService == nil {
		logger.Info("⚠️ trackMint: Bridge service is nil, skipping")
		return nil // Bridge service not initialized
	}

	logger.Info("✅ trackMint: Bridge service found")

	// Get pending deposits from the bridge service
	pendingDeposits := bridgeService.GetPendingDeposits()
	logger.Info("📊 trackMint: Retrieved pending deposits", "count", len(pendingDeposits))

	if len(pendingDeposits) == 0 {
		logger.Info("⚠️ trackMint: No pending deposits to process")
		return nil // No deposits to process
	}

	logger.Info("🔄 trackMint: EndBlocker processing pending deposits", "count", len(pendingDeposits))

	// Process each pending deposit
	for i, deposit := range pendingDeposits {
		logger.Info("🔷 trackMint: Processing queued deposit",
			"index", i+1,
			"total", len(pendingDeposits),
			"txHash", deposit.TxHash,
			"recipient", deposit.Recipient,
			"amount", deposit.Amount.String(),
		)
		// Check if already processed
		if exists, err := am.keeper.ProcessedEthTxs.Has(sdkCtx, deposit.TxHash); err != nil {
			logger.Error("❌ trackMint: Failed to check processed transaction",
				"error", err,
				"txHash", deposit.TxHash,
			)
			continue
		} else if exists {
			logger.Warn("⚠️ trackMint: Transaction already processed, skipping",
				"txHash", deposit.TxHash,
			)
			continue
		}

		logger.Info("✅ trackMint: Transaction not yet processed")

		// Validate recipient address
		recipientAddr, err := sdk.AccAddressFromBech32(deposit.Recipient)
		if err != nil {
			logger.Error("❌ trackMint: Invalid recipient address",
				"error", err,
				"recipient", deposit.Recipient,
				"txHash", deposit.TxHash,
			)
			continue
		}

		logger.Info("✅ trackMint: Recipient address validated", "recipientAddr", recipientAddr.String())

		// Create coins to mint
		amount := deposit.Amount.Uint64()
		coins := sdk.NewCoins(sdk.NewInt64Coin("uusdc", int64(amount)))

		logger.Info("🪙 trackMint: Minting coins", "amount", amount, "coins", coins.String())

		// Mint coins to module account
		if err := am.bankKeeper.MintCoins(ctx, types.ModuleName, coins); err != nil {
			logger.Error("❌ trackMint: Failed to mint coins",
				"error", err,
				"amount", amount,
				"txHash", deposit.TxHash,
			)
			continue
		}

		logger.Info("✅ trackMint: Coins minted to module account")

		logger.Info("💸 trackMint: Sending coins to recipient", "recipient", deposit.Recipient)

		// Send coins to recipient
		if err := am.bankKeeper.SendCoinsFromModuleToAccount(ctx, types.ModuleName, recipientAddr, coins); err != nil {
			logger.Error("❌ trackMint: Failed to send coins to recipient",
				"error", err,
				"recipient", deposit.Recipient,
				"amount", amount,
				"txHash", deposit.TxHash,
			)
			continue
		}

		logger.Info("✅ trackMint: Coins sent to recipient")

		logger.Info("📝 trackMint: Marking transaction as processed", "txHash", deposit.TxHash)

		// Mark transaction as processed
		if err := am.keeper.ProcessedEthTxs.Set(sdkCtx, deposit.TxHash); err != nil {
			logger.Error("❌ trackMint: Failed to mark transaction as processed",
				"error", err,
				"txHash", deposit.TxHash,
			)
			continue
		}

		logger.Info("✅ trackMint: Transaction marked as processed")

		// Emit event
		sdkCtx.EventManager().EmitEvent(
			sdk.NewEvent(
				"bridge_mint",
				sdk.NewAttribute("recipient", deposit.Recipient),
				sdk.NewAttribute("amount", coins.String()),
				sdk.NewAttribute("eth_tx_hash", deposit.TxHash),
				sdk.NewAttribute("nonce", fmt.Sprintf("%d", deposit.Nonce)),
			),
		)

		logger.Info("🎉 trackMint: Deposit processed successfully!",
			"recipient", deposit.Recipient,
			"amount", coins.String(),
			"txHash", deposit.TxHash,
			"nonce", deposit.Nonce,
		)
	}

	return nil
}
