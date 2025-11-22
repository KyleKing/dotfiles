package testutil

import (
	"os/exec"
	"strings"
)

// CommandExecutor is an interface for executing commands (for testing)
type CommandExecutor interface {
	Execute(name string, args ...string) ([]byte, error)
}

// RealCommandExecutor executes real commands
type RealCommandExecutor struct{}

// Execute runs a real command
func (r *RealCommandExecutor) Execute(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	return cmd.Output()
}

// MockCommandExecutor is a mock for testing
type MockCommandExecutor struct {
	Responses map[string]MockResponse
}

// MockResponse represents a mocked command response
type MockResponse struct {
	Output []byte
	Error  error
}

// Execute returns mocked output
func (m *MockCommandExecutor) Execute(name string, args ...string) ([]byte, error) {
	key := name + " " + strings.Join(args, " ")
	if response, ok := m.Responses[key]; ok {
		return response.Output, response.Error
	}
	return nil, exec.ErrNotFound
}

// NewMockExecutor creates a new mock executor
func NewMockExecutor() *MockCommandExecutor {
	return &MockCommandExecutor{
		Responses: make(map[string]MockResponse),
	}
}

// AddResponse adds a mocked response
func (m *MockCommandExecutor) AddResponse(cmd string, output []byte, err error) {
	m.Responses[cmd] = MockResponse{
		Output: output,
		Error:  err,
	}
}
