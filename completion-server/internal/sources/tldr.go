package sources

import (
	"bufio"
	"fmt"
	"regexp"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/internal/testutil"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// TldrSource provides completions from TLDR pages
type TldrSource struct {
	binPath  string
	executor testutil.CommandExecutor
}

// TldrOption configures TldrSource
type TldrOption func(*TldrSource)

// WithTldrBinPath sets the tldr binary path
func WithTldrBinPath(path string) TldrOption {
	return func(s *TldrSource) {
		s.binPath = path
	}
}

// WithTldrExecutor sets a custom executor (for testing)
func WithTldrExecutor(executor testutil.CommandExecutor) TldrOption {
	return func(s *TldrSource) {
		s.executor = executor
	}
}

// NewTldrSource creates a new TLDR source
func NewTldrSource(opts ...TldrOption) (*TldrSource, error) {
	source := &TldrSource{
		executor: &testutil.RealExecutor{},
	}

	for _, opt := range opts {
		opt(source)
	}

	// Find tldr binary if not specified
	if source.binPath == "" {
		// Try common tldr implementations
		for _, name := range []string{"tldr", "tealdeer"} {
			if path, err := source.executor.LookPath(name); err == nil {
				source.binPath = path
				break
			}
		}
		if source.binPath == "" {
			return nil, fmt.Errorf("tldr not found in PATH (install with: cargo install tealdeer)")
		}
	}

	return source, nil
}

// GetCompletions returns completions from TLDR pages
func (t *TldrSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	// Get TLDR page for command
	output, err := t.executor.Execute(t.binPath, ctx.ParsedCommand)
	if err != nil {
		// TLDR page not found - gracefully return empty
		return []types.Candidate{}, nil
	}

	// Parse TLDR markdown format
	return t.parseTldrPage(string(output), ctx)
}

// parseTldrPage extracts flags and descriptions from TLDR markdown
func (t *TldrSource) parseTldrPage(content string, ctx *types.QueryContext) ([]types.Candidate, error) {
	var candidates []types.Candidate
	scanner := bufio.NewScanner(strings.NewReader(content))

	// Regular expressions for parsing
	flagRegex := regexp.MustCompile(`--?[a-zA-Z][-a-zA-Z0-9]*`)
	codeBlockRegex := regexp.MustCompile("`([^`]+)`")

	var currentDescription string
	seenFlags := make(map[string]bool)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Description line (starts with -)
		if strings.HasPrefix(line, "- ") {
			currentDescription = strings.TrimPrefix(line, "- ")
			currentDescription = strings.TrimSuffix(currentDescription, ":")
			continue
		}

		// Code block line (contains `)
		if strings.Contains(line, "`") {
			// Extract code from backticks
			matches := codeBlockRegex.FindAllStringSubmatch(line, -1)
			for _, match := range matches {
				if len(match) < 2 {
					continue
				}

				code := match[1]

				// Extract all flags from this example
				flags := flagRegex.FindAllString(code, -1)
				for _, flag := range flags {
					// Skip if already seen or doesn't match prefix
					if seenFlags[flag] {
						continue
					}

					// Filter by prefix if provided
					if len(ctx.ParsedArgs) > 0 {
						lastArg := ctx.ParsedArgs[len(ctx.ParsedArgs)-1]
						if !strings.HasPrefix(flag, lastArg) {
							continue
						}
					}

					seenFlags[flag] = true

					candidates = append(candidates, types.Candidate{
						Value:       flag,
						Display:     flag,
						Description: currentDescription,
						Score:       75.0, // Medium priority (below carapace/usage)
						Source:      "tldr",
						Metadata: map[string]interface{}{
							"example": code,
						},
					})
				}
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("failed to parse tldr page: %w", err)
	}

	return candidates, nil
}

// Name returns the source name
func (t *TldrSource) Name() string {
	return "tldr"
}

// Priority returns the source priority
func (t *TldrSource) Priority() int {
	return 75 // Medium priority (below carapace=100, usage=90)
}
