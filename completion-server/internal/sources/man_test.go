package sources_test

import (
	"fmt"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/sources"
	"github.com/KyleKing/dotfiles/completion-server/internal/testutil"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewManSource(t *testing.T) {
	t.Parallel()

	// Test with mock executor that has man
	mockExec := &testutil.MockExecutor{
		LookPaths: map[string]string{
			"man": "/usr/bin/man",
		},
	}

	source, err := sources.NewManSource(sources.WithManExecutor(mockExec))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if source == nil {
		t.Fatal("expected non-nil source")
	}
}

func TestNewManSource_NotFound(t *testing.T) {
	t.Parallel()

	// Test with mock executor without man
	mockExec := &testutil.MockExecutor{
		LookPaths: map[string]string{},
	}

	_, err := sources.NewManSource(sources.WithManExecutor(mockExec))
	if err == nil {
		t.Error("expected error when man not found")
	}
}

func TestManSource_GetCompletions(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		manOutput      string
		commandLine    string
		expectedCount  int
		expectedValues []string
	}{
		{
			name:          "empty command returns nil",
			commandLine:   "",
			expectedCount: 0,
		},
		{
			name: "successful completion for ls",
			manOutput: `LS(1)                            User Commands                           LS(1)

NAME
       ls - list directory contents

SYNOPSIS
       ls [OPTION]... [FILE]...

DESCRIPTION
       -a, --all
              do not ignore entries starting with .

       -h, --human-readable
              with -l, print sizes in human readable format

       --help display this help and exit
`,
			commandLine:    "ls ",
			expectedCount:  5,
			expectedValues: []string{"-a", "--all", "-h", "--human-readable", "--help"},
		},
		{
			name: "completion with filtering",
			manOutput: `GIT(1)                               Git Manual                              GIT(1)

OPTIONS
       --version
              Prints the Git suite version

       --help
              Prints the synopsis and a list of options
`,
			commandLine:    "git --v",
			expectedCount:  1,
			expectedValues: []string{"--version"},
		},
		{
			name:          "man command error returns empty",
			manOutput:     "",
			commandLine:   "unknowncommand ",
			expectedCount: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			mockExec := &testutil.MockExecutor{
				Output: tc.manOutput,
				LookPaths: map[string]string{
					"man": "/usr/bin/man",
				},
			}

			// Set error for empty output
			if tc.manOutput == "" && tc.commandLine != "" {
				mockExec.Err = fmt.Errorf("man page not found")
			}

			source, err := sources.NewManSource(sources.WithManExecutor(mockExec))
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
						if c.Source != "man" {
							t.Errorf("expected source 'man', got '%s'", c.Source)
						}
						if c.Score != 50.0 {
							t.Errorf("expected score 50.0, got %f", c.Score)
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

func TestManSource_Name(t *testing.T) {
	t.Parallel()

	mockExec := &testutil.MockExecutor{
		LookPaths: map[string]string{
			"man": "/usr/bin/man",
		},
	}

	source, err := sources.NewManSource(sources.WithManExecutor(mockExec))
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Name() != "man" {
		t.Errorf("expected name 'man', got '%s'", source.Name())
	}
}

func TestManSource_Priority(t *testing.T) {
	t.Parallel()

	mockExec := &testutil.MockExecutor{
		LookPaths: map[string]string{
			"man": "/usr/bin/man",
		},
	}

	source, err := sources.NewManSource(sources.WithManExecutor(mockExec))
	if err != nil {
		t.Fatalf("failed to create source: %v", err)
	}

	if source.Priority() != 50 {
		t.Errorf("expected priority 50, got %d", source.Priority())
	}
}
