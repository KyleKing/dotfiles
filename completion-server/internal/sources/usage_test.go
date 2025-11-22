package sources_test

import (
	"errors"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewUsageSource(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name        string
		opts        []sources.UsageOption
		expectError bool
	}{
		{
			name: "with custom bin path",
			opts: []sources.UsageOption{
				sources.WithUsageBinPath("/usr/bin/usage"),
			},
			expectError: false,
		},
		{
			name: "with custom executor",
			opts: []sources.UsageOption{
				sources.WithUsageBinPath("/usr/bin/usage"),
				sources.WithUsageExecutor(newMockExecutor()),
			},
			expectError: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			source, err := sources.NewUsageSource(tc.opts...)

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

func TestUsageSource_GetCompletions(t *testing.T) {
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
				"name": "fd",
				"flags": [
					{
						"long": "--hidden",
						"short": "-H",
						"description": "Search hidden files and directories"
					},
					{
						"long": "--type",
						"short": "-t",
						"description": "Filter by type",
						"arg": {
							"choices": ["f", "d", "l"]
						}
					}
				],
				"args": [
					{
						"name": "pattern",
						"description": "Search pattern",
						"choices": []
					}
				]
			}`,
			expectedCount: 2,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				if len(candidates) != 2 {
					t.Fatalf("expected 2 candidates, got %d", len(candidates))
				}

				// Check first flag candidate
				if candidates[0].Value != "--hidden" {
					t.Errorf("expected first candidate value to be '--hidden', got %q", candidates[0].Value)
				}

				if candidates[0].Display != "-H, --hidden" {
					t.Errorf("expected display to be '-H, --hidden', got %q", candidates[0].Display)
				}

				if candidates[0].Source != "usage" {
					t.Errorf("expected source to be 'usage', got %q", candidates[0].Source)
				}

				if candidates[0].Score != 90.0 {
					t.Errorf("expected score to be 90.0, got %f", candidates[0].Score)
				}
			},
		},
		{
			name: "completion with flag filtering",
			context: &types.QueryContext{
				ParsedCommand: "fd",
				ParsedArgs:    []string{"--h"},
			},
			mockOutput: `{
				"name": "fd",
				"flags": [
					{
						"long": "--hidden",
						"short": "-H",
						"description": "Search hidden files"
					},
					{
						"long": "--help",
						"short": "",
						"description": "Show help"
					},
					{
						"long": "--type",
						"short": "-t",
						"description": "Filter by type"
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
			name: "flag with choices",
			context: &types.QueryContext{
				ParsedCommand: "fd",
				ParsedArgs:    []string{"--type", ""},
			},
			mockOutput: `{
				"name": "fd",
				"flags": [
					{
						"long": "--type",
						"short": "-t",
						"description": "Filter by type",
						"arg": {
							"choices": ["f", "d", "l"]
						}
					}
				]
			}`,
			expectedCount: 3,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				// Should have all 3 choices
				expectedChoices := map[string]bool{"f": true, "d": true, "l": true}

				for _, c := range candidates {
					if !expectedChoices[c.Value] {
						t.Errorf("unexpected choice: %q", c.Value)
					}

					if c.Metadata["type"] != "flag-value" {
						t.Errorf("expected metadata type to be 'flag-value', got %v", c.Metadata["type"])
					}
				}
			},
		},
		{
			name: "flag without short form",
			context: &types.QueryContext{
				ParsedCommand: "git",
				ParsedArgs:    []string{},
			},
			mockOutput: `{
				"name": "git",
				"flags": [
					{
						"long": "--version",
						"short": "",
						"description": "Show version"
					}
				]
			}`,
			expectedCount: 1,
			validateResult: func(t *testing.T, candidates []types.Candidate) {
				t.Helper()

				if candidates[0].Display != "--version" {
					t.Errorf("expected display to be '--version', got %q", candidates[0].Display)
				}
			},
		},
		{
			name: "usage command error returns empty",
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
			cmdKey := "/usr/bin/usage --spec " + tc.context.ParsedCommand

			mockExec.addResponse(cmdKey, tc.mockOutput, tc.mockError)

			// Create source with mock
			source, err := sources.NewUsageSource(
				sources.WithUsageBinPath("/usr/bin/usage"),
				sources.WithUsageExecutor(mockExec),
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

func TestUsageSource_Name(t *testing.T) {
	t.Parallel()

	source, err := sources.NewUsageSource(
		sources.WithUsageBinPath("/usr/bin/usage"),
		sources.WithUsageExecutor(newMockExecutor()),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Name() != "usage" {
		t.Errorf("expected name to be 'usage', got %q", source.Name())
	}
}

func TestUsageSource_Priority(t *testing.T) {
	t.Parallel()

	source, err := sources.NewUsageSource(
		sources.WithUsageBinPath("/usr/bin/usage"),
		sources.WithUsageExecutor(newMockExecutor()),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Priority() != 90 {
		t.Errorf("expected priority to be 90, got %d", source.Priority())
	}
}
