package sources

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// CarapaceSource provides completions from carapace-bin
type CarapaceSource struct {
	binPath string
}

// NewCarapaceSource creates a new carapace source
func NewCarapaceSource() (*CarapaceSource, error) {
	// Find carapace binary
	binPath, err := exec.LookPath("carapace")
	if err != nil {
		return nil, fmt.Errorf("carapace not found in PATH: %w", err)
	}

	return &CarapaceSource{
		binPath: binPath,
	}, nil
}

// GetCompletions queries carapace for completions
func (c *CarapaceSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	// Run carapace with --format=json
	cmd := exec.Command(c.binPath, ctx.ParsedCommand, "--format=json")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("carapace command failed: %w", err)
	}

	// Parse carapace JSON output
	var carapaceResult struct {
		Completion []struct {
			Value       string `json:"Value"`
			Display     string `json:"Display"`
			Description string `json:"Description"`
			Style       string `json:"Style"`
		} `json:"Completion"`
	}

	if err := json.Unmarshal(output, &carapaceResult); err != nil {
		return nil, fmt.Errorf("failed to parse carapace output: %w", err)
	}

	// Convert to our Candidate format
	candidates := make([]types.Candidate, 0, len(carapaceResult.Completion))
	for _, item := range carapaceResult.Completion {
		candidates = append(candidates, types.Candidate{
			Value:       item.Value,
			Display:     item.Display,
			Description: item.Description,
			Score:       100.0, // Base score, will be adjusted by ranker
			Source:      c.Name(),
			Metadata: map[string]interface{}{
				"style": item.Style,
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
