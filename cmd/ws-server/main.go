package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"

	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/std"
	sdk "github.com/cosmos/cosmos-sdk/types"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

// Default configuration values (production)
const (
	defaultGRPCURL         = "node.texashodl.net:9443"
	defaultAddressPrefix   = "b52"
	defaultTendermintWSURL = "ws://localhost:26657/websocket"
	defaultServerPort      = ":8585"
)

// getEnv returns environment variable value or default
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// isLocalGRPC checks if the gRPC URL is a local endpoint
func isLocalGRPC(url string) bool {
	return strings.HasPrefix(url, "localhost") ||
		strings.HasPrefix(url, "127.0.0.1") ||
		strings.HasPrefix(url, "0.0.0.0")
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
	gameIDs   map[string]bool // Games this client is subscribed to
	playerId  string          // Authenticated player address for per-client card masking
	timestamp int64           // Timestamp from subscription for GameState query
	signature string          // Signature from subscription for GameState query
	mu        sync.RWMutex
}

// Hub manages all client connections and game subscriptions
type Hub struct {
	clients       map[*Client]bool
	games         map[string]map[*Client]bool // gameID -> clients
	broadcast     chan *GameUpdate
	register      chan *Client
	unregister    chan *Client
	subscribe     chan *Subscription
	unsubscribe   chan *Subscription
	mu            sync.RWMutex
	grpcConn      *grpc.ClientConn
	queryClient   pokertypes.QueryClient
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
	Event     string          `json:"event"` // "action", "join", "leave", "state_change"
	Data      json.RawMessage `json:"data"`
}

// Message from client
type ClientMessage struct {
	Type          string `json:"type"`   // "subscribe", "unsubscribe", "ping", "action"
	GameID        string `json:"game_id"`
	PlayerAddress string `json:"player_address,omitempty"` // For authenticated subscriptions
	Timestamp     int64  `json:"timestamp,omitempty"`      // Unix timestamp for signature verification
	Signature     string `json:"signature,omitempty"`      // Ethereum personal_sign signature

	// Action relay fields - for optimistic updates
	Action string `json:"action,omitempty"` // "fold", "call", "raise", "check", "bet", "all_in"
	Amount string `json:"amount,omitempty"` // For raise/bet actions (as string to handle big numbers)
}

// PendingAction represents an action that has been accepted but not yet confirmed
type PendingAction struct {
	GameID string `json:"game_id"`
	Actor  string `json:"actor"`
	Action string `json:"action"`
	Amount string `json:"amount,omitempty"`
}

func newHub(grpcConn *grpc.ClientConn) *Hub {
	return &Hub{
		clients:     make(map[*Client]bool),
		games:       make(map[string]map[*Client]bool),
		broadcast:   make(chan *GameUpdate, 256),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		subscribe:   make(chan *Subscription),
		unsubscribe: make(chan *Subscription),
		grpcConn:    grpcConn,
		queryClient: pokertypes.NewQueryClient(grpcConn),
	}
}

func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("Client registered. Total clients: %d", len(h.clients))

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				h.mu.Lock()
				delete(h.clients, client)

				// Unsubscribe from all games
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
				log.Printf("Client unregistered. Total clients: %d", len(h.clients))
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

			log.Printf("Client subscribed to game %s. Subscribers: %d", sub.gameID, len(h.games[sub.gameID]))

			// Send current game state to newly subscribed client
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

			log.Printf("Client unsubscribed from game %s", sub.gameID)

		case update := <-h.broadcast:
			h.mu.RLock()
			if clients, exists := h.games[update.GameID]; exists {
				message, _ := json.Marshal(update)

				// Log the exact message being sent to clients
				log.Printf("[HUB] 📤 Broadcasting to %d clients for game %s", len(clients), update.GameID)
				log.Printf("[HUB] Message structure: game_id=%s event=%s data_length=%d",
					update.GameID, update.Event, len(update.Data))

				// Log preview of message
				msgPreview := string(message)
				if len(msgPreview) > 500 {
					msgPreview = msgPreview[:500] + "..."
				}
				log.Printf("[HUB] Full message preview: %s", msgPreview)

				for client := range clients {
					select {
					case client.send <- message:
						log.Printf("[HUB] ✓ Sent to client")
					default:
						// Client's send channel is full, close it
						log.Printf("[HUB] ❌ Client send buffer full, closing")
						close(client.send)
						delete(h.clients, client)
					}
				}
			} else {
				log.Printf("[HUB] ⚠️ No subscribers for game %s", update.GameID)
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) sendGameState(client *Client, gameID string) {
	log.Printf("[GRPC] Querying game state for gameID=%s", gameID)
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

	log.Printf("[GRPC] 🔍 sendGameState: hasAuth=%v, playerId=%s, timestamp=%d, signatureLen=%d",
		hasAuth, playerId, timestamp, len(signature))

	if hasAuth {
		// Use authenticated GameState query for per-player card masking
		log.Printf("[GRPC] 🔐 Attempting authenticated GameState query for player %s", playerId)
		res, err := h.queryClient.GameState(ctx, &pokertypes.QueryGameStateRequest{
			GameId:        gameID,
			PlayerAddress: playerId,
			Timestamp:     timestamp,
			Signature:     signature,
		})
		if err != nil {
			log.Printf("[GRPC] ❌ Error querying authenticated game state for %s (player %s): %v - falling back to public query",
				gameID, playerId, err)
			// Fall back to public query
			hasAuth = false
		} else {
			// Wrap GameState result to match Game query format: {"gameState": {...}}
			// The frontend expects data.gameState to contain the game state
			gameData = fmt.Sprintf(`{"gameState":%s}`, res.GameState)
			log.Printf("[GRPC] ✅ Using authenticated GameState for player %s - response length: %d", playerId, len(res.GameState))
		}
	}

	if !hasAuth {
		// Fall back to public Game query (all cards masked)
		log.Printf("[GRPC] 📢 Using public Game query (all cards masked)")
		res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
			GameId: gameID,
		})
		if err != nil {
			log.Printf("[GRPC] ❌ Error querying game state for %s: %v", gameID, err)
			return
		}
		gameData = res.Game
	}

	// Log the response for debugging
	log.Printf("[GRPC] ✓ Got game state response, length=%d bytes", len(gameData))
	if len(gameData) > 0 {
		preview := gameData
		if len(preview) > 500 {
			preview = preview[:500] + "..."
		}
		log.Printf("[GRPC] Game data preview: %s", preview)
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
		log.Printf("[SEND] ✓ Sent initial game state to client for game %s (%d bytes, authenticated: %v)", gameID, len(message), hasAuth)
	default:
		log.Printf("[SEND] ❌ Failed to send game state to client (channel full)")
	}
}

// BroadcastGameUpdate broadcasts a game state update to all subscribers
// Each client receives a personalized state with their own cards visible
func (h *Hub) BroadcastGameUpdate(gameID string, event string) {
	log.Printf("[BROADCAST] Starting broadcast for gameID=%s event=%s", gameID, event)

	// Get all clients subscribed to this game
	h.mu.RLock()
	clients, exists := h.games[gameID]
	if !exists || len(clients) == 0 {
		h.mu.RUnlock()
		log.Printf("[BROADCAST] No subscribers for game %s", gameID)
		return
	}

	// Make a copy of client pointers to avoid holding lock during queries
	clientList := make([]*Client, 0, len(clients))
	for client := range clients {
		clientList = append(clientList, client)
	}
	h.mu.RUnlock()

	log.Printf("[BROADCAST] Broadcasting %s event to %d clients for game %s", event, len(clientList), gameID)

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
			log.Printf("[BROADCAST] ❌ Error querying authenticated game state for broadcast (player %s): %v - falling back to public query",
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
			log.Printf("[BROADCAST] ❌ Error querying game for broadcast: %v", err)
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
		log.Printf("[BROADCAST] ❌ Failed to send update to client (channel full)")
	}
}

// handleAction processes an action message from a client and broadcasts pending state
// This enables optimistic updates - all subscribers see the action immediately
func (h *Hub) handleAction(client *Client, msg ClientMessage) {
	// Get player address from client auth or message
	client.mu.RLock()
	playerAddress := client.playerId
	client.mu.RUnlock()

	if playerAddress == "" {
		playerAddress = msg.PlayerAddress
	}

	if playerAddress == "" {
		log.Printf("[ACTION] ❌ Action rejected: no player address")
		client.sendError("No player address provided")
		return
	}

	log.Printf("[ACTION] 🚀 Processing action: game=%s, player=%s, action=%s, amount=%s",
		msg.GameID, playerAddress, msg.Action, msg.Amount)

	// Broadcast pending state immediately to all subscribers
	pendingAction := &PendingAction{
		GameID: msg.GameID,
		Actor:  playerAddress,
		Action: msg.Action,
		Amount: msg.Amount,
	}

	h.broadcastPendingState(pendingAction)

	// Send acknowledgment to the acting client
	ack := map[string]interface{}{
		"event":   "action_accepted",
		"game_id": msg.GameID,
		"action":  msg.Action,
		"status":  "pending",
	}
	ackBytes, _ := json.Marshal(ack)
	select {
	case client.send <- ackBytes:
		log.Printf("[ACTION] ✅ Action acknowledged to client")
	default:
		log.Printf("[ACTION] ⚠️ Failed to send ack (channel full)")
	}
}

// broadcastPendingState sends a pending action notification to all game subscribers
func (h *Hub) broadcastPendingState(pending *PendingAction) {
	h.mu.RLock()
	clients, exists := h.games[pending.GameID]
	if !exists || len(clients) == 0 {
		h.mu.RUnlock()
		log.Printf("[PENDING] No subscribers for pending state: game=%s", pending.GameID)
		return
	}

	// Make a copy of client pointers
	clientList := make([]*Client, 0, len(clients))
	for client := range clients {
		clientList = append(clientList, client)
	}
	h.mu.RUnlock()

	// Create pending update message
	pendingData, _ := json.Marshal(pending)
	update := &GameUpdate{
		GameID:    pending.GameID,
		Timestamp: time.Now(),
		Event:     "pending",
		Data:      pendingData,
	}

	message, _ := json.Marshal(update)

	// Broadcast to all subscribers
	for _, client := range clientList {
		select {
		case client.send <- message:
			// Sent successfully
		default:
			log.Printf("[PENDING] ❌ Failed to send pending state to client (channel full)")
		}
	}

	log.Printf("[PENDING] 📢 Broadcasted pending action to %d clients: game=%s, action=%s",
		len(clientList), pending.GameID, pending.Action)
}

// sendError sends an error message to the client
func (c *Client) sendError(message string) {
	errorMsg := map[string]interface{}{
		"event":   "error",
		"message": message,
	}
	errorBytes, _ := json.Marshal(errorMsg)
	select {
	case c.send <- errorBytes:
	default:
		log.Printf("[CLIENT] ❌ Failed to send error to client (channel full)")
	}
}

func (c *Client) readPump() {
	defer func() {
		log.Printf("[CLIENT] readPump ending, unregistering client")
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
				log.Printf("[CLIENT] ❌ WebSocket read error: %v", err)
			}
			break
		}

		// Log raw message from client
		log.Printf("[CLIENT] 📥 Received message: %s", string(message))

		var msg ClientMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("[CLIENT] ❌ Error unmarshaling message: %v", err)
			continue
		}

		log.Printf("[CLIENT] Parsed message: type=%s game_id=%s player_address=%s timestamp=%d has_signature=%v",
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
					log.Printf("[CLIENT] ✅ Client authenticated as player: %s (timestamp: %d, signature length: %d)",
						msg.PlayerAddress, msg.Timestamp, len(msg.Signature))
				} else {
					log.Printf("[CLIENT] ⚠️ Subscribe without player_address - will use public query (all cards masked)")
				}
				log.Printf("[CLIENT] 📌 Subscribing to game: %s", msg.GameID)
				c.hub.subscribe <- &Subscription{
					client: c,
					gameID: msg.GameID,
				}
			}
		case "unsubscribe":
			if msg.GameID != "" {
				log.Printf("[CLIENT] 📌 Unsubscribing from game: %s", msg.GameID)
				c.hub.unsubscribe <- &Subscription{
					client: c,
					gameID: msg.GameID,
				}
			}
		case "ping":
			log.Printf("[CLIENT] 🏓 Received ping, sending pong")
			pong := map[string]string{"type": "pong"}
			pongBytes, _ := json.Marshal(pong)
			c.send <- pongBytes

		case "action":
			// Handle action relay for optimistic updates
			if msg.GameID != "" && msg.Action != "" {
				log.Printf("[CLIENT] 🎯 Action received: game=%s, action=%s, amount=%s, player=%s",
					msg.GameID, msg.Action, msg.Amount, msg.PlayerAddress)
				go c.hub.handleAction(c, msg)
			} else {
				log.Printf("[CLIENT] ⚠️ Invalid action message: missing game_id or action")
				c.sendError("Invalid action message: missing game_id or action")
			}

		default:
			log.Printf("[CLIENT] ⚠️ Unknown message type: %s", msg.Type)
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

			// Add queued messages to current websocket message
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
		log.Printf("Upgrade error: %v", err)
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

func main() {
	// Load configuration from environment variables
	grpcURL := getEnv("GRPC_URL", defaultGRPCURL)
	addressPrefix := getEnv("ADDRESS_PREFIX", defaultAddressPrefix)
	tendermintWSURL := getEnv("TENDERMINT_WS_URL", defaultTendermintWSURL)
	serverPort := getEnv("WS_SERVER_PORT", defaultServerPort)

	// Ensure port has colon prefix
	if !strings.HasPrefix(serverPort, ":") {
		serverPort = ":" + serverPort
	}

	// Log configuration
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Println("Poker WebSocket Server Configuration")
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("  GRPC_URL:          %s", grpcURL)
	log.Printf("  ADDRESS_PREFIX:    %s", addressPrefix)
	log.Printf("  TENDERMINT_WS_URL: %s", tendermintWSURL)
	log.Printf("  WS_SERVER_PORT:    %s", serverPort)
	log.Printf("  TLS:               %v", !isLocalGRPC(grpcURL))
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	// Set address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(addressPrefix, addressPrefix+"pub")
	config.Seal()

	// Create gRPC connection with TLS or insecure based on endpoint
	log.Println("Connecting to blockchain via gRPC...")
	var grpcConn *grpc.ClientConn
	var err error

	if isLocalGRPC(grpcURL) {
		// Local development - use insecure connection
		log.Println("Using insecure gRPC connection (local development)")
		grpcConn, err = grpc.Dial(grpcURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	} else {
		// Production - use TLS
		log.Println("Using TLS gRPC connection (production)")
		creds := credentials.NewTLS(nil)
		grpcConn, err = grpc.Dial(grpcURL, grpc.WithTransportCredentials(creds))
	}

	if err != nil {
		log.Fatalf("Failed to connect to gRPC: %v", err)
	}
	defer grpcConn.Close()
	log.Printf("Connected to gRPC at %s", grpcURL)

	hub := newHub(grpcConn)
	go hub.run()

	// Start Tendermint event subscription (subscribes to poker module events)
	go subscribeTendermintEvents(hub, tendermintWSURL)

	// HTTP endpoints
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":          "ok",
			"clients":         len(hub.clients),
			"active_games":    len(hub.games),
			"grpc_url":        grpcURL,
			"tendermint_ws":   tendermintWSURL,
		})
	})

	http.HandleFunc("/trigger", func(w http.ResponseWriter, r *http.Request) {
		// Manual trigger endpoint for testing
		gameID := r.URL.Query().Get("game_id")
		event := r.URL.Query().Get("event")
		if gameID != "" && event != "" {
			hub.BroadcastGameUpdate(gameID, event)
			w.Write([]byte(fmt.Sprintf("Triggered %s event for game %s", event, gameID)))
		} else {
			http.Error(w, "Missing game_id or event parameter", http.StatusBadRequest)
		}
	})

	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("WebSocket server starting on %s", serverPort)
	log.Printf("WebSocket endpoint: ws://localhost%s/ws", serverPort)
	log.Printf("Health check: http://localhost%s/health", serverPort)
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if err := http.ListenAndServe(serverPort, nil); err != nil {
		log.Fatalf("ListenAndServe error: %v", err)
	}
}

// subscribeTendermintEvents connects to Tendermint WebSocket and subscribes to poker module events
func subscribeTendermintEvents(hub *Hub, tendermintWSURL string) {
	// Connect to Tendermint WebSocket
	log.Printf("[TENDERMINT] 🔌 Connecting to Tendermint WebSocket at %s...", tendermintWSURL)

	for {
		conn, _, err := websocket.DefaultDialer.Dial(tendermintWSURL, nil)
		if err != nil {
			log.Printf("[TENDERMINT] ❌ Failed to connect to Tendermint WebSocket: %v. Retrying in 5 seconds...", err)
			time.Sleep(5 * time.Second)
			continue
		}

		log.Println("[TENDERMINT] ✅ Connected to Tendermint WebSocket")

		// Subscribe to poker module events
		subscribeToEvent(conn, "action_performed", 1)
		subscribeToEvent(conn, "player_joined_game", 2)
		subscribeToEvent(conn, "game_created", 3)

		// Read events from Tendermint
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("[TENDERMINT] ❌ WebSocket read error: %v. Reconnecting...", err)
				conn.Close()
				break
			}

			// Log raw Tendermint message
			msgPreview := string(message)
			if len(msgPreview) > 300 {
				msgPreview = msgPreview[:300] + "..."
			}
			log.Printf("[TENDERMINT] 📥 Raw message: %s", msgPreview)

			// Parse the Tendermint event response
			var response TendermintEventResponse
			if err := json.Unmarshal(message, &response); err != nil {
				log.Printf("[TENDERMINT] ❌ Failed to parse event: %v", err)
				continue
			}

			// Skip subscription confirmations
			if response.Result.Query == "" {
				log.Printf("[TENDERMINT] ⏭️ Skipping subscription confirmation (id=%d)", response.ID)
				continue
			}

			log.Printf("[TENDERMINT] 📋 Event query: %s", response.Result.Query)
			if response.Result.Events != nil {
				log.Printf("[TENDERMINT] 📋 Events map keys: %v", getMapKeys(response.Result.Events))
			}

			// Extract game_id from events and broadcast
			processBlockEvent(hub, response)
		}
	}
}

// getMapKeys returns the keys of a map for logging
func getMapKeys(m map[string][]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
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

// subscribeToEvent sends a subscription request for a specific event type
func subscribeToEvent(conn *websocket.Conn, eventType string, id int) {
	// Cosmos SDK events are queried using the format: message.action='event_type'
	// Or for custom events: event_type.attribute_key='value'
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
		log.Printf("Failed to subscribe to %s events: %v", eventType, err)
	} else {
		log.Printf("Subscribed to %s events", eventType)
	}
}

// processBlockEvent extracts game_id from Tendermint events and broadcasts updates
func processBlockEvent(hub *Hub, response TendermintEventResponse) {
	// Check if we have events in the response
	if response.Result.Events == nil {
		log.Printf("[PROCESS] ⚠️ No events in response")
		return
	}

	log.Printf("[PROCESS] Processing event with %d event types", len(response.Result.Events))

	// Look for poker-related events
	eventTypes := []string{"action_performed", "player_joined_game", "game_created"}

	foundEvent := false
	for _, eventType := range eventTypes {
		// Check for game_id attribute in events
		gameIDKey := eventType + ".game_id"
		if gameIDs, ok := response.Result.Events[gameIDKey]; ok && len(gameIDs) > 0 {
			foundEvent = true
			for _, gameID := range gameIDs {
				log.Printf("[PROCESS] 🎮 Found %s event for game_id=%s", eventType, gameID)
				hub.BroadcastGameUpdate(gameID, eventType)
			}
		}
	}

	if !foundEvent {
		// Log all available keys to help debug
		log.Printf("[PROCESS] ⚠️ No poker events found. Available event keys:")
		for key, values := range response.Result.Events {
			log.Printf("[PROCESS]   - %s: %v", key, values)
		}
	}
}

func makeEncodingConfig() struct {
	InterfaceRegistry codectypes.InterfaceRegistry
	Codec             codec.Codec
} {
	amino := codec.NewLegacyAmino()
	interfaceRegistry := codectypes.NewInterfaceRegistry()
	cdc := codec.NewProtoCodec(interfaceRegistry)

	std.RegisterLegacyAminoCodec(amino)
	std.RegisterInterfaces(interfaceRegistry)
	authtypes.RegisterInterfaces(interfaceRegistry)
	pokertypes.RegisterInterfaces(interfaceRegistry)

	return struct {
		InterfaceRegistry codectypes.InterfaceRegistry
		Codec             codec.Codec
	}{
		InterfaceRegistry: interfaceRegistry,
		Codec:             cdc,
	}
}
