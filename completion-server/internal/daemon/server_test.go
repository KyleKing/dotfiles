package daemon_test

import (
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/KyleKing/dotfiles/completion-server/internal/completion"
	"github.com/KyleKing/dotfiles/completion-server/internal/daemon"
	"github.com/KyleKing/dotfiles/completion-server/pkg/protocol"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewServer(t *testing.T) {
	t.Parallel()

	server, err := daemon.NewServer()
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}
	defer server.Stop()

	if server == nil {
		t.Fatal("expected non-nil server")
	}

	// Should have default socket path
	user := os.Getenv("USER")
	if user == "" {
		user = "default"
	}
	expectedPath := filepath.Join("/tmp", "completion-server-"+user+".sock")
	if server.SocketPath() != expectedPath {
		t.Errorf("expected socket path %s, got %s", expectedPath, server.SocketPath())
	}
}

func TestServer_CustomSocketPath(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "test.sock")

	server, err := daemon.NewServer(daemon.WithSocketPath(socketPath))
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}
	defer server.Stop()

	if server.SocketPath() != socketPath {
		t.Errorf("expected socket path %s, got %s", socketPath, server.SocketPath())
	}
}

func TestServer_StartStop(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "test.sock")

	server, err := daemon.NewServer(daemon.WithSocketPath(socketPath))
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}

	// Start server
	if err := server.Start(); err != nil {
		t.Fatalf("failed to start server: %v", err)
	}

	// Check socket exists
	if _, err := os.Stat(socketPath); os.IsNotExist(err) {
		t.Error("socket file not created")
	}

	// Stop server
	if err := server.Stop(); err != nil {
		t.Fatalf("failed to stop server: %v", err)
	}

	// Check socket removed
	if _, err := os.Stat(socketPath); !os.IsNotExist(err) {
		t.Error("socket file not removed")
	}
}

func TestServer_HandleRequest(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "test.sock")

	// Create mock engine with test candidate
	mockEngine, err := completion.New(
		completion.WithSources(&mockSource{
			candidates: []types.Candidate{
				{
					Value:       "--hidden",
					Display:     "--hidden",
					Description: "Include hidden files",
					Score:       100.0,
					Source:      "test",
				},
			},
		}),
	)
	if err != nil {
		t.Fatalf("failed to create mock engine: %v", err)
	}

	server, err := daemon.NewServer(
		daemon.WithSocketPath(socketPath),
		daemon.WithEngine(mockEngine),
	)
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}
	defer server.Stop()

	if err := server.Start(); err != nil {
		t.Fatalf("failed to start server: %v", err)
	}

	// Wait for server to be ready
	time.Sleep(50 * time.Millisecond)

	// Connect to server
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("failed to connect: %v", err)
	}
	defer conn.Close()

	// Send request
	req := protocol.Request{
		CommandLine: "fd ",
		CursorPos:   3,
		MaxResults:  5,
	}

	encoder := json.NewEncoder(conn)
	if err := encoder.Encode(req); err != nil {
		t.Fatalf("failed to encode request: %v", err)
	}

	// Read response
	var resp protocol.Response
	decoder := json.NewDecoder(conn)
	if err := decoder.Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Validate response
	if resp.Error != "" {
		t.Fatalf("unexpected error in response: %s", resp.Error)
	}

	if len(resp.Completions) != 1 {
		t.Fatalf("expected 1 completion, got %d", len(resp.Completions))
	}

	if resp.Completions[0].Value != "--hidden" {
		t.Errorf("expected completion '--hidden', got '%s'", resp.Completions[0].Value)
	}
}

func TestServer_InvalidRequest(t *testing.T) {
	t.Parallel()

	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "test.sock")

	server, err := daemon.NewServer(daemon.WithSocketPath(socketPath))
	if err != nil {
		t.Fatalf("failed to create server: %v", err)
	}
	defer server.Stop()

	if err := server.Start(); err != nil {
		t.Fatalf("failed to start server: %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	// Connect and send invalid JSON
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("failed to connect: %v", err)
	}
	defer conn.Close()

	// Send malformed JSON
	if _, err := conn.Write([]byte("{invalid json")); err != nil {
		t.Fatalf("failed to write: %v", err)
	}

	// Read error response
	var resp protocol.Response
	decoder := json.NewDecoder(conn)
	if err := decoder.Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Should have error
	if resp.Error == "" {
		t.Error("expected error in response")
	}
}

// mockSource implements sources.Source for testing
type mockSource struct {
	candidates []types.Candidate
}

func (m *mockSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}
	return m.candidates, nil
}

func (m *mockSource) Name() string {
	return "test"
}

func (m *mockSource) Priority() int {
	return 100
}
