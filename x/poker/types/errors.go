package types

// DONTCOVER

import (
	"cosmossdk.io/errors"
)

// x/poker module sentinel errors
var (
	ErrInvalidSigner      = errors.Register(ModuleName, 1100, "expected gov account as only signer for proposal message")
	ErrTxAlreadyProcessed = errors.Register(ModuleName, 1101, "ethereum transaction already processed")
	ErrInvalidAmount      = errors.Register(ModuleName, 1102, "invalid mint amount")
	ErrInvalidRecipient   = errors.Register(ModuleName, 1103, "invalid recipient address")
	ErrInvalidRequest     = errors.Register(ModuleName, 1104, "invalid request")
	ErrInvalidAction      = errors.Register(ModuleName, 1105, "invalid poker action")
	ErrGameNotFound       = errors.Register(ModuleName, 1106, "game not found")
)
