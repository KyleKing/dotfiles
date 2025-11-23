package sources

import (
	"bufio"
	"fmt"
	"regexp"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/internal/testutil"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// ManSource provides completions from man pages
type ManSource struct {
	executor testutil.CommandExecutor
}

// ManOption configures ManSource
type ManOption func(*ManSource)

// WithManExecutor sets a custom executor (for testing)
func WithManExecutor(executor testutil.CommandExecutor) ManOption {
	return func(s *ManSource) {
		s.executor = executor
	}
}

// NewManSource creates a new man page source
func NewManSource(opts ...ManOption) (*ManSource, error) {
	source := &ManSource{
		executor: &testutil.RealExecutor{},
	}

	for _, opt := range opts {
		opt(source)
	}

	// Check if man is available
	if _, err := source.executor.LookPath("man"); err != nil {
		return nil, fmt.Errorf("man not found in PATH")
	}

	return source, nil
}

// GetCompletions returns completions from man pages
func (m *ManSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	// Get man page content
	output, err := m.executor.Execute("man", ctx.ParsedCommand)
	if err != nil {
		// Man page not found - gracefully return empty
		return []types.Candidate{}, nil
	}

	// Parse man page format
	return m.parseManPage(string(output), ctx)
}

// parseManPage extracts flags and descriptions from man page output
func (m *ManSource) parseManPage(content string, ctx *types.QueryContext) ([]types.Candidate, error) {
	var candidates []types.Candidate
	scanner := bufio.NewScanner(strings.NewReader(content))

	// Regular expressions for parsing man pages
	// Match flags like: -f, --flag, -f, --flag ARG
	flagRegex := regexp.MustCompile(`--?[a-zA-Z][-a-zA-Z0-9]*`)

	var currentFlags []string
	var currentDesc strings.Builder
	seenFlags := make(map[string]bool)

	for scanner.Scan() {
		line := scanner.Text()

		// Check if this line starts a new flag definition (starts with whitespace and flag)
		trimmed := strings.TrimSpace(line)
		startsWithFlag := len(trimmed) > 0 && (trimmed[0] == '-')
		hasLeadingSpace := len(line) > 0 && (line[0] == ' ' || line[0] == '\t')

		if hasLeadingSpace && startsWithFlag {
			// Save previous flags if any
			if len(currentFlags) > 0 {
				desc := strings.TrimSpace(currentDesc.String())
				if desc != "" {
					for _, flag := range currentFlags {
						if !seenFlags[flag] {
							candidate := m.createCandidate(flag, desc, ctx)
							if candidate.Value != "" {
								candidates = append(candidates, candidate)
								seenFlags[flag] = true
							}
						}
					}
				}
			}

			// Extract all flags from this line
			currentFlags = flagRegex.FindAllString(line, -1)
			currentDesc.Reset()

			// Get description from remainder of line (after flags)
			lastFlagIdx := strings.LastIndex(line, currentFlags[len(currentFlags)-1])
			remainder := strings.TrimSpace(line[lastFlagIdx+len(currentFlags[len(currentFlags)-1]):])
			if remainder != "" {
				currentDesc.WriteString(remainder)
			}
		} else if len(currentFlags) > 0 {
			// Continuation of description
			trimmed := strings.TrimSpace(line)
			if trimmed != "" {
				if currentDesc.Len() > 0 {
					currentDesc.WriteString(" ")
				}
				currentDesc.WriteString(trimmed)
			}

			// Stop if description is getting too long
			if currentDesc.Len() > 200 {
				desc := strings.TrimSpace(currentDesc.String())
				for _, flag := range currentFlags {
					if !seenFlags[flag] {
						candidate := m.createCandidate(flag, desc, ctx)
						if candidate.Value != "" {
							candidates = append(candidates, candidate)
							seenFlags[flag] = true
						}
					}
				}
				currentFlags = nil
				currentDesc.Reset()
			}
		}
	}

	// Save last flags
	if len(currentFlags) > 0 {
		desc := strings.TrimSpace(currentDesc.String())
		if desc != "" {
			for _, flag := range currentFlags {
				if !seenFlags[flag] {
					candidate := m.createCandidate(flag, desc, ctx)
					if candidate.Value != "" {
						candidates = append(candidates, candidate)
					}
				}
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("failed to parse man page: %w", err)
	}

	return candidates, nil
}

// createCandidate creates a candidate from flag and description
func (m *ManSource) createCandidate(flag, description string, ctx *types.QueryContext) types.Candidate {
	// Filter by prefix if provided
	if len(ctx.ParsedArgs) > 0 {
		lastArg := ctx.ParsedArgs[len(ctx.ParsedArgs)-1]
		if !strings.HasPrefix(flag, lastArg) {
			return types.Candidate{}
		}
	}

	// Truncate long descriptions
	if len(description) > 120 {
		description = description[:117] + "..."
	}

	return types.Candidate{
		Value:       flag,
		Display:     flag,
		Description: description,
		Score:       50.0, // Lowest priority (below carapace=100, usage=90, tldr=75)
		Source:      "man",
		Metadata: map[string]interface{}{
			"type": "flag",
		},
	}
}

// Name returns the source name
func (m *ManSource) Name() string {
	return "man"
}

// Priority returns the source priority
func (m *ManSource) Priority() int {
	return 50 // Lowest priority (fallback source)
}
