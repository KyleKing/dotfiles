package completion_test

import (
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/completion"
	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// mockSource is a test double for sources.Source
type mockSource struct {
	name       string
	priority   int
	candidates []types.Candidate
	err        error
}

func (m *mockSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	// Behave like a real source - return nil for empty commands
	if ctx.ParsedCommand == "" {
		return nil, nil
	}

	if m.err != nil {
		return nil, m.err
	}

	return m.candidates, nil
}

func (m *mockSource) Name() string {
	return m.name
}

func (m *mockSource) Priority() int {
	return m.priority
}

func newMockSource(name string, priority int) *mockSource {
	return &mockSource{
		name:       name,
		priority:   priority,
		candidates: []types.Candidate{},
	}
}

func (m *mockSource) addCandidate(value, display, description string, score float64) {
	m.candidates = append(m.candidates, types.Candidate{
		Value:       value,
		Display:     display,
		Description: description,
		Score:       score,
		Source:      m.name,
	})
}

func TestEngine_QueryWithSources(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		commandLine    string
		cursorPos      int
		maxResults     int
		sources        []sources.Source
		expectedCount  int
		validateResult func(*testing.T, []completion.Candidate)
	}{
		{
			name:        "single source returns candidates",
			commandLine: "fd ",
			cursorPos:   3,
			maxResults:  5,
			sources: func() []sources.Source {
				src := newMockSource("mock", 100)
				src.addCandidate("--hidden", "-H, --hidden", "Search hidden files", 100.0)
				src.addCandidate("--type", "-t, --type", "Filter by type", 100.0)

				return []sources.Source{src}
			}(),
			expectedCount: 2,
			validateResult: func(t *testing.T, candidates []completion.Candidate) {
				t.Helper()

				if len(candidates) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(candidates))
				}

				// Check that candidates are from the mock source
				for _, c := range candidates {
					if c.Source != "mock" {
						t.Errorf("expected source to be 'mock', got %q", c.Source)
					}
				}
			},
		},
		{
			name:        "multiple sources are merged",
			commandLine: "git ",
			cursorPos:   4,
			maxResults:  10,
			sources: func() []sources.Source {
				src1 := newMockSource("carapace", 100)
				src1.addCandidate("commit", "commit", "Record changes", 100.0)
				src1.addCandidate("push", "push", "Update remote", 100.0)

				src2 := newMockSource("usage", 90)
				src2.addCandidate("pull", "pull", "Fetch and merge", 90.0)
				src2.addCandidate("status", "status", "Show working tree", 90.0)

				return []sources.Source{src1, src2}
			}(),
			expectedCount: 4,
			validateResult: func(t *testing.T, candidates []completion.Candidate) {
				t.Helper()

				if len(candidates) != 4 {
					t.Fatalf("expected 4 candidates, got %d", len(candidates))
				}

				// Check that we have candidates from both sources
				sources := make(map[string]bool)
				for _, c := range candidates {
					sources[c.Source] = true
				}

				if !sources["carapace"] || !sources["usage"] {
					t.Error("expected candidates from both carapace and usage sources")
				}
			},
		},
		{
			name:        "duplicates are removed (higher score wins)",
			commandLine: "fd ",
			cursorPos:   3,
			maxResults:  5,
			sources: func() []sources.Source {
				src1 := newMockSource("carapace", 100)
				src1.addCandidate("--hidden", "-H, --hidden", "Search hidden files", 100.0)

				src2 := newMockSource("usage", 90)
				src2.addCandidate("--hidden", "--hidden", "Search hidden files", 90.0)

				return []sources.Source{src1, src2}
			}(),
			expectedCount: 1,
			validateResult: func(t *testing.T, candidates []completion.Candidate) {
				t.Helper()

				if len(candidates) != 1 {
					t.Fatalf("expected 1 candidate after deduplication, got %d", len(candidates))
				}

				// Should keep the one with higher score (carapace)
				if candidates[0].Source != "carapace" {
					t.Errorf("expected source to be 'carapace' (higher score), got %q", candidates[0].Source)
				}

				if candidates[0].Score != 100.0 {
					t.Errorf("expected score to be 100.0, got %f", candidates[0].Score)
				}
			},
		},
		{
			name:        "max results limits output",
			commandLine: "git ",
			cursorPos:   4,
			maxResults:  2,
			sources: func() []sources.Source {
				src := newMockSource("mock", 100)
				src.addCandidate("commit", "commit", "Record changes", 100.0)
				src.addCandidate("push", "push", "Update remote", 100.0)
				src.addCandidate("pull", "pull", "Fetch and merge", 100.0)
				src.addCandidate("status", "status", "Show working tree", 100.0)

				return []sources.Source{src}
			}(),
			expectedCount: 2,
			validateResult: func(t *testing.T, candidates []completion.Candidate) {
				t.Helper()

				if len(candidates) != 2 {
					t.Fatalf("expected 2 candidates (limited by maxResults), got %d", len(candidates))
				}
			},
		},
		{
			name:        "empty command line returns empty",
			commandLine: "",
			cursorPos:   0,
			maxResults:  5,
			sources: func() []sources.Source {
				src := newMockSource("mock", 100)
				src.addCandidate("something", "something", "desc", 100.0)

				return []sources.Source{src}
			}(),
			expectedCount: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Create engine with mock sources
			engine, err := completion.New(completion.WithSources(tc.sources...))
			if err != nil {
				t.Fatalf("failed to create engine: %v", err)
			}

			// Query completions
			candidates, err := engine.Query(tc.commandLine, tc.cursorPos, tc.maxResults)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if len(candidates) != tc.expectedCount {
				t.Errorf("expected %d candidates, got %d", tc.expectedCount, len(candidates))
			}

			// Run custom validation if provided
			if tc.validateResult != nil {
				tc.validateResult(t, candidates)
			}
		})
	}
}

// captureMockSource is a mock source that captures the query context
type captureMockSource struct {
	name         string
	priority     int
	capturedCtx  *types.QueryContext
	candidates   []types.Candidate
}

func (c *captureMockSource) GetCompletions(ctx *types.QueryContext) ([]types.Candidate, error) {
	c.capturedCtx = ctx

	return c.candidates, nil
}

func (c *captureMockSource) Name() string {
	return c.name
}

func (c *captureMockSource) Priority() int {
	return c.priority
}

func TestEngine_QueryContextParsing(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name        string
		commandLine string
		cursorPos   int
		wantCommand string
		wantArgs    []string
	}{
		{
			name:        "simple command",
			commandLine: "fd ",
			cursorPos:   3,
			wantCommand: "fd",
			wantArgs:    nil,
		},
		{
			name:        "command with one arg",
			commandLine: "fd --hidden ",
			cursorPos:   12,
			wantCommand: "fd",
			wantArgs:    []string{"--hidden"},
		},
		{
			name:        "command with multiple args",
			commandLine: "git commit -m 'message' ",
			cursorPos:   24,
			wantCommand: "git",
			wantArgs:    []string{"commit", "-m", "'message'"},
		},
		{
			name:        "cursor in middle",
			commandLine: "git commit --amend",
			cursorPos:   10,
			wantCommand: "git",
			wantArgs:    []string{"commit"},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Create capture mock source
			mockSrc := &captureMockSource{
				name:       "mock",
				priority:   100,
				candidates: []types.Candidate{},
			}

			// Create engine with mock source
			engine, err := completion.New(completion.WithSources(mockSrc))
			if err != nil {
				t.Fatalf("failed to create engine: %v", err)
			}

			// Query
			_, err = engine.Query(tc.commandLine, tc.cursorPos, 5)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			// Validate captured context
			if mockSrc.capturedCtx == nil {
				t.Fatal("context was not captured")
			}

			if mockSrc.capturedCtx.ParsedCommand != tc.wantCommand {
				t.Errorf("expected command %q, got %q", tc.wantCommand, mockSrc.capturedCtx.ParsedCommand)
			}

			if len(mockSrc.capturedCtx.ParsedArgs) != len(tc.wantArgs) {
				t.Errorf("expected %d args, got %d", len(tc.wantArgs), len(mockSrc.capturedCtx.ParsedArgs))
			}

			for i, wantArg := range tc.wantArgs {
				if i >= len(mockSrc.capturedCtx.ParsedArgs) {
					break
				}

				if mockSrc.capturedCtx.ParsedArgs[i] != wantArg {
					t.Errorf("expected arg[%d] to be %q, got %q", i, wantArg, mockSrc.capturedCtx.ParsedArgs[i])
				}
			}
		})
	}
}
