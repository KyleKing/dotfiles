package sources_test

import (
	"errors"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// mockExecutor is a test double for CommandExecutor
type mockExecutor struct {
	responses map[string]mockResponse
}

type mockResponse struct {
	output []byte
	err    error
}

func (m *mockExecutor) Execute(name string, args ...string) ([]byte, error) {
	// Build key from command and args
	key := name
	for _, arg := range args {
		key += " " + arg
	}

	if response, ok := m.responses[key]; ok {
		return response.output, response.err
	}

	return nil, errors.New("command not found in mock")
}

func newMockExecutor() *mockExecutor {
	return &mockExecutor{
		responses: make(map[string]mockResponse),
	}
}

func (m *mockExecutor) addResponse(cmd string, output string, err error) {
	m.responses[cmd] = mockResponse{
		output: []byte(output),
		err:    err,
	}
}

func TestNewCarapaceSource(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name        string
		opts        []sources.CarapaceOption
		expectError bool
	}{
		{
			name: "with custom bin path",
			opts: []sources.CarapaceOption{
				sources.WithBinPath("/usr/bin/carapace"),
			},
			expectError: false,
		},
		{
			name: "with custom executor",
			opts: []sources.CarapaceOption{
				sources.WithBinPath("/usr/bin/carapace"),
				sources.WithExecutor(newMockExecutor()),
			},
			expectError: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			source, err := sources.NewCarapaceSource(tc.opts...)

			if tc.expectError && err == nil {
				t.Fatal("expected error but got none")
			}

			if !tc.expectError && err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if !tc.expectError && source == nil {
				t.Fatal("expected source to be non-nil")
			}
		})
	}
}

func TestCarapaceSource_GetCompletions(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		context        *types.QueryContext
		mockOutput     string
		mockError      error
		expectedCount  int
		expectError    bool
		validateResult func(*testing.T, []types.Candidate)
	}{
		{
			name: "empty command returns nil",
			context: &types.QueryContext{
				ParsedCommand: "",
			},
			expectedCount: 0,
		},
		{
			name: "successful completion for fd",
			context: &types.QueryContext{
				ParsedCommand: "fd",
				ParsedArgs:    []string{},
			},
			mockOutput: `{
				"values": [
					{
						"value": "--hidden",
						"display": "-H, --hidden",
						"description": "Search hidden files and directories",
						"style": "blue",
						"tag": "flags"
					},
					{
						"value": "--type",
						"display": "-t, --type",
						"description": "Filter by type",
						"style": "blue",
						"tag": "flags"
					}
				]
			}`,
			expectedCount: 2,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				if len(candidates) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(candidates))
				}

				// Check first candidate
				if candidates[0].Value != "--hidden" {
					t.Errorf("expected first candidate value to be '--hidden', got %q", candidates[0].Value)
				}

				if candidates[0].Display != "-H, --hidden" {
					t.Errorf("expected first candidate display to be '-H, --hidden', got %q", candidates[0].Display)
				}

				if candidates[0].Source != "carapace" {
					t.Errorf("expected source to be 'carapace', got %q", candidates[0].Source)
				}

				if candidates[0].Score != 100.0 {
					t.Errorf("expected score to be 100.0, got %f", candidates[0].Score)
				}

				// Check metadata
				if style, ok := candidates[0].Metadata["style"]; !ok || style != "blue" {
					t.Errorf("expected style metadata to be 'blue', got %v", style)
				}

				if tag, ok := candidates[0].Metadata["tag"]; !ok || tag != "flags" {
					t.Errorf("expected tag metadata to be 'flags', got %v", tag)
				}
			},
		},
		{
			name: "completion with filtering",
			context: &types.QueryContext{
				ParsedCommand: "fd",
				ParsedArgs:    []string{"--h"},
			},
			mockOutput: `{
				"values": [
					{
						"value": "--hidden",
						"display": "-H, --hidden",
						"description": "Search hidden files",
						"style": "blue"
					},
					{
						"value": "--help",
						"display": "--help",
						"description": "Show help",
						"style": "blue"
					},
					{
						"value": "--type",
						"display": "--type",
						"description": "Filter by type",
						"style": "blue"
					}
				]
			}`,
			expectedCount: 2,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				// Should only have --hidden and --help (filtered by --h prefix)
				if len(candidates) != 2 {
					t.Fatalf("expected 2 candidates after filtering, got %d", len(candidates))
				}

				for _, c := range candidates {
					if c.Value != "--hidden" && c.Value != "--help" {
						t.Errorf("unexpected candidate after filtering: %q", c.Value)
					}
				}
			},
		},
		{
			name: "empty display uses value",
			context: &types.QueryContext{
				ParsedCommand: "git",
				ParsedArgs:    []string{},
			},
			mockOutput: `{
				"values": [
					{
						"value": "commit",
						"display": "",
						"description": "Record changes to the repository"
					}
				]
			}`,
			expectedCount: 1,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				if candidates[0].Display != "commit" {
					t.Errorf("expected display to fallback to value 'commit', got %q", candidates[0].Display)
				}
			},
		},
		{
			name: "carapace command error returns empty",
			context: &types.QueryContext{
				ParsedCommand: "unknown-cmd",
			},
			mockError:     errors.New("command not found"),
			expectedCount: 0,
		},
		{
			name: "invalid JSON returns error",
			context: &types.QueryContext{
				ParsedCommand: "fd",
			},
			mockOutput:  `{invalid json`,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			// Create mock executor
			mockExec := newMockExecutor()

			// Build expected command key
			cmdKey := "/usr/bin/carapace " + tc.context.ParsedCommand + " _carapace export "
			for _, arg := range tc.context.ParsedArgs {
				cmdKey += " " + arg
			}

			mockExec.addResponse(cmdKey, tc.mockOutput, tc.mockError)

			// Create source with mock
			source, err := sources.NewCarapaceSource(
				sources.WithBinPath("/usr/bin/carapace"),
				sources.WithExecutor(mockExec),
			)
			if err != nil {
				t.Fatalf("failed to create source: %v", err)
			}

			// Get completions
			candidates, err := source.GetCompletions(tc.context)

			if tc.expectError && err == nil {
				t.Fatal("expected error but got none")
			}

			if !tc.expectError && err != nil {
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

func TestCarapaceSource_Name(t *testing.T) {
	t.Parallel()

	source, err := sources.NewCarapaceSource(
		sources.WithBinPath("/usr/bin/carapace"),
		sources.WithExecutor(newMockExecutor()),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Name() != "carapace" {
		t.Errorf("expected name to be 'carapace', got %q", source.Name())
	}
}

func TestCarapaceSource_Priority(t *testing.T) {
	t.Parallel()

	source, err := sources.NewCarapaceSource(
		sources.WithBinPath("/usr/bin/carapace"),
		sources.WithExecutor(newMockExecutor()),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Priority() != 100 {
		t.Errorf("expected priority to be 100, got %d", source.Priority())
	}
}
