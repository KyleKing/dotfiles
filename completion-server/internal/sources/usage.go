package sources

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// UsageSource provides completions from jdx/usage CLI
type UsageSource struct {
	binPath  string
	executor CommandExecutor
}

// UsageOption is a functional option for configuring UsageSource
type UsageOption func(*UsageSource)

// WithUsageExecutor sets a custom command executor (for testing)
func WithUsageExecutor(executor CommandExecutor) UsageOption {
	return func(u *UsageSource) {
		u.executor = executor
	}
}

// WithUsageBinPath sets a custom binary path (for testing)
func WithUsageBinPath(binPath string) UsageOption {
	return func(u *UsageSource) {
		u.binPath = binPath
	}
}

// NewUsageSource creates a new usage source
func NewUsageSource(opts ...UsageOption) (*UsageSource, error) {
	source := &UsageSource{
		executor: &realExecutor{},
	}

	// Apply options
	for _, opt := range opts {
		opt(source)
	}

	// Find usage binary if not set
	if source.binPath == "" {
		binPath, err := exec.LookPath("usage")
		if err != nil {
			return nil, fmt.Errorf("usage not found in PATH: %w", err)
		}
		source.binPath = binPath
	}

	return source, nil
}

// GetCompletions queries usage for completions
func (u *UsageSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	// Run usage to get spec: usage --spec <command>
	args := []string{"--spec", ctx.ParsedCommand}
	output, err := u.executor.Execute(u.binPath, args...)
	if err != nil {
		// Usage might fail for unknown commands - return empty results
		return []types.Candidate{}, nil
	}

	// Parse usage JSON output
	var usageSpec struct {
		Name  string `json:"name"`
		Flags []struct {
			Long        string   `json:"long"`
			Short       string   `json:"short"`
			Description string   `json:"description"`
			Arg         *struct{ Choices []string `json:"choices"` } `json:"arg"`
		} `json:"flags"`
		Args []struct {
			Name        string   `json:"name"`
			Description string   `json:"description"`
			Choices     []string `json:"choices"`
		} `json:"args"`
	}

	if err := json.Unmarshal(output, &usageSpec); err != nil {
		return nil, fmt.Errorf("failed to parse usage output: %w", err)
	}

	candidates := []types.Candidate{}

	// Get current argument being typed (for filtering)
	currentArg := ""
	if len(ctx.ParsedArgs) > 0 {
		currentArg = ctx.ParsedArgs[len(ctx.ParsedArgs)-1]
	}

	// Check if we're completing a flag value
	completingFlagValue := false
	if len(ctx.ParsedArgs) >= 1 {
		prevArg := ""
		if len(ctx.ParsedArgs) >= 2 {
			prevArg = ctx.ParsedArgs[len(ctx.ParsedArgs)-2]
		}

		// Check if previous arg looks like a flag
		if strings.HasPrefix(prevArg, "-") {
			completingFlagValue = true
		}
	}

	// Add flag completions
	for _, flag := range usageSpec.Flags {
		// Build display string
		display := flag.Long
		if flag.Short != "" {
			display = flag.Short + ", " + flag.Long
		}

		// Check if we're completing a flag value - if so, check if it's for this flag
		isCompletingThisFlag := false
		if completingFlagValue && len(ctx.ParsedArgs) >= 2 {
			prevArg := ctx.ParsedArgs[len(ctx.ParsedArgs)-2]
			isCompletingThisFlag = prevArg == flag.Long || prevArg == flag.Short
		}

		// Add choices if flag has them and we're completing this flag's value
		if isCompletingThisFlag && flag.Arg != nil && len(flag.Arg.Choices) > 0 {
			for _, choice := range flag.Arg.Choices {
				if currentArg != "" && !strings.HasPrefix(choice, currentArg) {
					continue
				}

				candidates = append(candidates, types.Candidate{
					Value:       choice,
					Display:     choice,
					Description: fmt.Sprintf("Value for %s", flag.Long),
					Score:       90.0,
					Source:      u.Name(),
					Metadata: map[string]interface{}{
						"type": "flag-value",
						"flag": flag.Long,
					},
				})
			}
			// Skip adding the flag itself since we're completing its value
			continue
		}

		// Check if we're completing a flag (starts with -)
		if strings.HasPrefix(currentArg, "-") {
			// Filter by prefix
			if !strings.HasPrefix(flag.Long, currentArg) &&
				(flag.Short == "" || !strings.HasPrefix(flag.Short, currentArg)) {
				continue
			}
		} else if currentArg != "" || completingFlagValue {
			// Not completing a flag, skip
			continue
		}

		// Add the flag itself
		candidates = append(candidates, types.Candidate{
			Value:       flag.Long,
			Display:     display,
			Description: flag.Description,
			Score:       90.0, // Slightly lower than carapace
			Source:      u.Name(),
			Metadata: map[string]interface{}{
				"short": flag.Short,
			},
		})
	}

	// Add positional argument completions (if any)
	for _, arg := range usageSpec.Args {
		if len(arg.Choices) > 0 {
			for _, choice := range arg.Choices {
				if currentArg != "" && !strings.HasPrefix(choice, currentArg) {
					continue
				}

				candidates = append(candidates, types.Candidate{
					Value:       choice,
					Display:     choice,
					Description: arg.Description,
					Score:       85.0,
					Source:      u.Name(),
					Metadata: map[string]interface{}{
						"type": "arg",
						"name": arg.Name,
					},
				})
			}
		}
	}

	return candidates, nil
}

// Name returns the source name
func (u *UsageSource) Name() string {
	return "usage"
}

// Priority returns the source priority
func (u *UsageSource) Priority() int {
	return 90
}
