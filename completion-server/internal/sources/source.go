package sources

import "github.com/KyleKing/dotfiles/completion-server/pkg/types"

// Source represents a completion data source
type Source interface {
	// GetCompletions returns completion candidates for the given context
	GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error)

	// Name returns the source name
	Name() string

	// Priority returns the source priority (higher = more important)
	Priority() int
}
