package ranker_test

import (
	"testing"
	"time"

	"github.com/KyleKing/dotfiles/completion-server/internal/ranker"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNew(t *testing.T) {
	t.Parallel()

	r := ranker.New()
	if r == nil {
		t.Fatal("expected ranker to be non-nil")
	}
}

func TestNewWithOptions(t *testing.T) {
	t.Parallel()

	r := ranker.New(
		ranker.WithFrequencyWeight(2.0),
		ranker.WithRecencyWeight(1.0),
	)

	if r == nil {
		t.Fatal("expected ranker to be non-nil")
	}
}

func TestRanker_Rank(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name       string
		candidates []types.Candidate
		stats      map[string]types.HistoryStats
		context    *types.QueryContext
		validate   func(*testing.T, []types.Candidate)
	}{
		{
			name: "candidates without history keep base score",
			candidates: []types.Candidate{
				{Value: "--hidden", Score: 100.0},
				{Value: "--type", Score: 90.0},
			},
			stats:   map[string]types.HistoryStats{},
			context: &types.QueryContext{},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(ranked))
				}

				// Should maintain original order (--hidden higher score)
				if ranked[0].Value != "--hidden" {
					t.Errorf("expected first candidate to be --hidden, got %s", ranked[0].Value)
				}
			},
		},
		{
			name: "frequency boosts score",
			candidates: []types.Candidate{
				{Value: "--hidden", Score: 100.0},
				{Value: "--type", Score: 100.0},
			},
			stats: map[string]types.HistoryStats{
				"--hidden": {
					Frequency:   10,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 1.0,
				},
				"--type": {
					Frequency:   2,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 1.0,
				},
			},
			context: &types.QueryContext{},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(ranked))
				}

				// --hidden should rank higher due to frequency
				if ranked[0].Value != "--hidden" {
					t.Errorf("expected --hidden to rank first (higher frequency), got %s", ranked[0].Value)
				}

				if ranked[0].Score <= ranked[1].Score {
					t.Errorf("expected first candidate to have higher score than second")
				}
			},
		},
		{
			name: "recency boosts score",
			candidates: []types.Candidate{
				{Value: "--hidden", Score: 100.0},
				{Value: "--type", Score: 100.0},
			},
			stats: map[string]types.HistoryStats{
				"--hidden": {
					Frequency:   5,
					LastUsed:    time.Now().Add(-1 * time.Hour), // Recent
					SuccessRate: 1.0,
				},
				"--type": {
					Frequency:   5,
					LastUsed:    time.Now().Add(-30 * 24 * time.Hour), // 30 days ago
					SuccessRate: 1.0,
				},
			},
			context: &types.QueryContext{},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(ranked))
				}

				// --hidden should rank higher due to recency
				if ranked[0].Value != "--hidden" {
					t.Errorf("expected --hidden to rank first (more recent), got %s", ranked[0].Value)
				}
			},
		},
		{
			name: "success rate affects score",
			candidates: []types.Candidate{
				{Value: "--hidden", Score: 100.0},
				{Value: "--type", Score: 100.0},
			},
			stats: map[string]types.HistoryStats{
				"--hidden": {
					Frequency:   5,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 1.0, // Always successful
				},
				"--type": {
					Frequency:   5,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 0.5, // 50% success rate
				},
			},
			context: &types.QueryContext{},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(ranked))
				}

				// --hidden should rank higher due to better success rate
				if ranked[0].Value != "--hidden" {
					t.Errorf("expected --hidden to rank first (higher success rate), got %s", ranked[0].Value)
				}
			},
		},
		{
			name: "git context boosts git-related flags",
			candidates: []types.Candidate{
				{Value: "--branch", Score: 100.0},
				{Value: "--hidden", Score: 100.0},
			},
			stats: map[string]types.HistoryStats{
				"--branch": {
					Frequency:   2,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 1.0,
				},
				"--hidden": {
					Frequency:   2,
					LastUsed:    time.Now().Add(-1 * time.Hour),
					SuccessRate: 1.0,
				},
			},
			context: &types.QueryContext{
				InGitRepo: true,
			},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(ranked))
				}

				// --branch should rank higher due to git context
				if ranked[0].Value != "--branch" {
					t.Errorf("expected --branch to rank first (git context), got %s", ranked[0].Value)
				}
			},
		},
		{
			name: "empty candidates returns empty",
			candidates: []types.Candidate{},
			stats:      map[string]types.HistoryStats{},
			context:    &types.QueryContext{},
			validate: func(t *testing.T, ranked []types.Candidate) {
				t.Helper()

				if len(ranked) != 0 {
					t.Errorf("expected 0 candidates, got %d", len(ranked))
				}
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			r := ranker.New()
			ranked := r.Rank(tc.candidates, tc.stats, tc.context)

			if tc.validate != nil {
				tc.validate(t, ranked)
			}
		})
	}
}

func TestRanker_RankPreservesOriginalOrder(t *testing.T) {
	t.Parallel()

	r := ranker.New()

	candidates := []types.Candidate{
		{Value: "a", Score: 100.0},
		{Value: "b", Score: 100.0},
		{Value: "c", Score: 100.0},
	}

	// With no stats, should preserve original order (stable sort)
	ranked := r.Rank(candidates, map[string]types.HistoryStats{}, &types.QueryContext{})

	if len(ranked) != 3 {
		t.Fatalf("expected 3 candidates, got %d", len(ranked))
	}

	// All should have same score, so order should be stable
	for i, expected := range []string{"a", "b", "c"} {
		if ranked[i].Value != expected {
			t.Errorf("expected candidate %d to be %s, got %s", i, expected, ranked[i].Value)
		}
	}
}

func TestRanker_CustomWeights(t *testing.T) {
	t.Parallel()

	// Create ranker with only frequency weight
	r := ranker.New(
		ranker.WithFrequencyWeight(10.0),
		ranker.WithRecencyWeight(0.0),
		ranker.WithSuccessWeight(0.0),
		ranker.WithContextWeight(0.0),
	)

	candidates := []types.Candidate{
		{Value: "--hidden", Score: 100.0},
		{Value: "--type", Score: 100.0},
	}

	stats := map[string]types.HistoryStats{
		"--hidden": {
			Frequency:   10,
			LastUsed:    time.Now().Add(-30 * 24 * time.Hour), // Old
			SuccessRate: 0.5,                                   // Low success
		},
		"--type": {
			Frequency:   2,
			LastUsed:    time.Now().Add(-1 * time.Hour), // Recent
			SuccessRate: 1.0,                            // High success
		},
	}

	ranked := r.Rank(candidates, stats, &types.QueryContext{})

	// With only frequency weight, --hidden should rank first
	if ranked[0].Value != "--hidden" {
		t.Errorf("expected --hidden to rank first (frequency weight only), got %s", ranked[0].Value)
	}
}
