package app

// PVMConfig contains configuration for the Poker Virtual Machine
type PVMConfig struct {
	// PVMURL is the URL of the PVM RPC endpoint
	PVMURL string `mapstructure:"pvm_url"`
}

// DefaultPVMConfig returns default configuration for the PVM
func DefaultPVMConfig() PVMConfig {
	return PVMConfig{
		PVMURL: "http://localhost:8545", // Default to local PVM
	}
}
