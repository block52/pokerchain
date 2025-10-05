package app

// BridgeConfig contains configuration for the Ethereum bridge
type BridgeConfig struct {
	// Enabled determines if the bridge should be started
	Enabled bool `mapstructure:"enabled"`

	// EthereumRPCURL is the URL of the Ethereum RPC endpoint
	EthereumRPCURL string `mapstructure:"ethereum_rpc_url"`

	// DepositContractAddress is the address of the USDC deposit contract on Ethereum
	DepositContractAddress string `mapstructure:"deposit_contract_address"`

	// USDCContractAddress is the address of the USDC token contract on Ethereum
	USDCContractAddress string `mapstructure:"usdc_contract_address"`

	// PollingIntervalSeconds defines how often to check for new deposits
	PollingIntervalSeconds int `mapstructure:"polling_interval_seconds"`

	// StartingBlock is the Ethereum block number to start monitoring from
	StartingBlock uint64 `mapstructure:"starting_block"`
}

// DefaultBridgeConfig returns default configuration for the bridge
func DefaultBridgeConfig() BridgeConfig {
	return BridgeConfig{
		Enabled:                false,                                        // Disabled by default
		EthereumRPCURL:         "https://eth.llamarpc.com",                   // Free public RPC
		DepositContractAddress: "",                                           // Must be set in config
		USDCContractAddress:    "0xA0b86a33E6d3D24fDbCBFe003eDa2E26A6E73a60", // Mainnet USDC
		PollingIntervalSeconds: 15,
		StartingBlock:          0, // Will use latest block - 10 if 0
	}
}
