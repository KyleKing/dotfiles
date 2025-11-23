package sources_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/internal/testutil"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewTldrSource(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		opts    []sources.TldrOption
		wantErr bool
	}{
		{
			name: "with custom bin path",
			opts: []sources.TldrOption{
				sources.WithTldrBinPath("/usr/bin/tldr"),
			},
			wantErr: false,
		},
		{
			name: "with custom executor",
			opts: []sources.TldrOption{
				sources.WithTldrExecutor(&testutil.MockExecutor{}),
			},
			wantErr: true, // Will fail because LookPath returns error
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			source, err := sources.NewTldrSource(tc.opts...)

			if tc.wantErr {
				if err == nil {
					t.Error("expected error but got nil")
				}
				return
			}

			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if source == nil {
				t.Fatal("expected non-nil source")
			}
		})
	}
}

func TestTldrSource_GetCompletions(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		tldrOutput     string
		commandLine    string
		expectedCount  int
		expectedValues []string
	}{
		{
			name: "empty command returns nil",
			commandLine: "",
			expectedCount: 0,
		},
		{
			name: "successful completion for fd",
			tldrOutput: "# fd\n\n> Find entries in the filesystem.\n> More information: <https://github.com/sharkdp/fd>.\n\n- Recursively find files matching a pattern:\n\n`fd pattern`\n\n- Find files that begin with \"foo\":\n\n`fd '^foo'`\n\n- Find files with a specific extension:\n\n`fd --extension txt`\n\n- Find files in a specific directory:\n\n`fd pattern path/to/dir`\n\n- Include ignored and hidden files:\n\n`fd --hidden --no-ignore pattern`\n",
			commandLine:    "fd ",
			expectedCount:  3,
			expectedValues: []string{"--extension", "--hidden", "--no-ignore"},
		},
		{
			name: "completion with filtering",
			tldrOutput: "# git\n\n> Distributed version control system.\n> More information: <https://git-scm.com/>.\n\n- Clone a repository:\n\n`git clone https://example.com/repo`\n\n- Show the status:\n\n`git status`\n\n- Add files:\n\n`git add --all`\n\n- Commit changes:\n\n`git commit --message \"message\"`\n",
			commandLine:    "git --m",
			expectedCount:  1,
			expectedValues: []string{"--message"},
		},
		{
			name: "tldr command error returns empty",
			tldrOutput: "",
			commandLine: "unknowncommand ",
			expectedCount: 0,
		},
		{
			name: "short flags extracted",
			tldrOutput: "# ls\n\n> List directory contents.\n\n- List files:\n\n`ls -la`\n\n- Human readable sizes:\n\n`ls -lh`\n",
			commandLine:    "ls -",
			expectedCount:  2, // Short flags (-la, -lh) are extracted
			expectedValues: []string{"-la", "-lh"},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			mockExec := &testutil.MockExecutor{
				Output: tc.tldrOutput,
			}

			// Set error for empty output (simulating command not found)
			if tc.tldrOutput == "" && tc.commandLine != "" {
				mockExec.Err = fmt.Errorf("tldr page not found")
			}

			source, err := sources.NewTldrSource(
				sources.WithTldrBinPath("/usr/bin/tldr"),
				sources.WithTldrExecutor(mockExec),
			)
			if err != nil {
				t.Fatalf("failed to create source: %v", err)
			}

			ctx := &types.QueryContext{
				CommandLine:   tc.commandLine,
				ParsedCommand: parseCommand(tc.commandLine),
				ParsedArgs:    parseArgs(tc.commandLine),
			}

			completions, err := source.GetCompletions(ctx)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if len(completions) != tc.expectedCount {
				t.Errorf("expected %d completions, got %d", tc.expectedCount, len(completions))
				for i, c := range completions {
					t.Logf("  [%d] %s: %s", i, c.Value, c.Description)
				}
			}

			// Verify expected values
			for _, expectedValue := range tc.expectedValues {
				found := false
				for _, c := range completions {
					if c.Value == expectedValue {
						found = true

						// Verify fields
						if c.Source != "tldr" {
							t.Errorf("expected source 'tldr', got '%s'", c.Source)
						}
						if c.Score != 75.0 {
							t.Errorf("expected score 75.0, got %f", c.Score)
						}
						if c.Description == "" {
							t.Error("expected non-empty description")
						}

						break
					}
				}
				if !found {
					t.Errorf("expected value '%s' not found in completions", expectedValue)
				}
			}
		})
	}
}

func TestTldrSource_Name(t *testing.T) {
	t.Parallel()

	source, err := sources.NewTldrSource(
		sources.WithTldrBinPath("/usr/bin/tldr"),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Name() != "tldr" {
		t.Errorf("expected name 'tldr', got '%s'", source.Name())
	}
}

func TestTldrSource_Priority(t *testing.T) {
	t.Parallel()

	source, err := sources.NewTldrSource(
		sources.WithTldrBinPath("/usr/bin/tldr"),
	)
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Priority() != 75 {
		t.Errorf("expected priority 75, got %d", source.Priority())
	}
}

// Helper functions (duplicated from other tests for parallel execution)
func parseCommand(commandLine string) string {
	parts := strings.Fields(commandLine)
	if len(parts) == 0 {
		return ""
	}
	return parts[0]
}

func parseArgs(commandLine string) []string {
	parts := strings.Fields(commandLine)
	if len(parts) <= 1 {
		return []string{}
	}
	return parts[1:]
}
