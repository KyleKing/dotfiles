package main

import (
	"fmt"
	"os"

	"github.com/KyleKing/dotfiles/completion-server/cmd"
)

var (
	// Version is set during build via ldflags
	Version = "dev"
	// Commit is set during build via ldflags
	Commit = "unknown"
	// BuildDate is set during build via ldflags
	BuildDate = "unknown"
)

func main() {
	if err := cmd.Execute(Version, Commit, BuildDate); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
