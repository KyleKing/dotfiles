package ranker

import (
	"math"
	"sort"
	"time"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Ranker ranks completion candidates based on history and context
type Ranker struct {
	// Weights for different ranking factors
	frequencyWeight float64
	recencyWeight   float64
	successWeight   float64
	contextWeight   float64
}

// Option is a functional option for configuring Ranker
type Option func(*Ranker)

// WithFrequencyWeight sets the weight for frequency-based ranking
func WithFrequencyWeight(weight float64) Option {
	return func(r *Ranker) {
		r.frequencyWeight = weight
	}
}

// WithRecencyWeight sets the weight for recency-based ranking
func WithRecencyWeight(weight float64) Option {
	return func(r *Ranker) {
		r.recencyWeight = weight
	}
}

// WithSuccessWeight sets the weight for success rate-based ranking
func WithSuccessWeight(weight float64) Option {
	return func(r *Ranker) {
		r.successWeight = weight
	}
}

// WithContextWeight sets the weight for context-based ranking
func WithContextWeight(weight float64) Option {
	return func(r *Ranker) {
		r.contextWeight = weight
	}
}

// New creates a new ranker with default weights
func New(opts ...Option) *Ranker {
	r := &Ranker{
		frequencyWeight: 1.0,
		recencyWeight:   0.5,
		successWeight:   0.3,
		contextWeight:   0.2,
	}

	for _, opt := range opts {
		opt(r)
	}

	return r
}

// Rank ranks candidates based on history stats and context
func (r *Ranker) Rank(candidates []types.Candidate, stats map[string]types.HistoryStats, context *types.QueryContext) []types.Candidate {
	// Calculate scores for each candidate
	scored := make([]types.Candidate, len(candidates))
	copy(scored, candidates)

	for i := range scored {
		score := r.calculateScore(&scored[i], stats, context)
		scored[i].Score = score
	}

	// Sort by score (descending)
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})

	return scored
}

// calculateScore calculates the ranking score for a candidate
func (r *Ranker) calculateScore(candidate *types.Candidate, stats map[string]types.HistoryStats, context *types.QueryContext) float64 {
	baseScore := candidate.Score

	// Look up history stats for this candidate
	stat, hasStats := stats[candidate.Value]
	if !hasStats {
		// No history - return base score
		return baseScore
	}

	// Frequency score (normalized by log to prevent dominance)
	frequencyScore := 0.0
	if stat.Frequency > 0 {
		// Use log1p to handle both small and large frequencies well
		frequencyScore = math.Log1p(float64(stat.Frequency))
	}

	// Recency score (exponential decay)
	recencyScore := 0.0
	if !stat.LastUsed.IsZero() {
		hoursSince := time.Since(stat.LastUsed).Hours()
		// Exponential decay: score decreases by half every 24 hours
		recencyScore = math.Exp(-hoursSince / 24.0)
	}

	// Success rate score (0.0 to 1.0)
	successScore := stat.SuccessRate

	// Context score (placeholder - can be extended)
	contextScore := 0.0
	if context.InGitRepo && isGitRelated(candidate.Value) {
		contextScore = 1.0
	}

	// Combine scores with weights
	totalScore := baseScore +
		r.frequencyWeight*frequencyScore +
		r.recencyWeight*recencyScore +
		r.successWeight*successScore +
		r.contextWeight*contextScore

	return totalScore
}

// isGitRelated checks if a flag/command is git-related
func isGitRelated(value string) bool {
	gitFlags := []string{
		"--branch", "-b",
		"--commit", "-c",
		"--merge", "-m",
		"--rebase", "-r",
		"--push", "-p",
		"--pull",
		"--fetch",
		"--checkout",
	}

	for _, flag := range gitFlags {
		if value == flag {
			return true
		}
	}

	return false
}
