package daemon

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"sync"

	"github.com/KyleKing/dotfiles/completion-server/internal/completion"
	"github.com/KyleKing/dotfiles/completion-server/pkg/protocol"
)

// Server handles Unix socket connections
type Server struct {
	socketPath string
	engine     *completion.Engine
	listener   net.Listener
	wg         sync.WaitGroup
	ctx        context.Context
	cancel     context.CancelFunc
}

// ServerOption configures the server
type ServerOption func(*Server) error

// WithSocketPath sets a custom socket path
func WithSocketPath(path string) ServerOption {
	return func(s *Server) error {
		s.socketPath = path
		return nil
	}
}

// WithEngine sets a custom completion engine (for testing)
func WithEngine(engine *completion.Engine) ServerOption {
	return func(s *Server) error {
		s.engine = engine
		return nil
	}
}

// NewServer creates a new daemon server
func NewServer(opts ...ServerOption) (*Server, error) {
	ctx, cancel := context.WithCancel(context.Background())

	server := &Server{
		ctx:    ctx,
		cancel: cancel,
	}

	// Apply options
	for _, opt := range opts {
		if err := opt(server); err != nil {
			cancel()
			return nil, fmt.Errorf("failed to apply option: %w", err)
		}
	}

	// Set default socket path
	if server.socketPath == "" {
		user := os.Getenv("USER")
		if user == "" {
			user = "default"
		}
		server.socketPath = filepath.Join("/tmp", fmt.Sprintf("completion-server-%s.sock", user))
	}

	// Initialize engine if not set
	if server.engine == nil {
		engine, err := completion.New()
		if err != nil {
			cancel()
			return nil, fmt.Errorf("failed to initialize completion engine: %w", err)
		}
		server.engine = engine
	}

	return server, nil
}

// Start starts the daemon server
func (s *Server) Start() error {
	// Remove existing socket if present
	if err := os.RemoveAll(s.socketPath); err != nil {
		return fmt.Errorf("failed to remove existing socket: %w", err)
	}

	// Create Unix socket listener
	listener, err := net.Listen("unix", s.socketPath)
	if err != nil {
		return fmt.Errorf("failed to create listener: %w", err)
	}
	s.listener = listener

	// Set socket permissions (user only)
	if err := os.Chmod(s.socketPath, 0600); err != nil {
		return fmt.Errorf("failed to set socket permissions: %w", err)
	}

	// Accept connections in background
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		s.acceptConnections()
	}()

	return nil
}

// acceptConnections handles incoming connections
func (s *Server) acceptConnections() {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			select {
			case <-s.ctx.Done():
				return
			default:
				continue
			}
		}

		s.wg.Add(1)
		go func() {
			defer s.wg.Done()
			s.handleConnection(conn)
		}()
	}
}

// handleConnection processes a single connection
func (s *Server) handleConnection(conn net.Conn) {
	defer conn.Close()

	// Decode request
	var req protocol.Request
	decoder := json.NewDecoder(conn)
	if err := decoder.Decode(&req); err != nil {
		s.writeError(conn, fmt.Sprintf("invalid request: %v", err))
		return
	}

	// Validate request
	if err := req.Validate(); err != nil {
		s.writeError(conn, fmt.Sprintf("validation error: %v", err))
		return
	}

	// Query completions
	completions, err := s.engine.Query(req.CommandLine, req.CursorPos, req.MaxResults)
	if err != nil {
		s.writeError(conn, fmt.Sprintf("query error: %v", err))
		return
	}

	// Write response
	resp := protocol.Response{
		Completions: completions,
	}

	encoder := json.NewEncoder(conn)
	if err := encoder.Encode(resp); err != nil {
		// Can't write error response if encoding fails
		return
	}
}

// writeError writes an error response
func (s *Server) writeError(w io.Writer, errMsg string) {
	resp := protocol.Response{
		Error: errMsg,
	}
	encoder := json.NewEncoder(w)
	_ = encoder.Encode(resp)
}

// Stop gracefully stops the server
func (s *Server) Stop() error {
	// Cancel context to stop accepting new connections
	s.cancel()

	// Close listener
	if s.listener != nil {
		if err := s.listener.Close(); err != nil {
			return fmt.Errorf("failed to close listener: %w", err)
		}
	}

	// Wait for all connections to finish
	s.wg.Wait()

	// Remove socket file
	if err := os.RemoveAll(s.socketPath); err != nil {
		return fmt.Errorf("failed to remove socket: %w", err)
	}

	return nil
}

// SocketPath returns the socket path
func (s *Server) SocketPath() string {
	return s.socketPath
}
