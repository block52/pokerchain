package main

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
	"google.golang.org/grpc/credentials"

	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/std"
	sdk "github.com/cosmos/cosmos-sdk/types"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

const (
	grpcURL       = "node.texashodl.net:9443"
	addressPrefix = "b52"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for now
	},
}

// Client represents a WebSocket client connection
type Client struct {
	hub     *Hub
	conn    *websocket.Conn
	send    chan []byte
	gameIDs map[string]bool // Games this client is subscribed to
	mu      sync.RWMutex
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
	Type   string `json:"type"`   // "subscribe", "unsubscribe", "ping"
	GameID string `json:"game_id"`
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
				for client := range clients {
					select {
					case client.send <- message:
					default:
						// Client's send channel is full, close it
						close(client.send)
						delete(h.clients, client)
					}
				}
				log.Printf("Broadcasted %s event to %d clients for game %s", update.Event, len(clients), update.GameID)
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) sendGameState(client *Client, gameID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
		GameId: gameID,
	})
	if err != nil {
		log.Printf("Error querying game state for %s: %v", gameID, err)
		return
	}

	update := &GameUpdate{
		GameID:    gameID,
		Timestamp: time.Now(),
		Event:     "state",
		Data:      json.RawMessage(res.Game),
	}

	message, _ := json.Marshal(update)
	select {
	case client.send <- message:
		log.Printf("Sent initial game state to client for game %s", gameID)
	default:
		log.Printf("Failed to send game state to client (channel full)")
	}
}

// BroadcastGameUpdate broadcasts a game state update to all subscribers
func (h *Hub) BroadcastGameUpdate(gameID string, event string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
		GameId: gameID,
	})
	if err != nil {
		log.Printf("Error querying game for broadcast: %v", err)
		return
	}

	update := &GameUpdate{
		GameID:    gameID,
		Timestamp: time.Now(),
		Event:     event,
		Data:      json.RawMessage(res.Game),
	}

	h.broadcast <- update
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
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var msg ClientMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("Error unmarshaling message: %v", err)
			continue
		}

		switch msg.Type {
		case "subscribe":
			if msg.GameID != "" {
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
			// Respond with pong
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
	// Set address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(addressPrefix, addressPrefix+"pub")
	config.Seal()

	// Create gRPC connection
	log.Println("Connecting to blockchain via gRPC...")
	creds := credentials.NewTLS(nil)
	grpcConn, err := grpc.Dial(grpcURL, grpc.WithTransportCredentials(creds))
	if err != nil {
		log.Fatalf("Failed to connect to gRPC: %v", err)
	}
	defer grpcConn.Close()

	hub := newHub(grpcConn)
	go hub.run()

	// Start blockchain event listener
	go pollBlockchainEvents(hub)

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

	port := ":8585"
	log.Printf("WebSocket server starting on %s", port)
	log.Printf("WebSocket endpoint: ws://localhost:8585/ws")
	log.Printf("Health check: http://localhost:8585/health")

	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("ListenAndServe error: %v", err)
	}
}

// pollBlockchainEvents polls the blockchain for new events and triggers broadcasts
func pollBlockchainEvents(hub *Hub) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	lastHeight := int64(0)

	for range ticker.C {
		// TODO: Query latest block height and check for poker events
		// For now, this is a placeholder that would need to be implemented
		// based on your blockchain's event system

		// Example implementation would:
		// 1. Query latest block height
		// 2. Scan blocks for poker module events (action_performed, player_joined, player_left)
		// 3. Extract game_id from events
		// 4. Call hub.BroadcastGameUpdate(gameID, eventType)

		_ = lastHeight // Placeholder to avoid unused variable error
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
