/**
 * WebSocket client for subscribing to Pokerchain game state updates
 *
 * @example
 * ```typescript
 * const ws = new PokerWebSocketClient('ws://localhost:3000');
 *
 * ws.subscribeToGame('0x123...', (event) => {
 *   console.log('Game state updated:', event);
 *   // Update UI with new game state
 * });
 *
 * // Later, unsubscribe
 * ws.unsubscribeFromGame('0x123...');
 * ```
 */

export interface GameStateEvent {
  type: string;
  game_id: string;
  player?: string;
  action?: string;
  amount?: string;
  round?: string;
  next_to_act?: string;
  action_count?: string;
  hand_number?: string;
  timestamp: string;
  block_height: number;
  tx_hash: string;
  raw_data?: Record<string, any>;
}

export type EventHandler = (event: GameStateEvent) => void;
export type ErrorHandler = (error: Error) => void;
export type ConnectionHandler = () => void;

export interface PokerWebSocketOptions {
  /** Automatically reconnect on connection loss (default: true) */
  autoReconnect?: boolean;
  /** Reconnection delay in milliseconds (default: 3000) */
  reconnectDelay?: number;
  /** Maximum reconnection attempts (default: 10, 0 = infinite) */
  maxReconnectAttempts?: number;
  /** Ping interval in milliseconds to keep connection alive (default: 30000) */
  pingInterval?: number;
}

interface Subscription {
  gameId: string;
  socket: WebSocket | null;
  handlers: EventHandler[];
  reconnectAttempts: number;
  reconnectTimer?: NodeJS.Timeout;
  pingTimer?: NodeJS.Timeout;
}

export class PokerWebSocketClient {
  private baseUrl: string;
  private subscriptions: Map<string, Subscription>;
  private options: Required<PokerWebSocketOptions>;
  private errorHandlers: ErrorHandler[] = [];
  private connectHandlers: ConnectionHandler[] = [];
  private disconnectHandlers: ConnectionHandler[] = [];

  constructor(baseUrl: string, options: PokerWebSocketOptions = {}) {
    this.baseUrl = baseUrl.replace(/\/$/, ''); // Remove trailing slash
    this.subscriptions = new Map();
    this.options = {
      autoReconnect: options.autoReconnect ?? true,
      reconnectDelay: options.reconnectDelay ?? 3000,
      maxReconnectAttempts: options.maxReconnectAttempts ?? 10,
      pingInterval: options.pingInterval ?? 30000,
    };
  }

  /**
   * Subscribe to game state updates for a specific game
   * @param gameId The game ID to subscribe to
   * @param handler Callback function for game state events
   */
  subscribeToGame(gameId: string, handler: EventHandler): void {
    const subscription = this.subscriptions.get(gameId);

    if (subscription) {
      // Add handler to existing subscription
      subscription.handlers.push(handler);
      return;
    }

    // Create new subscription
    const newSubscription: Subscription = {
      gameId,
      socket: null,
      handlers: [handler],
      reconnectAttempts: 0,
    };

    this.subscriptions.set(gameId, newSubscription);
    this.connect(gameId);
  }

  /**
   * Unsubscribe from game state updates
   * @param gameId The game ID to unsubscribe from
   * @param handler Optional specific handler to remove. If not provided, all handlers are removed.
   */
  unsubscribeFromGame(gameId: string, handler?: EventHandler): void {
    const subscription = this.subscriptions.get(gameId);
    if (!subscription) return;

    if (handler) {
      // Remove specific handler
      subscription.handlers = subscription.handlers.filter(h => h !== handler);

      // Keep subscription alive if there are other handlers
      if (subscription.handlers.length > 0) {
        return;
      }
    }

    // Close connection and clean up
    this.disconnect(gameId);
    this.subscriptions.delete(gameId);
  }

  /**
   * Unsubscribe from all games
   */
  unsubscribeAll(): void {
    for (const gameId of this.subscriptions.keys()) {
      this.disconnect(gameId);
    }
    this.subscriptions.clear();
  }

  /**
   * Register a global error handler
   */
  onError(handler: ErrorHandler): void {
    this.errorHandlers.push(handler);
  }

  /**
   * Register a connection handler
   */
  onConnect(handler: ConnectionHandler): void {
    this.connectHandlers.push(handler);
  }

  /**
   * Register a disconnection handler
   */
  onDisconnect(handler: ConnectionHandler): void {
    this.disconnectHandlers.push(handler);
  }

  /**
   * Check if connected to a specific game
   */
  isConnected(gameId: string): boolean {
    const subscription = this.subscriptions.get(gameId);
    return subscription?.socket?.readyState === WebSocket.OPEN;
  }

  /**
   * Get the WebSocket connection state for a game
   */
  getConnectionState(gameId: string): number | null {
    const subscription = this.subscriptions.get(gameId);
    return subscription?.socket?.readyState ?? null;
  }

  private connect(gameId: string): void {
    const subscription = this.subscriptions.get(gameId);
    if (!subscription) return;

    const url = `${this.baseUrl}/ws/game/${gameId}`;

    try {
      const socket = new WebSocket(url);

      socket.onopen = () => {
        console.log(`[PokerWS] Connected to game ${gameId}`);
        subscription.reconnectAttempts = 0;

        // Setup ping to keep connection alive
        this.setupPing(gameId);

        // Notify connection handlers
        this.connectHandlers.forEach(handler => handler());
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as GameStateEvent;

          // Notify all handlers for this game
          subscription.handlers.forEach(handler => {
            try {
              handler(data);
            } catch (error) {
              console.error('[PokerWS] Error in event handler:', error);
              this.notifyError(new Error(`Handler error: ${error}`));
            }
          });
        } catch (error) {
          console.error('[PokerWS] Failed to parse message:', error);
          this.notifyError(new Error(`Parse error: ${error}`));
        }
      };

      socket.onerror = (event) => {
        console.error(`[PokerWS] WebSocket error for game ${gameId}:`, event);
        this.notifyError(new Error(`WebSocket error for game ${gameId}`));
      };

      socket.onclose = (event) => {
        console.log(`[PokerWS] Disconnected from game ${gameId} (code: ${event.code})`);

        // Clear ping timer
        if (subscription.pingTimer) {
          clearInterval(subscription.pingTimer);
          subscription.pingTimer = undefined;
        }

        // Notify disconnect handlers
        this.disconnectHandlers.forEach(handler => handler());

        // Attempt reconnection if enabled
        if (this.options.autoReconnect && subscription.handlers.length > 0) {
          this.scheduleReconnect(gameId);
        }
      };

      subscription.socket = socket;
    } catch (error) {
      console.error(`[PokerWS] Failed to create WebSocket for game ${gameId}:`, error);
      this.notifyError(new Error(`Connection error: ${error}`));

      if (this.options.autoReconnect) {
        this.scheduleReconnect(gameId);
      }
    }
  }

  private disconnect(gameId: string): void {
    const subscription = this.subscriptions.get(gameId);
    if (!subscription) return;

    // Clear timers
    if (subscription.reconnectTimer) {
      clearTimeout(subscription.reconnectTimer);
      subscription.reconnectTimer = undefined;
    }

    if (subscription.pingTimer) {
      clearInterval(subscription.pingTimer);
      subscription.pingTimer = undefined;
    }

    // Close socket
    if (subscription.socket) {
      subscription.socket.close();
      subscription.socket = null;
    }
  }

  private scheduleReconnect(gameId: string): void {
    const subscription = this.subscriptions.get(gameId);
    if (!subscription) return;

    // Check max attempts
    if (
      this.options.maxReconnectAttempts > 0 &&
      subscription.reconnectAttempts >= this.options.maxReconnectAttempts
    ) {
      console.error(
        `[PokerWS] Max reconnection attempts reached for game ${gameId}`
      );
      this.notifyError(
        new Error(`Max reconnection attempts reached for game ${gameId}`)
      );
      return;
    }

    subscription.reconnectAttempts++;

    console.log(
      `[PokerWS] Scheduling reconnect for game ${gameId} (attempt ${subscription.reconnectAttempts})`
    );

    subscription.reconnectTimer = setTimeout(() => {
      this.connect(gameId);
    }, this.options.reconnectDelay);
  }

  private setupPing(gameId: string): void {
    const subscription = this.subscriptions.get(gameId);
    if (!subscription || !subscription.socket) return;

    subscription.pingTimer = setInterval(() => {
      if (subscription.socket?.readyState === WebSocket.OPEN) {
        // Send ping message (you can customize this)
        try {
          subscription.socket.send(JSON.stringify({ type: 'ping' }));
        } catch (error) {
          console.error('[PokerWS] Failed to send ping:', error);
        }
      }
    }, this.options.pingInterval);
  }

  private notifyError(error: Error): void {
    this.errorHandlers.forEach(handler => {
      try {
        handler(error);
      } catch (e) {
        console.error('[PokerWS] Error in error handler:', e);
      }
    });
  }
}

/**
 * Helper function to create a WebSocket client with common defaults
 */
export function createPokerWebSocketClient(
  baseUrl: string = 'ws://localhost:3000',
  options?: PokerWebSocketOptions
): PokerWebSocketClient {
  return new PokerWebSocketClient(baseUrl, options);
}
