package completion

import (
	"fmt"
	"strings"

	"github.com/KyleKing/dotfiles/completion-server/internal/context"
	"github.com/KyleKing/dotfiles/completion-server/internal/history"
	"github.com/KyleKing/dotfiles/completion-server/internal/ranker"
	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Candidate is an alias for types.Candidate
type Candidate = types.Candidate

// Engine handles completion queries
type Engine struct {
	sources         []sources.Source
	historyProvider history.Provider
	ranker          *ranker.Ranker
	contextDetector *context.Detector
}

// EngineOption is a functional option for configuring Engine
type EngineOption func(*Engine) error

// WithSources sets custom sources (for testing)
func WithSources(sources ...sources.Source) EngineOption {
	return func(e *Engine) error {
		e.sources = sources
		return nil
	}
}

// WithHistoryProvider sets a custom history provider
func WithHistoryProvider(provider history.Provider) EngineOption {
	return func(e *Engine) error {
		e.historyProvider = provider
		return nil
	}
}

// WithRanker sets a custom ranker
func WithRanker(r *ranker.Ranker) EngineOption {
	return func(e *Engine) error {
		e.ranker = r
		return nil
	}
}

// New creates a new completion engine
func New(opts ...EngineOption) (*Engine, error) {
	engine := &Engine{
		sources:         []sources.Source{},
		contextDetector: context.New(),
	}

	// Apply options first
	for _, opt := range opts {
		if err := opt(engine); err != nil {
			return nil, fmt.Errorf("failed to apply option: %w", err)
		}
	}

	// If no sources were set via options, initialize default sources
	if len(engine.sources) == 0 {
		// Try to initialize carapace source
		if carapace, err := sources.NewCarapaceSource(); err == nil {
			engine.sources = append(engine.sources, carapace)
		}

		// Try to initialize usage source
		if usage, err := sources.NewUsageSource(); err == nil {
			engine.sources = append(engine.sources, usage)
		}

		// Try to initialize TLDR source
		if tldr, err := sources.NewTldrSource(); err == nil {
			engine.sources = append(engine.sources, tldr)
		}

		// TODO: Add ZSH completion source
	}

	// If no history provider set, try to initialize Atuin
	if engine.historyProvider == nil {
		if provider, err := history.NewAtuinProvider(); err == nil {
			engine.historyProvider = provider
		}
		// If Atuin not available, continue without history
	}

	// If no ranker set, create default ranker
	if engine.ranker == nil {
		engine.ranker = ranker.New()
	}

	return engine, nil
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

	// Rank candidates if ranker is available
	if e.ranker != nil && len(candidates) > 0 {
		// Get history stats if provider is available
		stats := make(map[string]types.HistoryStats)
		if e.historyProvider != nil && ctx.ParsedCommand != "" {
			// Get stats for the command
			historyStats, err := e.historyProvider.GetCommandStats(ctx.ParsedCommand, 100)
			if err == nil {
				// Convert slice to map for easy lookup
				for _, stat := range historyStats {
					if stat.Flag != "" {
						stats[stat.Flag] = stat
					}
				}

				// Also get stats for specific candidate values
				values := make([]string, len(candidates))
				for i, c := range candidates {
					values[i] = c.Value
				}

				if flagStats, err := e.historyProvider.GetFlagStats(ctx.ParsedCommand, values); err == nil {
					for k, v := range flagStats {
						stats[k] = v
					}
				}
			}
		}

		// Rank candidates
		candidates = e.ranker.Rank(candidates, stats, ctx)
	}

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

	// Detect working directory and git repo
	if e.contextDetector != nil {
		if wd, err := e.contextDetector.GetWorkingDirectory(); err == nil {
			ctx.WorkingDir = wd
			ctx.InGitRepo = e.contextDetector.IsInGitRepo(wd)
		}
	}

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
