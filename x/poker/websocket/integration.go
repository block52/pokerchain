package websocket

import (
	"fmt"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/rs/zerolog/log"

	"github.com/cosmos/cosmos-sdk/server/api"
	"github.com/cosmos/cosmos-sdk/server/config"
)

// Config holds the WebSocket server configuration
type Config struct {
	Enabled        bool   `mapstructure:"enabled"`
	CometBftRpcUrl string `mapstructure:"cometbft_rpc_url"`
	ListenPort     string `mapstructure:"listen_port"`
}

// DefaultConfig returns default WebSocket configuration
func DefaultConfig() Config {
	return Config{
		Enabled:        true,
		CometBftRpcUrl: "tcp://localhost:26657",
		ListenPort:     ":3000",
	}
}

// Manager manages the WebSocket server lifecycle
type Manager struct {
	server     *Server
	httpServer *http.Server
	config     Config
}

// NewManager creates a new WebSocket manager
func NewManager(cfg Config) (*Manager, error) {
	if !cfg.Enabled {
		log.Info().Msg("WebSocket server is disabled")
		return &Manager{config: cfg}, nil
	}

	server, err := NewServer(cfg.CometBftRpcUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to create WebSocket server: %w", err)
	}

	return &Manager{
		server: server,
		config: cfg,
	}, nil
}

// Start starts the WebSocket server
func (m *Manager) Start() error {
	if !m.config.Enabled || m.server == nil {
		return nil
	}

	// Start event processing
	if err := m.server.Start(); err != nil {
		return fmt.Errorf("failed to start WebSocket server: %w", err)
	}

	// Setup HTTP server with routes
	router := mux.NewRouter()
	handler := NewHTTPHandler(m.server)

	router.HandleFunc("/ws/game/{gameId}", handler.ServeHTTP)
	router.HandleFunc("/health", HealthCheckHandler)

	m.httpServer = &http.Server{
		Addr:    m.config.ListenPort,
		Handler: router,
	}

	// Start HTTP server in goroutine
	go func() {
		log.Info().
			Str("address", m.config.ListenPort).
			Msg("Starting WebSocket HTTP server")

		if err := m.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("WebSocket HTTP server error")
		}
	}()

	return nil
}

// Stop stops the WebSocket server
func (m *Manager) Stop() error {
	if m.server != nil {
		if err := m.server.Stop(); err != nil {
			return err
		}
	}

	if m.httpServer != nil {
		return m.httpServer.Close()
	}

	return nil
}

// RegisterRoutes registers WebSocket routes with the API server (optional)
// This allows WebSocket to be served alongside the REST API
func (m *Manager) RegisterRoutes(apiSvr *api.Server, apiConfig config.APIConfig) {
	if !m.config.Enabled || m.server == nil {
		return
	}

	handler := NewHTTPHandler(m.server)

	// Register WebSocket endpoint with the API router
	apiSvr.Router.HandleFunc("/ws/game/{gameId}", handler.ServeHTTP)
	apiSvr.Router.HandleFunc("/ws/health", HealthCheckHandler)

	log.Info().Msg("WebSocket routes registered with API server")
}
