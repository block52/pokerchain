/**
 * React hook for subscribing to Pokerchain game state updates via WebSocket
 *
 * @example
 * ```tsx
 * import { usePokerWebSocket } from './usePokerWebSocket';
 *
 * function GameComponent({ gameId }: { gameId: string }) {
 *   const { gameState, isConnected, error } = usePokerWebSocket(gameId);
 *
 *   if (error) return <div>Error: {error.message}</div>;
 *   if (!isConnected) return <div>Connecting...</div>;
 *
 *   return (
 *     <div>
 *       <h2>Game {gameState?.game_id}</h2>
 *       <p>Round: {gameState?.round}</p>
 *       <p>Action Count: {gameState?.action_count}</p>
 *     </div>
 *   );
 * }
 * ```
 */

import { useEffect, useState, useRef, useCallback } from 'react';
import {
  PokerWebSocketClient,
  GameStateEvent,
  PokerWebSocketOptions,
} from './websocket-client';

export interface UsePokerWebSocketResult {
  /** Latest game state event */
  gameState: GameStateEvent | null;
  /** All received events (limited by maxEvents) */
  events: GameStateEvent[];
  /** Whether the WebSocket is connected */
  isConnected: boolean;
  /** Connection error if any */
  error: Error | null;
  /** Manually reconnect */
  reconnect: () => void;
  /** Clear all events */
  clearEvents: () => void;
}

export interface UsePokerWebSocketOptions extends PokerWebSocketOptions {
  /** WebSocket server base URL (default: ws://localhost:3000) */
  baseUrl?: string;
  /** Maximum number of events to keep in memory (default: 100) */
  maxEvents?: number;
  /** Whether to connect automatically (default: true) */
  autoConnect?: boolean;
}

/**
 * React hook for subscribing to game state updates
 */
export function usePokerWebSocket(
  gameId: string | null | undefined,
  options: UsePokerWebSocketOptions = {}
): UsePokerWebSocketResult {
  const {
    baseUrl = 'ws://localhost:3000',
    maxEvents = 100,
    autoConnect = true,
    ...wsOptions
  } = options;

  const [gameState, setGameState] = useState<GameStateEvent | null>(null);
  const [events, setEvents] = useState<GameStateEvent[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const clientRef = useRef<PokerWebSocketClient | null>(null);
  const currentGameIdRef = useRef<string | null>(null);

  // Initialize client
  useEffect(() => {
    if (!clientRef.current) {
      const client = new PokerWebSocketClient(baseUrl, wsOptions);

      client.onConnect(() => {
        setIsConnected(true);
        setError(null);
      });

      client.onDisconnect(() => {
        setIsConnected(false);
      });

      client.onError((err) => {
        setError(err);
      });

      clientRef.current = client;
    }

    return () => {
      if (clientRef.current) {
        clientRef.current.unsubscribeAll();
      }
    };
  }, [baseUrl, wsOptions]);

  // Subscribe to game
  useEffect(() => {
    if (!gameId || !autoConnect || !clientRef.current) return;

    const client = clientRef.current;

    // Unsubscribe from previous game if different
    if (currentGameIdRef.current && currentGameIdRef.current !== gameId) {
      client.unsubscribeFromGame(currentGameIdRef.current);
      setGameState(null);
      setEvents([]);
    }

    currentGameIdRef.current = gameId;

    const handler = (event: GameStateEvent) => {
      setGameState(event);
      setEvents((prev) => {
        const newEvents = [...prev, event];
        // Limit events array size
        if (newEvents.length > maxEvents) {
          return newEvents.slice(-maxEvents);
        }
        return newEvents;
      });
    };

    client.subscribeToGame(gameId, handler);

    return () => {
      if (gameId) {
        client.unsubscribeFromGame(gameId, handler);
      }
    };
  }, [gameId, autoConnect, maxEvents]);

  // Manual reconnect
  const reconnect = useCallback(() => {
    if (!gameId || !clientRef.current) return;

    clientRef.current.unsubscribeFromGame(gameId);
    setGameState(null);
    setEvents([]);
    setError(null);

    // Re-subscribe after a short delay
    setTimeout(() => {
      if (gameId && clientRef.current) {
        const handler = (event: GameStateEvent) => {
          setGameState(event);
          setEvents((prev) => [...prev, event].slice(-maxEvents));
        };
        clientRef.current.subscribeToGame(gameId, handler);
      }
    }, 100);
  }, [gameId, maxEvents]);

  // Clear events
  const clearEvents = useCallback(() => {
    setEvents([]);
  }, []);

  return {
    gameState,
    events,
    isConnected,
    error,
    reconnect,
    clearEvents,
  };
}

/**
 * Hook for subscribing to multiple games at once
 */
export function useMultipleGames(
  gameIds: string[],
  options: UsePokerWebSocketOptions = {}
): Record<string, UsePokerWebSocketResult> {
  const [results, setResults] = useState<Record<string, UsePokerWebSocketResult>>({});

  const {
    baseUrl = 'ws://localhost:3000',
    maxEvents = 100,
    ...wsOptions
  } = options;

  const clientRef = useRef<PokerWebSocketClient | null>(null);

  useEffect(() => {
    if (!clientRef.current) {
      clientRef.current = new PokerWebSocketClient(baseUrl, wsOptions);
    }

    const client = clientRef.current;
    const newResults: Record<string, UsePokerWebSocketResult> = {};

    gameIds.forEach((gameId) => {
      const gameState = { current: null as GameStateEvent | null };
      const events = { current: [] as GameStateEvent[] };
      const isConnected = { current: false };
      const error = { current: null as Error | null };

      const handler = (event: GameStateEvent) => {
        gameState.current = event;
        events.current = [...events.current, event].slice(-maxEvents);

        setResults((prev) => ({
          ...prev,
          [gameId]: {
            ...prev[gameId],
            gameState: gameState.current,
            events: events.current,
          },
        }));
      };

      client.subscribeToGame(gameId, handler);

      newResults[gameId] = {
        gameState: gameState.current,
        events: events.current,
        isConnected: isConnected.current,
        error: error.current,
        reconnect: () => {
          client.unsubscribeFromGame(gameId);
          setTimeout(() => client.subscribeToGame(gameId, handler), 100);
        },
        clearEvents: () => {
          events.current = [];
          setResults((prev) => ({
            ...prev,
            [gameId]: { ...prev[gameId], events: [] },
          }));
        },
      };
    });

    setResults(newResults);

    return () => {
      gameIds.forEach((gameId) => {
        client.unsubscribeFromGame(gameId);
      });
    };
  }, [gameIds.join(','), baseUrl, maxEvents, wsOptions]);

  return results;
}
