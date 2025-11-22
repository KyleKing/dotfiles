package context_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/context"
)

func TestDetector_IsInGitRepo(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name     string
		setup    func(t *testing.T) string
		expected bool
	}{
		{
			name: "directory with .git directory",
			setup: func(t *testing.T) string {
				t.Helper()

				tmpDir := t.TempDir()
				gitDir := filepath.Join(tmpDir, ".git")
				if err := os.Mkdir(gitDir, 0755); err != nil {
					t.Fatalf("failed to create .git dir: %v", err)
				}

				return tmpDir
			},
			expected: true,
		},
		{
			name: "subdirectory of git repo",
			setup: func(t *testing.T) string {
				t.Helper()

				tmpDir := t.TempDir()
				gitDir := filepath.Join(tmpDir, ".git")
				if err := os.Mkdir(gitDir, 0755); err != nil {
					t.Fatalf("failed to create .git dir: %v", err)
				}

				subDir := filepath.Join(tmpDir, "subdir", "nested")
				if err := os.MkdirAll(subDir, 0755); err != nil {
					t.Fatalf("failed to create subdir: %v", err)
				}

				return subDir
			},
			expected: true,
		},
		{
			name: "directory without .git",
			setup: func(t *testing.T) string {
				t.Helper()

				return t.TempDir()
			},
			expected: false,
		},
		{
			name: "git submodule (.git file)",
			setup: func(t *testing.T) string {
				t.Helper()

				tmpDir := t.TempDir()
				gitFile := filepath.Join(tmpDir, ".git")
				if err := os.WriteFile(gitFile, []byte("gitdir: ../.git/modules/submodule"), 0644); err != nil {
					t.Fatalf("failed to create .git file: %v", err)
				}

				return tmpDir
			},
			expected: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			dir := tc.setup(t)

			detector := context.New()
			result := detector.IsInGitRepo(dir)

			if result != tc.expected {
				t.Errorf("expected %v, got %v", tc.expected, result)
			}
		})
	}
}

func TestDetector_GetWorkingDirectory(t *testing.T) {
	t.Parallel()

	detector := context.New()
	dir, err := detector.GetWorkingDirectory()

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if dir == "" {
		t.Error("expected non-empty working directory")
	}

	// Verify it's an absolute path
	if !filepath.IsAbs(dir) {
		t.Errorf("expected absolute path, got %s", dir)
	}
}
