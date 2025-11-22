package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	version   string
	commit    string
	buildDate string
)

var rootCmd = &cobra.Command{
	Use:   "completion-server",
	Short: "IDE-like completion server for shell commands",
	Long: `A completion server that provides IDE-like command completion
for shell commands, integrating with carapace-bin, usage, TLDR, and
shell history to provide rich, ranked completion suggestions.`,
	Version: "", // Set in Execute()
}

// Execute runs the root command
func Execute(ver, cmt, date string) error {
	version = ver
	commit = cmt
	buildDate = date

	rootCmd.Version = fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, buildDate)

	return rootCmd.Execute()
}

func init() {
	rootCmd.SetVersionTemplate(`{{with .Name}}{{printf "%s " .}}{{end}}{{printf "%s" .Version}}
`)
}
