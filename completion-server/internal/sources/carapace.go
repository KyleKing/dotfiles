package sources

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// CommandExecutor interface for executing commands (allows mocking)
type CommandExecutor interface {
	Execute(name string, args ...string) ([]byte, error)
}

// realExecutor implements CommandExecutor for production use
type realExecutor struct{}

func (r *realExecutor) Execute(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)

	return cmd.Output()
}

// CarapaceSource provides completions from carapace-bin
type CarapaceSource struct {
	binPath  string
	executor CommandExecutor
}

// CarapaceOption is a functional option for configuring CarapaceSource
type CarapaceOption func(*CarapaceSource)

// WithExecutor sets a custom command executor (for testing)
func WithExecutor(executor CommandExecutor) CarapaceOption {
	return func(c *CarapaceSource) {
		c.executor = executor
	}
}

// WithBinPath sets a custom binary path (for testing)
func WithBinPath(binPath string) CarapaceOption {
	return func(c *CarapaceSource) {
		c.binPath = binPath
	}
}

// NewCarapaceSource creates a new carapace source
func NewCarapaceSource(opts ...CarapaceOption) (*CarapaceSource, error) {
	source := &CarapaceSource{
		executor: &realExecutor{},
	}

	// Apply options
	for _, opt := range opts {
		opt(source)
	}

	// Find carapace binary if not set
	if source.binPath == "" {
		binPath, err := exec.LookPath("carapace")
		if err != nil {
			return nil, fmt.Errorf("carapace not found in PATH: %w", err)
		}
		source.binPath = binPath
	}

	return source, nil
}

// GetCompletions queries carapace for completions
func (c *CarapaceSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	// Build args for carapace export command
	// Format: carapace <command> _carapace export "" [args...]
	args := []string{ctx.ParsedCommand, "_carapace", "export", ""}

	// Add parsed arguments if any
	args = append(args, ctx.ParsedArgs...)

	// Run carapace
	output, err := c.executor.Execute(c.binPath, args...)
	if err != nil {
		// Carapace might fail for unknown commands - return empty results
		return []types.Candidate{}, nil
	}

	// Parse carapace JSON output
	var carapaceResult struct {
		Values []struct {
			Value       string   `json:"value"`
			Display     string   `json:"display"`
			Description string   `json:"description"`
			Style       string   `json:"style"`
			Tag         string   `json:"tag"`
			CodeActions []string `json:"codeActions,omitempty"`
		} `json:"values"`
	}

	if err := json.Unmarshal(output, &carapaceResult); err != nil {
		return nil, fmt.Errorf("failed to parse carapace output: %w", err)
	}

	// Convert to our Candidate format
	candidates := make([]types.Candidate, 0, len(carapaceResult.Values))

	for _, item := range carapaceResult.Values {
		display := item.Display
		if display == "" {
			display = item.Value
		}

		// Get current argument being typed (for filtering)
		currentArg := ""
		if len(ctx.ParsedArgs) > 0 {
			// Get the last argument
			currentArg = ctx.ParsedArgs[len(ctx.ParsedArgs)-1]
		}

		// Only include candidates that match the current input
		if currentArg != "" && !strings.HasPrefix(item.Value, currentArg) {
			continue
		}

		candidates = append(candidates, types.Candidate{
			Value:       item.Value,
			Display:     display,
			Description: item.Description,
			Score:       100.0, // Base score, will be adjusted by ranker
			Source:      c.Name(),
			Metadata: map[string]interface{}{
				"style": item.Style,
				"tag":   item.Tag,
			},
		})
	}

	return candidates, nil
}

// Name returns the source name
func (c *CarapaceSource) Name() string {
	return "carapace"
}

// Priority returns the source priority
func (c *CarapaceSource) Priority() int {
	return 100
}
