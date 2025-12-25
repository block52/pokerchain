package app

import (
	"io"
	"os"

	clienthelpers "cosmossdk.io/client/v2/helpers"
	"cosmossdk.io/core/appmodule"
	"cosmossdk.io/depinject"
	"cosmossdk.io/log"
	storetypes "cosmossdk.io/store/types"
	circuitkeeper "cosmossdk.io/x/circuit/keeper"
	upgradekeeper "cosmossdk.io/x/upgrade/keeper"

	abci "github.com/cometbft/cometbft/abci/types"
	dbm "github.com/cosmos/cosmos-db"
	"github.com/cosmos/cosmos-sdk/baseapp"
	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/runtime"
	"github.com/cosmos/cosmos-sdk/server"
	"github.com/cosmos/cosmos-sdk/server/api"
	"github.com/cosmos/cosmos-sdk/server/config"
	servertypes "github.com/cosmos/cosmos-sdk/server/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"
	"github.com/cosmos/cosmos-sdk/x/auth"
	authkeeper "github.com/cosmos/cosmos-sdk/x/auth/keeper"
	authsims "github.com/cosmos/cosmos-sdk/x/auth/simulation"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	authzkeeper "github.com/cosmos/cosmos-sdk/x/authz/keeper"
	bankkeeper "github.com/cosmos/cosmos-sdk/x/bank/keeper"
	consensuskeeper "github.com/cosmos/cosmos-sdk/x/consensus/keeper"
	distrkeeper "github.com/cosmos/cosmos-sdk/x/distribution/keeper"
	"github.com/cosmos/cosmos-sdk/x/genutil"
	genutiltypes "github.com/cosmos/cosmos-sdk/x/genutil/types"
	govkeeper "github.com/cosmos/cosmos-sdk/x/gov/keeper"
	mintkeeper "github.com/cosmos/cosmos-sdk/x/mint/keeper"
	paramskeeper "github.com/cosmos/cosmos-sdk/x/params/keeper"
	paramstypes "github.com/cosmos/cosmos-sdk/x/params/types"
	slashingkeeper "github.com/cosmos/cosmos-sdk/x/slashing/keeper"
	stakingkeeper "github.com/cosmos/cosmos-sdk/x/staking/keeper"
	icacontrollerkeeper "github.com/cosmos/ibc-go/v10/modules/apps/27-interchain-accounts/controller/keeper"
	icahostkeeper "github.com/cosmos/ibc-go/v10/modules/apps/27-interchain-accounts/host/keeper"
	ibctransferkeeper "github.com/cosmos/ibc-go/v10/modules/apps/transfer/keeper"
	ibckeeper "github.com/cosmos/ibc-go/v10/modules/core/keeper"

	feegrantkeeper "cosmossdk.io/x/feegrant/keeper"

	authante "github.com/cosmos/cosmos-sdk/x/auth/ante"

	pokerante "github.com/block52/pokerchain/app/ante"
	"github.com/block52/pokerchain/docs"
	"github.com/block52/pokerchain/pkg/wsserver"
	pokermodulekeeper "github.com/block52/pokerchain/x/poker/keeper"
)

const (
	// Name is the name of the application.
	Name = "pokerchain"
	// Version is the version of the application. This is the single source of truth.
	Version = "0.1.33"
	// AccountAddressPrefix is the prefix for accounts addresses.
	AccountAddressPrefix = "b52"
	// ChainCoinType is the coin type of the chain.
	ChainCoinType = 118
)

// DefaultNodeHome default home directories for the application daemon
var DefaultNodeHome string

var (
	_ runtime.AppI            = (*App)(nil)
	_ servertypes.Application = (*App)(nil)
)

// App extends an ABCI application, but with most of its parameters exported.
// They are exported for convenience in creating helper functions, as object
// capabilities aren't needed for testing.
type App struct {
	*runtime.App
	legacyAmino       *codec.LegacyAmino
	appCodec          codec.Codec
	txConfig          client.TxConfig
	interfaceRegistry codectypes.InterfaceRegistry

	// keepers
	// only keepers required by the app are exposed
	// the list of all modules is available in the app_config
	AuthKeeper            authkeeper.AccountKeeper
	BankKeeper            bankkeeper.Keeper
	StakingKeeper         *stakingkeeper.Keeper
	SlashingKeeper        slashingkeeper.Keeper
	MintKeeper            mintkeeper.Keeper
	DistrKeeper           distrkeeper.Keeper
	GovKeeper             *govkeeper.Keeper
	UpgradeKeeper         *upgradekeeper.Keeper
	AuthzKeeper           authzkeeper.Keeper
	ConsensusParamsKeeper consensuskeeper.Keeper
	CircuitBreakerKeeper  circuitkeeper.Keeper
	FeegrantKeeper        feegrantkeeper.Keeper
	ParamsKeeper          paramskeeper.Keeper

	// ibc keepers
	IBCKeeper           *ibckeeper.Keeper
	ICAControllerKeeper icacontrollerkeeper.Keeper
	ICAHostKeeper       icahostkeeper.Keeper
	TransferKeeper      ibctransferkeeper.Keeper

	PokerKeeper *pokermodulekeeper.Keeper
	// this line is used by starport scaffolding # stargate/app/keeperDeclaration

	// simulation manager
	sm *module.SimulationManager
}

func init() {

	sdk.DefaultBondDenom = "stake"

	var err error
	clienthelpers.EnvPrefix = Name
	DefaultNodeHome, err = clienthelpers.GetNodeHomeDirectory("." + Name)
	if err != nil {
		panic(err)
	}
}

// AppConfig returns the default app config.
func AppConfig() depinject.Config {
	return depinject.Configs(
		appConfig,
		depinject.Supply(
			// supply custom module basics
			map[string]module.AppModuleBasic{
				genutiltypes.ModuleName: genutil.NewAppModuleBasic(genutiltypes.DefaultMessageValidator),
			},
		),
	)
}

// New returns a reference to an initialized App.
func New(
	logger log.Logger,
	db dbm.DB,
	traceStore io.Writer,
	loadLatest bool,
	appOpts servertypes.AppOptions,
	baseAppOptions ...func(*baseapp.BaseApp),
) *App {
	var (
		app        = &App{}
		appBuilder *runtime.AppBuilder

		// merge the AppConfig and other configuration in one config
		appConfig = depinject.Configs(
			AppConfig(),
			depinject.Supply(
				appOpts, // supply app options
				logger,  // supply logger
				// here alternative options can be supplied to the DI container.
				// those options can be used f.e to override the default behavior of some modules.
				// for instance supplying a custom address codec for not using bech32 addresses.
				// read the depinject documentation and depinject module wiring for more information
				// on available options and how to use them.
			),
		)
	)

	var appModules map[string]appmodule.AppModule
	if err := depinject.Inject(appConfig,
		&appBuilder,
		&appModules,
		&app.appCodec,
		&app.legacyAmino,
		&app.txConfig,
		&app.interfaceRegistry,
		&app.AuthKeeper,
		&app.BankKeeper,
		&app.StakingKeeper,
		&app.SlashingKeeper,
		&app.MintKeeper,
		&app.DistrKeeper,
		&app.GovKeeper,
		&app.UpgradeKeeper,
		&app.AuthzKeeper,
		&app.ConsensusParamsKeeper,
		&app.CircuitBreakerKeeper,
		&app.FeegrantKeeper,
		&app.ParamsKeeper,
		&app.PokerKeeper,
	); err != nil {
		panic(err)
	}

	// add to default baseapp options
	// enable optimistic execution
	baseAppOptions = append(baseAppOptions, baseapp.SetOptimisticExecution())

	// Set custom ante handler with poker gasless support
	anteHandler, err := pokerante.NewAnteHandler(
		pokerante.HandlerOptions{
			HandlerOptions: authante.HandlerOptions{
				AccountKeeper:   app.AuthKeeper,
				BankKeeper:      app.BankKeeper,
				FeegrantKeeper:  app.FeegrantKeeper,
				SignModeHandler: app.txConfig.SignModeHandler(),
			},
			CircuitKeeper: &app.CircuitBreakerKeeper,
		},
	)
	if err != nil {
		panic(err)
	}
	baseAppOptions = append(baseAppOptions, func(ba *baseapp.BaseApp) { ba.SetAnteHandler(anteHandler) })

	// build app
	app.App = appBuilder.Build(db, traceStore, baseAppOptions...)

	// register legacy modules
	if err := app.registerIBCModules(appOpts); err != nil {
		panic(err)
	}

	/****  Module Options ****/

	// create the simulation manager and define the order of the modules for deterministic simulations
	overrideModules := map[string]module.AppModuleSimulation{
		authtypes.ModuleName: auth.NewAppModule(app.appCodec, app.AuthKeeper, authsims.RandomGenesisAccounts, nil),
	}
	app.sm = module.NewSimulationManagerFromAppModules(app.ModuleManager.Modules, overrideModules)

	app.sm.RegisterStoreDecoders()

	// A custom InitChainer sets if extra pre-init-genesis logic is required.
	// This is necessary for manually registered modules that do not support app wiring.
	// Manually set the module version map as shown below.
	// The upgrade module will automatically handle de-duplication of the module version map.
	app.SetInitChainer(func(ctx sdk.Context, req *abci.RequestInitChain) (*abci.ResponseInitChain, error) {
		if err := app.UpgradeKeeper.SetModuleVersionMap(ctx, app.ModuleManager.GetVersionMap()); err != nil {
			return nil, err
		}
		return app.App.InitChainer(ctx, req)
	})

	if err := app.Load(loadLatest); err != nil {
		panic(err)
	}

	// Initialize and start the Ethereum bridge service
	bridgeConfig := loadBridgeConfig(appOpts)
	logger.Info("Bridge config loaded",
		"enabled", bridgeConfig.Enabled,
		"rpc_url", bridgeConfig.EthereumRPCURL,
		"deposit_contract", bridgeConfig.DepositContractAddress,
	)

	// Set bridge config on poker keeper for MsgMint verification and withdrawal signing
	app.PokerKeeper.SetBridgeConfig(
		bridgeConfig.EthereumRPCURL,
		bridgeConfig.DepositContractAddress,
		bridgeConfig.ValidatorEthPrivateKey,
	)
	if bridgeConfig.ValidatorEthPrivateKey != "" {
		logger.Info("✅ Bridge config set with validator signing key - automatic withdrawal signing ENABLED")
	} else {
		logger.Info("✅ Bridge config set for deposit verification - automatic withdrawal signing DISABLED (use MsgSignWithdrawal)")
	}

	// NOTE: Auto-sync bridge service removed (migrated to manual index-based processing)
	// Deposits are now processed via MsgProcessDeposit transactions submitted by users/relayers
	// This ensures deterministic consensus - all nodes process the same transactions in the same order
	// See BRIDGE_DEPOSIT_FLOW.md for the new manual processing architecture
	logger.Info("🌉 Bridge: Manual index-based processing enabled (no auto-sync)")

	// Load and set PVM configuration
	pvmConfig := loadPVMConfig(appOpts)
	app.PokerKeeper.SetPVMConfig(pvmConfig.PVMURL)
	logger.Info("🎰 PVM config set", "pvm_url", pvmConfig.PVMURL)

	return app
}

// loadBridgeConfig loads bridge configuration from app options
func loadBridgeConfig(appOpts servertypes.AppOptions) BridgeConfig {
	bridgeConfig := DefaultBridgeConfig()

	// Load from app config if available
	if enabled := appOpts.Get("bridge.enabled"); enabled != nil {
		if val, ok := enabled.(bool); ok {
			bridgeConfig.Enabled = val
		}
	}
	if rpcURL := appOpts.Get("bridge.ethereum_rpc_url"); rpcURL != nil {
		if val, ok := rpcURL.(string); ok {
			bridgeConfig.EthereumRPCURL = val
		}
	}
	if depositAddr := appOpts.Get("bridge.deposit_contract_address"); depositAddr != nil {
		if val, ok := depositAddr.(string); ok {
			bridgeConfig.DepositContractAddress = val
		}
	}
	if usdcAddr := appOpts.Get("bridge.usdc_contract_address"); usdcAddr != nil {
		if val, ok := usdcAddr.(string); ok {
			bridgeConfig.USDCContractAddress = val
		}
	}
	if interval := appOpts.Get("bridge.polling_interval_seconds"); interval != nil {
		if val, ok := interval.(int64); ok {
			bridgeConfig.PollingIntervalSeconds = int(val)
		} else if val, ok := interval.(float64); ok {
			bridgeConfig.PollingIntervalSeconds = int(val)
		}
	}
	if startBlock := appOpts.Get("bridge.starting_block"); startBlock != nil {
		if val, ok := startBlock.(int64); ok {
			bridgeConfig.StartingBlock = uint64(val)
		} else if val, ok := startBlock.(float64); ok {
			bridgeConfig.StartingBlock = uint64(val)
		}
	}
	if validatorKey := appOpts.Get("bridge.validator_eth_private_key"); validatorKey != nil {
		if val, ok := validatorKey.(string); ok {
			bridgeConfig.ValidatorEthPrivateKey = val
		}
	}

	return bridgeConfig
}

// loadPVMConfig loads PVM configuration from app options
func loadPVMConfig(appOpts servertypes.AppOptions) PVMConfig {
	pvmConfig := DefaultPVMConfig()

	// Load from app config if available
	if pvmURL := appOpts.Get("pvm.pvm_url"); pvmURL != nil {
		if val, ok := pvmURL.(string); ok && val != "" {
			pvmConfig.PVMURL = val
		}
	}

	return pvmConfig
}

// GetSubspace returns a param subspace for a given module name.
func (app *App) GetSubspace(moduleName string) paramstypes.Subspace {
	subspace, _ := app.ParamsKeeper.GetSubspace(moduleName)
	return subspace
}

// LegacyAmino returns App's amino codec.
func (app *App) LegacyAmino() *codec.LegacyAmino {
	return app.legacyAmino
}

// AppCodec returns App's app codec.
func (app *App) AppCodec() codec.Codec {
	return app.appCodec
}

// InterfaceRegistry returns App's InterfaceRegistry.
func (app *App) InterfaceRegistry() codectypes.InterfaceRegistry {
	return app.interfaceRegistry
}

// TxConfig returns App's TxConfig
func (app *App) TxConfig() client.TxConfig {
	return app.txConfig
}

// GetKey returns the KVStoreKey for the provided store key.
func (app *App) GetKey(storeKey string) *storetypes.KVStoreKey {
	kvStoreKey, ok := app.UnsafeFindStoreKey(storeKey).(*storetypes.KVStoreKey)
	if !ok {
		return nil
	}
	return kvStoreKey
}

// SimulationManager implements the SimulationApp interface
func (app *App) SimulationManager() *module.SimulationManager {
	return app.sm
}

// RegisterAPIRoutes registers all application module routes with the provided
// API server.
func (app *App) RegisterAPIRoutes(apiSvr *api.Server, apiConfig config.APIConfig) {
	app.App.RegisterAPIRoutes(apiSvr, apiConfig)
	// register swagger API in app.go so that other applications can override easily
	if err := server.RegisterSwaggerAPI(apiSvr.ClientCtx, apiSvr.Router, apiConfig.Swagger); err != nil {
		panic(err)
	}

	// register app's OpenAPI routes.
	docs.RegisterOpenAPIService(Name, apiSvr.Router)

	// Start embedded WebSocket server if enabled
	// Set WS_ENABLED=true in environment to enable
	if os.Getenv("WS_ENABLED") == "true" {
		wsConfig := wsserver.Config{
			Port:            getEnvOrDefault("WS_SERVER_PORT", ":8585"),
			TendermintWSURL: getEnvOrDefault("WS_TENDERMINT_URL", "ws://localhost:26657/websocket"),
			GRPCAddress:     getEnvOrDefault("WS_GRPC_ADDRESS", "localhost:9090"),
		}
		wsserver.StartAsync(wsConfig)
	}
}

// getEnvOrDefault returns the environment variable value or a default
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GetMaccPerms returns a copy of the module account permissions
//
// NOTE: This is solely to be used for testing purposes.
func GetMaccPerms() map[string][]string {
	dup := make(map[string][]string)
	for _, perms := range moduleAccPerms {
		dup[perms.GetAccount()] = perms.GetPermissions()
	}

	return dup
}

// BlockedAddresses returns all the app's blocked account addresses.
func BlockedAddresses() map[string]bool {
	result := make(map[string]bool)

	if len(blockAccAddrs) > 0 {
		for _, addr := range blockAccAddrs {
			result[addr] = true
		}
	} else {
		for addr := range GetMaccPerms() {
			result[addr] = true
		}
	}

	return result
}
