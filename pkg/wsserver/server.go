package wsserver

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

// Config holds the WebSocket server configuration
type Config struct {
	Port            string // HTTP port for WebSocket server (e.g., ":8585")
	TendermintWSURL string // Tendermint WebSocket URL (e.g., "ws://localhost:26657/websocket")
	GRPCAddress     string // gRPC address for querying game state (e.g., "localhost:9090")
}

// DefaultConfig returns default configuration for local development
func DefaultConfig() Config {
	return Config{
		Port:            ":8585",
		TendermintWSURL: "ws://localhost:26657/websocket",
		GRPCAddress:     "localhost:9090",
	}
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for now
	},
}

// Client represents a WebSocket client connection
type Client struct {
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
	gameIDs   map[string]bool
	playerId  string // Authenticated player address for per-client card masking
	timestamp int64  // Timestamp from subscription for GameState query
	signature string // Signature from subscription for GameState query
	mu        sync.RWMutex
}

// Hub manages all client connections and game subscriptions
type Hub struct {
	clients     map[*Client]bool
	games       map[string]map[*Client]bool
	broadcast   chan *GameUpdate
	register    chan *Client
	unregister  chan *Client
	subscribe   chan *Subscription
	unsubscribe chan *Subscription
	mu          sync.RWMutex
	grpcConn    *grpc.ClientConn
	queryClient pokertypes.QueryClient
}

// Subscription represents a client subscribing to a game
type Subscription struct {
	client *Client
	gameID string
}

// GameUpdate represents a game state update to broadcast
type GameUpdate struct {
	GameID    string          `json:"game_id"`
	Timestamp time.Time       `json:"timestamp"`
	Event     string          `json:"event"`
	Data      json.RawMessage `json:"data"`
}

// ClientMessage from client
type ClientMessage struct {
	Type          string `json:"type"`
	GameID        string `json:"game_id"`
	PlayerAddress string `json:"player_address,omitempty"` // For authenticated subscriptions
	Timestamp     int64  `json:"timestamp,omitempty"`      // Unix timestamp for signature verification
	Signature     string `json:"signature,omitempty"`      // Ethereum personal_sign signature
}

// TendermintEventResponse represents the structure of a Tendermint WebSocket event
type TendermintEventResponse struct {
	ID      int    `json:"id"`
	JSONRPC string `json:"jsonrpc"`
	Result  struct {
		Query  string `json:"query"`
		Data   struct {
			Type  string `json:"type"`
			Value struct {
				TxResult struct {
					Result struct {
						Events []struct {
							Type       string `json:"type"`
							Attributes []struct {
								Key   string `json:"key"`
								Value string `json:"value"`
							} `json:"attributes"`
						} `json:"events"`
					} `json:"result"`
				} `json:"TxResult"`
			} `json:"value"`
		} `json:"data"`
		Events map[string][]string `json:"events"`
	} `json:"result"`
}

func newHub(grpcConn *grpc.ClientConn) *Hub {
	var queryClient pokertypes.QueryClient
	if grpcConn != nil {
		queryClient = pokertypes.NewQueryClient(grpcConn)
	}
	return &Hub{
		clients:     make(map[*Client]bool),
		games:       make(map[string]map[*Client]bool),
		broadcast:   make(chan *GameUpdate, 256),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		subscribe:   make(chan *Subscription),
		unsubscribe: make(chan *Subscription),
		grpcConn:    grpcConn,
		queryClient: queryClient,
	}
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("[WS-Server] Client registered. Total clients: %d", len(h.clients))

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				h.mu.Lock()
				delete(h.clients, client)

				client.mu.RLock()
				for gameID := range client.gameIDs {
					if clients, exists := h.games[gameID]; exists {
						delete(clients, client)
						if len(clients) == 0 {
							delete(h.games, gameID)
						}
					}
				}
				client.mu.RUnlock()

				close(client.send)
				h.mu.Unlock()
				log.Printf("[WS-Server] Client unregistered. Total clients: %d", len(h.clients))
			}

		case sub := <-h.subscribe:
			h.mu.Lock()
			if h.games[sub.gameID] == nil {
				h.games[sub.gameID] = make(map[*Client]bool)
			}
			h.games[sub.gameID][sub.client] = true
			h.mu.Unlock()

			sub.client.mu.Lock()
			sub.client.gameIDs[sub.gameID] = true
			sub.client.mu.Unlock()

			log.Printf("[WS-Server] Client subscribed to game %s. Subscribers: %d", sub.gameID, len(h.games[sub.gameID]))

			go h.sendGameState(sub.client, sub.gameID)

		case sub := <-h.unsubscribe:
			h.mu.Lock()
			if clients, exists := h.games[sub.gameID]; exists {
				delete(clients, sub.client)
				if len(clients) == 0 {
					delete(h.games, sub.gameID)
				}
			}
			h.mu.Unlock()

			sub.client.mu.Lock()
			delete(sub.client.gameIDs, sub.gameID)
			sub.client.mu.Unlock()

			log.Printf("[WS-Server] Client unsubscribed from game %s", sub.gameID)

		case update := <-h.broadcast:
			h.mu.RLock()
			if clients, exists := h.games[update.GameID]; exists {
				message, _ := json.Marshal(update)
				for client := range clients {
					select {
					case client.send <- message:
					default:
						close(client.send)
						delete(h.clients, client)
					}
				}
				log.Printf("[WS-Server] Broadcasted %s event to %d clients for game %s", update.Event, len(clients), update.GameID)
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) sendGameState(client *Client, gameID string) {
	if h.queryClient == nil {
		log.Printf("[WS-Server] No gRPC client available, skipping initial state for game %s", gameID)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var gameData string

	// Try authenticated query if client has credentials
	client.mu.RLock()
	hasAuth := client.playerId != "" && client.signature != ""
	playerId := client.playerId
	timestamp := client.timestamp
	signature := client.signature
	client.mu.RUnlock()

	log.Printf("[WS-Server] 🔍 sendGameState: hasAuth=%v, playerId=%s, timestamp=%d, signatureLen=%d",
		hasAuth, playerId, timestamp, len(signature))

	if hasAuth {
		// Use authenticated GameState query for per-player card masking
		log.Printf("[WS-Server] 🔐 Attempting authenticated GameState query for player %s", playerId)
		res, err := h.queryClient.GameState(ctx, &pokertypes.QueryGameStateRequest{
			GameId:        gameID,
			PlayerAddress: playerId,
			Timestamp:     timestamp,
			Signature:     signature,
		})
		if err != nil {
			log.Printf("[WS-Server] ❌ Error querying authenticated game state for %s (player %s): %v - falling back to public query",
				gameID, playerId, err)
			// Fall back to public query
			hasAuth = false
		} else {
			// Wrap GameState result to match Game query format: {"gameState": {...}}
			// The frontend expects data.gameState to contain the game state
			gameData = fmt.Sprintf(`{"gameState":%s}`, res.GameState)
			log.Printf("[WS-Server] ✅ Using authenticated GameState for player %s - response length: %d", playerId, len(res.GameState))
		}
	}

	if !hasAuth {
		// Fall back to public Game query (all cards masked)
		log.Printf("[WS-Server] 📢 Using public Game query (all cards masked)")
		res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
			GameId: gameID,
		})
		if err != nil {
			log.Printf("[WS-Server] Error querying game state for %s: %v", gameID, err)
			return
		}
		gameData = res.Game
	}

	update := &GameUpdate{
		GameID:    gameID,
		Timestamp: time.Now(),
		Event:     "state",
		Data:      json.RawMessage(gameData),
	}

	message, _ := json.Marshal(update)
	select {
	case client.send <- message:
		log.Printf("[WS-Server] 📤 Sent initial game state to client for game %s (authenticated: %v)", gameID, hasAuth)
	default:
		log.Printf("[WS-Server] Failed to send game state to client (channel full)")
	}
}

// BroadcastGameUpdate broadcasts a game state update to all subscribers
// Each client receives a personalized state with their own cards visible
func (h *Hub) BroadcastGameUpdate(gameID string, event string) {
	if h.queryClient == nil {
		log.Printf("[WS-Server] No gRPC client, broadcasting event only for game %s", gameID)
		update := &GameUpdate{
			GameID:    gameID,
			Timestamp: time.Now(),
			Event:     event,
			Data:      json.RawMessage(`{}`),
		}
		h.broadcast <- update
		return
	}

	// Get all clients subscribed to this game
	h.mu.RLock()
	clients, exists := h.games[gameID]
	if !exists || len(clients) == 0 {
		h.mu.RUnlock()
		log.Printf("[WS-Server] No subscribers for game %s", gameID)
		return
	}

	// Make a copy of client pointers to avoid holding lock during queries
	clientList := make([]*Client, 0, len(clients))
	for client := range clients {
		clientList = append(clientList, client)
	}
	h.mu.RUnlock()

	log.Printf("[WS-Server] Broadcasting %s event to %d clients for game %s", event, len(clientList), gameID)

	// Send personalized state to each client
	for _, client := range clientList {
		go h.sendPersonalizedUpdate(client, gameID, event)
	}
}

// sendPersonalizedUpdate sends a game state update to a single client with their cards visible
func (h *Hub) sendPersonalizedUpdate(client *Client, gameID string, event string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var gameData string

	// Check if client has authentication credentials
	client.mu.RLock()
	hasAuth := client.playerId != "" && client.signature != ""
	playerId := client.playerId
	timestamp := client.timestamp
	signature := client.signature
	client.mu.RUnlock()

	if hasAuth {
		// Use authenticated GameState query for per-player card masking
		res, err := h.queryClient.GameState(ctx, &pokertypes.QueryGameStateRequest{
			GameId:        gameID,
			PlayerAddress: playerId,
			Timestamp:     timestamp,
			Signature:     signature,
		})
		if err != nil {
			log.Printf("[WS-Server] Error querying authenticated game state for broadcast (player %s): %v - falling back to public query",
				playerId, err)
			hasAuth = false
		} else {
			// Wrap GameState result to match Game query format: {"gameState": {...}}
			// The frontend expects data.gameState to contain the game state
			gameData = fmt.Sprintf(`{"gameState":%s}`, res.GameState)
		}
	}

	if !hasAuth {
		// Fall back to public Game query (all cards masked)
		res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
			GameId: gameID,
		})
		if err != nil {
			log.Printf("[WS-Server] Error querying game for broadcast: %v", err)
			return
		}
		gameData = res.Game
	}

	update := &GameUpdate{
		GameID:    gameID,
		Timestamp: time.Now(),
		Event:     event,
		Data:      json.RawMessage(gameData),
	}

	message, _ := json.Marshal(update)
	select {
	case client.send <- message:
		// Message sent successfully
	default:
		log.Printf("[WS-Server] Failed to send update to client (channel full)")
	}
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WS-Server] WebSocket error: %v", err)
			}
			break
		}

		// Log raw message for debugging
		log.Printf("[WS-Server] 📥 Raw message received: %s", string(message))

		var msg ClientMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("[WS-Server] Error unmarshaling message: %v", err)
			continue
		}

		log.Printf("[WS-Server] 📋 Parsed message: type=%s, game_id=%s, player_address=%s, timestamp=%d, has_signature=%v",
			msg.Type, msg.GameID, msg.PlayerAddress, msg.Timestamp, msg.Signature != "")

		switch msg.Type {
		case "subscribe":
			if msg.GameID != "" {
				// Store authenticated player credentials for per-client card masking
				if msg.PlayerAddress != "" {
					c.mu.Lock()
					c.playerId = msg.PlayerAddress
					c.timestamp = msg.Timestamp
					c.signature = msg.Signature
					c.mu.Unlock()
					log.Printf("[WS-Server] ✅ Client authenticated as player: %s (timestamp: %d, signature length: %d)",
						msg.PlayerAddress, msg.Timestamp, len(msg.Signature))
				} else {
					log.Printf("[WS-Server] ⚠️ Subscribe without player_address - will use public query")
				}
				c.hub.subscribe <- &Subscription{
					client: c,
					gameID: msg.GameID,
				}
			}
		case "unsubscribe":
			if msg.GameID != "" {
				c.hub.unsubscribe <- &Subscription{
					client: c,
					gameID: msg.GameID,
				}
			}
		case "ping":
			pong := map[string]string{"type": "pong"}
			pongBytes, _ := json.Marshal(pong)
			c.send <- pongBytes
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS-Server] Upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:     hub,
		conn:    conn,
		send:    make(chan []byte, 256),
		gameIDs: make(map[string]bool),
	}
	client.hub.register <- client

	go client.writePump()
	go client.readPump()
}

// subscribeTendermintEvents connects to Tendermint WebSocket and subscribes to poker module events
func subscribeTendermintEvents(hub *Hub, tendermintWSURL string) {
	log.Printf("[WS-Server] Connecting to Tendermint WebSocket at %s...", tendermintWSURL)

	for {
		conn, _, err := websocket.DefaultDialer.Dial(tendermintWSURL, nil)
		if err != nil {
			log.Printf("[WS-Server] Failed to connect to Tendermint WebSocket: %v. Retrying in 5 seconds...", err)
			time.Sleep(5 * time.Second)
			continue
		}

		log.Println("[WS-Server] Connected to Tendermint WebSocket")

		subscribeToEvent(conn, "action_performed", 1)
		subscribeToEvent(conn, "player_joined_game", 2)
		subscribeToEvent(conn, "game_created", 3)

		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("[WS-Server] Tendermint WebSocket read error: %v. Reconnecting...", err)
				conn.Close()
				break
			}

			var response TendermintEventResponse
			if err := json.Unmarshal(message, &response); err != nil {
				log.Printf("[WS-Server] Failed to parse Tendermint event: %v", err)
				continue
			}

			if response.Result.Query == "" {
				continue
			}

			processBlockEvent(hub, response)
		}
	}
}

func subscribeToEvent(conn *websocket.Conn, eventType string, id int) {
	query := fmt.Sprintf("%s.game_id EXISTS", eventType)

	subscribeRequest := map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"method":  "subscribe",
		"params": map[string]interface{}{
			"query": fmt.Sprintf("tm.event='Tx' AND %s", query),
		},
	}

	requestBytes, _ := json.Marshal(subscribeRequest)
	if err := conn.WriteMessage(websocket.TextMessage, requestBytes); err != nil {
		log.Printf("[WS-Server] Failed to subscribe to %s events: %v", eventType, err)
	} else {
		log.Printf("[WS-Server] Subscribed to %s events", eventType)
	}
}

func processBlockEvent(hub *Hub, response TendermintEventResponse) {
	if response.Result.Events == nil {
		return
	}

	eventTypes := []string{"action_performed", "player_joined_game", "game_created"}

	for _, eventType := range eventTypes {
		gameIDKey := eventType + ".game_id"
		if gameIDs, ok := response.Result.Events[gameIDKey]; ok && len(gameIDs) > 0 {
			for _, gameID := range gameIDs {
				log.Printf("[WS-Server] Tendermint event received: %s for game %s", eventType, gameID)
				hub.BroadcastGameUpdate(gameID, eventType)
			}
		}
	}
}

// Start starts the WebSocket server with the given configuration
// This function blocks, so call it in a goroutine if needed
func Start(cfg Config) error {
	log.Printf("[WS-Server] Starting WebSocket server on %s", cfg.Port)

	// Create gRPC connection (optional - for querying game state)
	var grpcConn *grpc.ClientConn
	var err error
	if cfg.GRPCAddress != "" {
		grpcConn, err = grpc.Dial(cfg.GRPCAddress, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			log.Printf("[WS-Server] Warning: Failed to connect to gRPC at %s: %v (continuing without game state queries)", cfg.GRPCAddress, err)
			grpcConn = nil
		} else {
			log.Printf("[WS-Server] Connected to gRPC at %s", cfg.GRPCAddress)
		}
	}

	hub := newHub(grpcConn)
	go hub.run()

	// Start Tendermint event subscription
	go subscribeTendermintEvents(hub, cfg.TendermintWSURL)

	// HTTP endpoints
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":       "ok",
			"clients":      len(hub.clients),
			"active_games": len(hub.games),
		})
	})

	http.HandleFunc("/trigger", func(w http.ResponseWriter, r *http.Request) {
		gameID := r.URL.Query().Get("game_id")
		event := r.URL.Query().Get("event")
		if gameID != "" && event != "" {
			hub.BroadcastGameUpdate(gameID, event)
			w.Write([]byte(fmt.Sprintf("Triggered %s event for game %s", event, gameID)))
		} else {
			http.Error(w, "Missing game_id or event parameter", http.StatusBadRequest)
		}
	})

	log.Printf("[WS-Server] WebSocket endpoint: ws://localhost%s/ws", cfg.Port)
	log.Printf("[WS-Server] Health check: http://localhost%s/health", cfg.Port)

	return http.ListenAndServe(cfg.Port, nil)
}

// StartAsync starts the WebSocket server in a background goroutine
func StartAsync(cfg Config) {
	go func() {
		if err := Start(cfg); err != nil {
			log.Printf("[WS-Server] Error: %v", err)
		}
	}()
}
