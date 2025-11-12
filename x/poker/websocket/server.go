package websocket

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"

	rpcclient "github.com/cometbft/cometbft/rpc/client"
	rpchttp "github.com/cometbft/cometbft/rpc/client/http"
	ctypes "github.com/cometbft/cometbft/rpc/core/types"
	tmtypes "github.com/cometbft/cometbft/types"
)

// Server manages WebSocket connections for game state subscriptions
type Server struct {
	cometClient  rpcclient.Client
	upgrader     websocket.Upgrader
	games        map[string]*GameSubscription // gameId -> subscription
	gamesMutex   sync.RWMutex
	eventsChan   <-chan ctypes.ResultEvent
	ctx          context.Context
	cancel       context.CancelFunc
}

// GameSubscription manages all clients subscribed to a specific game
type GameSubscription struct {
	gameId  string
	clients map[*websocket.Conn]bool
	mutex   sync.RWMutex
}

// GameStateEvent represents a game state update event
type GameStateEvent struct {
	Type        string                 `json:"type"`
	GameId      string                 `json:"game_id"`
	Player      string                 `json:"player,omitempty"`
	Action      string                 `json:"action,omitempty"`
	Amount      string                 `json:"amount,omitempty"`
	Round       string                 `json:"round,omitempty"`
	NextToAct   string                 `json:"next_to_act,omitempty"`
	ActionCount string                 `json:"action_count,omitempty"`
	HandNumber  string                 `json:"hand_number,omitempty"`
	Timestamp   time.Time              `json:"timestamp"`
	BlockHeight int64                  `json:"block_height"`
	TxHash      string                 `json:"tx_hash"`
	RawData     map[string]interface{} `json:"raw_data,omitempty"`
}

// NewServer creates a new WebSocket server
func NewServer(cometBftRpcUrl string) (*Server, error) {
	client, err := rpchttp.New(cometBftRpcUrl, "/websocket")
	if err != nil {
		return nil, fmt.Errorf("failed to create CometBFT client: %w", err)
	}

	if err := client.Start(); err != nil {
		return nil, fmt.Errorf("failed to start CometBFT client: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	server := &Server{
		cometClient: client,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// TODO: In production, implement proper origin checking
				return true
			},
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
		games:  make(map[string]*GameSubscription),
		ctx:    ctx,
		cancel: cancel,
	}

	return server, nil
}

// Start begins listening for events from CometBFT
func (s *Server) Start() error {
	// Subscribe to all poker module events
	query := "tm.event='Tx' AND message.module='poker'"

	eventsChan, err := s.cometClient.Subscribe(s.ctx, "poker-websocket", query)
	if err != nil {
		return fmt.Errorf("failed to subscribe to CometBFT events: %w", err)
	}

	s.eventsChan = eventsChan

	// Start event processing goroutine
	go s.processEvents()

	log.Info().Msg("WebSocket server started, listening for poker events")
	return nil
}

// Stop shuts down the WebSocket server
func (s *Server) Stop() error {
	s.cancel()

	// Close all client connections
	s.gamesMutex.Lock()
	for _, gameSub := range s.games {
		gameSub.mutex.Lock()
		for conn := range gameSub.clients {
			conn.Close()
		}
		gameSub.mutex.Unlock()
	}
	s.gamesMutex.Unlock()

	if err := s.cometClient.Stop(); err != nil {
		return fmt.Errorf("failed to stop CometBFT client: %w", err)
	}

	log.Info().Msg("WebSocket server stopped")
	return nil
}

// HandleConnection handles a new WebSocket connection for a specific game
func (s *Server) HandleConnection(w http.ResponseWriter, r *http.Request, gameId string) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error().Err(err).Msg("Failed to upgrade WebSocket connection")
		return
	}

	// Add client to game subscription
	s.addClient(gameId, conn)
	defer s.removeClient(gameId, conn)

	log.Info().Str("game_id", gameId).Str("remote_addr", r.RemoteAddr).Msg("Client connected to game")

	// Send initial connection success message
	welcomeMsg := GameStateEvent{
		Type:      "connection_established",
		GameId:    gameId,
		Timestamp: time.Now(),
	}
	if err := conn.WriteJSON(welcomeMsg); err != nil {
		log.Error().Err(err).Msg("Failed to send welcome message")
		return
	}

	// Keep connection alive and handle client messages
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Error().Err(err).Msg("WebSocket error")
			}
			break
		}

		// Handle ping/pong or other client messages if needed
		log.Debug().Str("game_id", gameId).Bytes("message", message).Msg("Received client message")
	}
}

// addClient adds a client to a game subscription
func (s *Server) addClient(gameId string, conn *websocket.Conn) {
	s.gamesMutex.Lock()
	defer s.gamesMutex.Unlock()

	gameSub, exists := s.games[gameId]
	if !exists {
		gameSub = &GameSubscription{
			gameId:  gameId,
			clients: make(map[*websocket.Conn]bool),
		}
		s.games[gameId] = gameSub
	}

	gameSub.mutex.Lock()
	gameSub.clients[conn] = true
	gameSub.mutex.Unlock()
}

// removeClient removes a client from a game subscription
func (s *Server) removeClient(gameId string, conn *websocket.Conn) {
	s.gamesMutex.Lock()
	defer s.gamesMutex.Unlock()

	gameSub, exists := s.games[gameId]
	if !exists {
		return
	}

	gameSub.mutex.Lock()
	delete(gameSub.clients, conn)
	clientCount := len(gameSub.clients)
	gameSub.mutex.Unlock()

	// Clean up empty game subscriptions
	if clientCount == 0 {
		delete(s.games, gameId)
		log.Info().Str("game_id", gameId).Msg("No more clients, removed game subscription")
	}

	conn.Close()
}

// processEvents processes events from CometBFT and broadcasts to subscribed clients
func (s *Server) processEvents() {
	for {
		select {
		case <-s.ctx.Done():
			return
		case event := <-s.eventsChan:
			s.handleEvent(event)
		}
	}
}

// handleEvent processes a single event and broadcasts to relevant clients
func (s *Server) handleEvent(event ctypes.ResultEvent) {
	txEvent, ok := event.Data.(tmtypes.EventDataTx)
	if !ok {
		return
	}

	// Extract game state events from transaction events
	for _, e := range txEvent.Result.Events {
		if e.Type == "game_state_updated" || e.Type == "player_joined_game" || e.Type == "game_created" {
			gameEvent := s.parseGameEvent(e, txEvent)
			if gameEvent == nil {
				continue
			}

			// Broadcast to all clients subscribed to this game
			s.broadcastToGame(gameEvent.GameId, gameEvent)
		}
	}
}

// parseGameEvent converts a CometBFT event to a GameStateEvent
func (s *Server) parseGameEvent(event tmtypes.Event, txEvent tmtypes.EventDataTx) *GameStateEvent {
	gameEvent := &GameStateEvent{
		Type:        event.Type,
		Timestamp:   time.Now(),
		BlockHeight: txEvent.Height,
		TxHash:      fmt.Sprintf("%X", txEvent.Tx.Hash()),
		RawData:     make(map[string]interface{}),
	}

	// Parse event attributes
	for _, attr := range event.Attributes {
		key := string(attr.Key)
		value := string(attr.Value)

		switch key {
		case "game_id":
			gameEvent.GameId = value
		case "player":
			gameEvent.Player = value
		case "action":
			gameEvent.Action = value
		case "amount":
			gameEvent.Amount = value
		case "round":
			gameEvent.Round = value
		case "next_to_act":
			gameEvent.NextToAct = value
		case "action_count":
			gameEvent.ActionCount = value
		case "hand_number":
			gameEvent.HandNumber = value
		default:
			gameEvent.RawData[key] = value
		}
	}

	// Game ID is required
	if gameEvent.GameId == "" {
		log.Warn().Str("event_type", event.Type).Msg("Event missing game_id")
		return nil
	}

	return gameEvent
}

// broadcastToGame sends an event to all clients subscribed to a specific game
func (s *Server) broadcastToGame(gameId string, event *GameStateEvent) {
	s.gamesMutex.RLock()
	gameSub, exists := s.games[gameId]
	s.gamesMutex.RUnlock()

	if !exists {
		return
	}

	gameSub.mutex.RLock()
	defer gameSub.mutex.RUnlock()

	eventJson, err := json.Marshal(event)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal event")
		return
	}

	log.Info().
		Str("game_id", gameId).
		Str("event_type", event.Type).
		Int("client_count", len(gameSub.clients)).
		Msg("Broadcasting event to clients")

	for conn := range gameSub.clients {
		if err := conn.WriteMessage(websocket.TextMessage, eventJson); err != nil {
			log.Error().Err(err).Msg("Failed to write message to client")
			// Note: Connection will be cleaned up on next read error
		}
	}
}
