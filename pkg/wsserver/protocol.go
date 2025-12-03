package wsserver

// Message type constants for WebSocket protocol
const (
	// Client -> Server message types
	MsgTypeSubscribe   = "subscribe"
	MsgTypeUnsubscribe = "unsubscribe"
	MsgTypeAction      = "action"
	MsgTypePing        = "ping"

	// Server -> Client event types
	EventState          = "state"           // Initial game state on subscribe
	EventPending        = "pending"         // Optimistic update - action accepted by mempool
	EventConfirmed      = "confirmed"       // Action confirmed in block
	EventActionAccepted = "action_accepted" // Acknowledgment to acting player
	EventError          = "error"           // Error message
	EventPong           = "pong"            // Response to ping
)

// Poker action types (matches Cosmos chain action types)
const (
	ActionFold   = "fold"
	ActionCheck  = "check"
	ActionCall   = "call"
	ActionBet    = "bet"
	ActionRaise  = "raise"
	ActionAllIn  = "all_in"
	ActionJoin   = "join"
	ActionLeave  = "leave"
	ActionSitIn  = "sit_in"
	ActionSitOut = "sit_out"
)
