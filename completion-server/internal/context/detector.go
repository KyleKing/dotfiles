package context

import (
	"os"
	"path/filepath"
)

// Detector detects contextual information about the environment
type Detector struct{}

// New creates a new context detector
func New() *Detector {
	return &Detector{}
}

// IsInGitRepo checks if the current directory is inside a git repository
func (d *Detector) IsInGitRepo(dir string) bool {
	// Walk up the directory tree looking for .git
	currentDir := dir
	for {
		gitDir := filepath.Join(currentDir, ".git")
		if info, err := os.Stat(gitDir); err == nil {
			// .git exists - check if it's a directory or file (submodule)
			return info.IsDir() || info.Mode().IsRegular()
		}

		// Move to parent directory
		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			// Reached root
			break
		}
		currentDir = parentDir
	}

	return false
}

// GetWorkingDirectory returns the current working directory
func (d *Detector) GetWorkingDirectory() (string, error) {
	return os.Getwd()
}
