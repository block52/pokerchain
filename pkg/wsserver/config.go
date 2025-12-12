package wsserver

import (
	"os"
	"strings"
)

// Config holds the WebSocket server configuration
type Config struct {
	Port            string // HTTP port for WebSocket server (e.g., ":8585")
	TendermintWSURL string // Tendermint WebSocket URL (e.g., "ws://localhost:26657/websocket")
	GRPCAddress     string // gRPC address for querying game state (e.g., "localhost:9090")
	AddressPrefix   string // Bech32 address prefix (e.g., "b52")
	UseTLS          bool   // Whether to use TLS for gRPC connection
}

// DefaultConfig returns default configuration for local development
func DefaultConfig() Config {
	return Config{
		Port:            ":8585",
		TendermintWSURL: "ws://localhost:26657/websocket",
		GRPCAddress:     "localhost:9090",
		AddressPrefix:   "b52",
		UseTLS:          false,
	}
}

// ProductionConfig returns default configuration for production
func ProductionConfig() Config {
	return Config{
		Port:            ":8585",
		TendermintWSURL: "ws://localhost:26657/websocket",
		GRPCAddress:     "node.texashodl.net:9443",
		AddressPrefix:   "b52",
		UseTLS:          true,
	}
}

// ConfigFromEnv loads configuration from environment variables with defaults
func ConfigFromEnv() Config {
	cfg := Config{
		Port:            getEnv("WS_SERVER_PORT", ":8585"),
		TendermintWSURL: getEnv("TENDERMINT_WS_URL", "ws://localhost:26657/websocket"),
		GRPCAddress:     getEnv("GRPC_URL", "node.texashodl.net:9443"),
		AddressPrefix:   getEnv("ADDRESS_PREFIX", "b52"),
	}

	// Ensure port has colon prefix
	if !strings.HasPrefix(cfg.Port, ":") {
		cfg.Port = ":" + cfg.Port
	}

	// Auto-detect TLS based on gRPC address (use TLS for non-local addresses)
	cfg.UseTLS = !isLocalAddress(cfg.GRPCAddress)

	return cfg
}

// getEnv returns environment variable value or default
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// isLocalAddress checks if the address is a local endpoint
func isLocalAddress(addr string) bool {
	return strings.HasPrefix(addr, "localhost") ||
		strings.HasPrefix(addr, "127.0.0.1") ||
		strings.HasPrefix(addr, "0.0.0.0")
}
