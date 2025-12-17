package keeper

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"time"

	"github.com/block52/pokerchain/x/poker/types"
)

const (
	// pvmEndpoint is the default PVM JSON-RPC endpoint
	pvmEndpoint = "http://localhost:8545"
	// pvmTimeout is the timeout for PVM health check requests
	pvmTimeout = 5 * time.Second
)

// pvmVersionResponse represents the response from PVM get_version method
type pvmVersionResponse struct {
	Result  string      `json:"result"`
	Error   interface{} `json:"error"`
	ID      int         `json:"id"`
	JSONRPC string      `json:"jsonrpc"`
}

// checkPvmHealth checks the PVM health and returns its status
func (k *Keeper) checkPvmHealth() *types.PvmStatus {
	endpoint := pvmEndpoint

	// Create JSON-RPC request for get_version
	requestBody, err := json.Marshal(map[string]interface{}{
		"method":  "get_version",
		"params":  []string{},
		"id":      1,
		"jsonrpc": "2.0",
	})
	if err != nil {
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    "failed to create request: " + err.Error(),
		}
	}

	client := &http.Client{Timeout: pvmTimeout}
	resp, err := client.Post(endpoint, "application/json", bytes.NewBuffer(requestBody))
	if err != nil {
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    err.Error(),
		}
	}
	defer resp.Body.Close()

	// Check HTTP status
	if resp.StatusCode != http.StatusOK {
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    "HTTP status: " + resp.Status,
		}
	}

	// Read and parse response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    "failed to read response: " + err.Error(),
		}
	}

	var response pvmVersionResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    "failed to parse response: " + err.Error(),
		}
	}

	// Check for JSON-RPC error
	if response.Error != nil {
		errorMsg := "unknown error"
		switch e := response.Error.(type) {
		case string:
			errorMsg = e
		case map[string]interface{}:
			if msg, ok := e["message"].(string); ok {
				errorMsg = msg
			}
		}
		return &types.PvmStatus{
			Healthy:  false,
			Endpoint: endpoint,
			Error:    errorMsg,
		}
	}

	// Success - PVM is healthy
	return &types.PvmStatus{
		Healthy:  true,
		Version:  response.Result,
		Endpoint: endpoint,
	}
}
