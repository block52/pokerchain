package websocket

import (
	"net/http"
	"strings"

	"github.com/rs/zerolog/log"
)

// HTTPHandler manages HTTP routing for WebSocket connections
type HTTPHandler struct {
	server *Server
}

// NewHTTPHandler creates a new HTTP handler for WebSocket connections
func NewHTTPHandler(server *Server) *HTTPHandler {
	return &HTTPHandler{
		server: server,
	}
}

// ServeHTTP handles WebSocket connection requests
// Expected path format: /ws/game/{gameId}
func (h *HTTPHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Parse game ID from path
	path := r.URL.Path
	if !strings.HasPrefix(path, "/ws/game/") {
		http.Error(w, "Invalid path. Expected /ws/game/{gameId}", http.StatusBadRequest)
		return
	}

	gameId := strings.TrimPrefix(path, "/ws/game/")
	if gameId == "" {
		http.Error(w, "Game ID is required", http.StatusBadRequest)
		return
	}

	log.Info().
		Str("game_id", gameId).
		Str("remote_addr", r.RemoteAddr).
		Msg("WebSocket connection request")

	// Handle WebSocket upgrade and connection
	h.server.HandleConnection(w, r, gameId)
}

// HealthCheckHandler provides a health check endpoint
func HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok","service":"poker-websocket"}`))
}
