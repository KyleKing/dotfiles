package completion

import (
	"fmt"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Candidate is an alias for types.Candidate
type Candidate = types.Candidate

// Engine handles completion queries
type Engine struct {
	sources []sources.Source
}

// New creates a new completion engine
func New() (*Engine, error) {
	// Initialize all sources
	srcs := []sources.Source{}

	// TODO: Add carapace source
	// TODO: Add usage source
	// TODO: Add TLDR source
	// TODO: Add ZSH completion source

	return &Engine{
		sources: srcs,
	}, nil
}

// Query retrieves completions for the given command line
func (e *Engine) Query(commandLine string, cursorPos, maxResults int) ([]Candidate, error) {
	// Parse the command context
	ctx, err := e.parseContext(commandLine, cursorPos)
	if err != nil {
		return nil, fmt.Errorf("failed to parse context: %w", err)
	}

	// Gather completions from all sources
	candidates := []Candidate{}
	for _, source := range e.sources {
		sourceCandidates, err := source.GetCompletions(ctx)
		if err != nil {
			// Log error but continue with other sources
			continue
		}
		candidates = append(candidates, sourceCandidates...)
	}

	// Deduplicate candidates
	candidates = e.deduplicate(candidates)

	// Rank candidates
	// TODO: Implement ranking with history, recency, context

	// Limit results
	if len(candidates) > maxResults {
		candidates = candidates[:maxResults]
	}

	return candidates, nil
}

// parseContext extracts context from the command line
func (e *Engine) parseContext(commandLine string, cursorPos int) (*types.QueryContext, error) {
	// Simple parsing - TODO: improve with proper shell parsing
	parts := strings.Fields(commandLine[:cursorPos])

	ctx := &types.QueryContext{
		CommandLine: commandLine,
		CursorPos:   cursorPos,
	}

	if len(parts) > 0 {
		ctx.ParsedCommand = parts[0]
		if len(parts) > 1 {
			ctx.ParsedArgs = parts[1:]
		}
	}

	// TODO: Detect git repo, working directory, etc.

	return ctx, nil
}

// deduplicate removes duplicate candidates, keeping the highest scored one
func (e *Engine) deduplicate(candidates []Candidate) []Candidate {
	seen := make(map[string]*Candidate)

	for i := range candidates {
		c := &candidates[i]
		key := c.Value

		if existing, ok := seen[key]; ok {
			// Keep the one with higher score
			if c.Score > existing.Score {
				seen[key] = c
			}
		} else {
			seen[key] = c
		}
	}

	// Convert back to slice
	result := make([]Candidate, 0, len(seen))
	for _, c := range seen {
		result = append(result, *c)
	}

	return result
}
