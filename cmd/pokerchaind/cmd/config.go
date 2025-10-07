package cmd

import (
	cmtcfg "github.com/cometbft/cometbft/config"
	serverconfig "github.com/cosmos/cosmos-sdk/server/config"
)

// initCometBFTConfig helps to override default CometBFT Config values.
// return cmtcfg.DefaultConfig if no custom configuration is required for the application.
func initCometBFTConfig() *cmtcfg.Config {
	cfg := cmtcfg.DefaultConfig()

	// these values put a higher strain on node memory
	// cfg.P2P.MaxNumInboundPeers = 100
	// cfg.P2P.MaxNumOutboundPeers = 40

	return cfg
}

// BridgeConfig defines configuration for the Ethereum bridge
type BridgeConfig struct {
	Enabled                bool   `mapstructure:"enabled"`
	EthereumRPCURL         string `mapstructure:"ethereum_rpc_url"`
	DepositContractAddress string `mapstructure:"deposit_contract_address"`
	USDCContractAddress    string `mapstructure:"usdc_contract_address"`
	PollingIntervalSeconds int    `mapstructure:"polling_interval_seconds"`
	StartingBlock          uint64 `mapstructure:"starting_block"`
}

// initAppConfig helps to override default appConfig template and configs.
// return "", nil if no custom configuration is required for the application.
func initAppConfig() (string, interface{}) {
	// The following code snippet is just for reference.
	type CustomAppConfig struct {
		serverconfig.Config `mapstructure:",squash"`
		Bridge              BridgeConfig `mapstructure:"bridge"`
	}

	// Optionally allow the chain developer to overwrite the SDK's default
	// server config.
	srvCfg := serverconfig.DefaultConfig()
	// The SDK's default minimum gas price is set to "" (empty value) inside
	// app.toml. If left empty by validators, the node will halt on startup.
	// However, the chain developer can set a default app.toml value for their
	// validators here.
	//
	// In summary:
	// - if you leave srvCfg.MinGasPrices = "", all validators MUST tweak their
	//   own app.toml config,
	// - if you set srvCfg.MinGasPrices non-empty, validators CAN tweak their
	//   own app.toml to override, or use this default value.
	//
	// In tests, we set the min gas prices to 0.
	// srvCfg.MinGasPrices = "0stake"

	customAppConfig := CustomAppConfig{
		Config: *srvCfg,
		Bridge: BridgeConfig{
			Enabled:                true,
			EthereumRPCURL:         "https://base.llamarpc.com",
			DepositContractAddress: "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B",
			USDCContractAddress:    "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
			PollingIntervalSeconds: 15,
			StartingBlock:          36469223,
		},
	}

	customAppTemplate := serverconfig.DefaultConfigTemplate + `
###############################################################################
###                           Bridge Configuration                          ###
###############################################################################

[bridge]
# Enable or disable the Ethereum bridge service
enabled = {{ .Bridge.Enabled }}

# Ethereum RPC URL (Base Chain)
ethereum_rpc_url = "{{ .Bridge.EthereumRPCURL }}"

# CosmosBridge contract address on Base Chain
deposit_contract_address = "{{ .Bridge.DepositContractAddress }}"

# USDC contract address on Base Chain
usdc_contract_address = "{{ .Bridge.USDCContractAddress }}"

# Polling interval in seconds
polling_interval_seconds = {{ .Bridge.PollingIntervalSeconds }}

# Starting block number (block where CosmosBridge was deployed)
starting_block = {{ .Bridge.StartingBlock }}
`
	// Edit the default template file
	//
	// customAppTemplate := serverconfig.DefaultConfigTemplate + `
	// [wasm]
	// # This is the maximum sdk gas (wasm and storage) that we allow for any x/wasm "smart" queries
	// query_gas_limit = 300000
	// # This is the number of wasm vm instances we keep cached in memory for speed-up
	// # Warning: this is currently unstable and may lead to crashes, best to keep for 0 unless testing locally
	// lru_size = 0`

	return customAppTemplate, customAppConfig
}
