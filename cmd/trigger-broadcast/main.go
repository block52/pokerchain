package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

func main() {
	if len(os.Args) < 3 {
		printUsage()
		os.Exit(1)
	}

	gameID := os.Args[1]
	event := os.Args[2]

	wsServerURL := "http://localhost:8585"
	if len(os.Args) >= 4 {
		wsServerURL = os.Args[3]
	}

	url := fmt.Sprintf("%s/trigger?game_id=%s&event=%s", wsServerURL, gameID, event)

	resp, err := http.Get(url)
	if err != nil {
		fmt.Printf("Error triggering broadcast: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	if resp.StatusCode == http.StatusOK {
		fmt.Printf("✅ Broadcast triggered successfully\n")
		fmt.Printf("Response: %s\n", string(body))
	} else {
		fmt.Printf("❌ Failed to trigger broadcast (status %d)\n", resp.StatusCode)
		fmt.Printf("Response: %s\n", string(body))
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: trigger-broadcast <game_id> <event> [ws_server_url]")
	fmt.Println("")
	fmt.Println("Arguments:")
	fmt.Println("  game_id        - The game ID (hex string starting with 0x)")
	fmt.Println("  event          - Event type: action, join, leave, state_change")
	fmt.Println("  ws_server_url  - WebSocket server URL (default: http://localhost:8585)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  # Trigger action event")
	fmt.Println("  trigger-broadcast 0x89a7c...771df1 action")
	fmt.Println("")
	fmt.Println("  # Trigger join event")
	fmt.Println("  trigger-broadcast 0x89a7c...771df1 join")
	fmt.Println("")
	fmt.Println("  # Use remote server")
	fmt.Println("  trigger-broadcast 0x89a7c...771df1 action https://node.texashodl.net")
}
