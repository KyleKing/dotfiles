package testutil

import (
	"os/exec"
)

// CommandExecutor is an interface for executing commands (for testing)
type CommandExecutor interface {
	Execute(name string, args ...string) ([]byte, error)
	LookPath(file string) (string, error)
}

// RealExecutor executes real commands
type RealExecutor struct{}

// Execute runs a real command
func (r *RealExecutor) Execute(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	return cmd.Output()
}

// LookPath searches for an executable in PATH
func (r *RealExecutor) LookPath(file string) (string, error) {
	return exec.LookPath(file)
}

// RealCommandExecutor is an alias for backwards compatibility
type RealCommandExecutor = RealExecutor

// MockExecutor is a mock for testing
type MockExecutor struct {
	Output    string
	Err       error
	LookPaths map[string]string // Map of command name to path
}

// Execute returns mocked output
func (m *MockExecutor) Execute(name string, args ...string) ([]byte, error) {
	if m.Err != nil {
		return nil, m.Err
	}
	return []byte(m.Output), nil
}

// LookPath returns mocked path
func (m *MockExecutor) LookPath(file string) (string, error) {
	if m.LookPaths != nil {
		if path, ok := m.LookPaths[file]; ok {
			return path, nil
		}
	}
	return "", exec.ErrNotFound
}

// MockCommandExecutor is an alias for backwards compatibility
type MockCommandExecutor = MockExecutor

// MockResponse represents a mocked command response (deprecated, use MockExecutor)
type MockResponse struct {
	Output []byte
	Error  error
}

// NewMockExecutor creates a new mock executor
func NewMockExecutor() *MockExecutor {
	return &MockExecutor{
		LookPaths: make(map[string]string),
	}
}

// AddResponse adds a mocked response (for backwards compatibility)
func (m *MockExecutor) AddResponse(cmd string, output []byte, err error) {
	// This is a simplified version for backwards compatibility
	m.Output = string(output)
	m.Err = err
}
