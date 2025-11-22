package cmd

import (
	"encoding/json"
	"fmt"

	"github.com/KyleKing/dotfiles/completion-server/internal/completion"
	"github.com/spf13/cobra"
)

var queryCmd = &cobra.Command{
	Use:   "query [command] [args...]",
	Short: "Query completions for a command",
	Long: `Query completion suggestions for a command with the given arguments.

Example:
  completion-server query "fd " --cursor 3
  completion-server query "git checkout " --cursor 13`,
	Args: cobra.MinimumNArgs(1),
	RunE: runQuery,
}

var (
	cursorPos  int
	maxResults int
	format     string
)

func init() {
	rootCmd.AddCommand(queryCmd)

	queryCmd.Flags().IntVar(&cursorPos, "cursor", -1, "Cursor position in the command")
	queryCmd.Flags().IntVar(&maxResults, "max", 5, "Maximum number of results to return")
	queryCmd.Flags().StringVar(&format, "format", "json", "Output format (json, text)")
}

func runQuery(cmd *cobra.Command, args []string) error {
	commandLine := args[0]
	if cursorPos == -1 {
		cursorPos = len(commandLine)
	}

	// Initialize completion engine
	engine, err := completion.New()
	if err != nil {
		return fmt.Errorf("failed to initialize completion engine: %w", err)
	}

	// Get completions
	completions, err := engine.Query(commandLine, cursorPos, maxResults)
	if err != nil {
		return fmt.Errorf("failed to query completions: %w", err)
	}

	// Output results
	switch format {
	case "json":
		return outputJSON(cmd, completions)
	case "text":
		return outputText(cmd, completions)
	default:
		return fmt.Errorf("unknown format: %s", format)
	}
}

func outputJSON(cmd *cobra.Command, completions []completion.Candidate) error {
	encoder := json.NewEncoder(cmd.OutOrStdout())
	encoder.SetIndent("", "  ")
	return encoder.Encode(completions)
}

func outputText(cmd *cobra.Command, completions []completion.Candidate) error {
	for _, c := range completions {
		fmt.Fprintf(cmd.OutOrStdout(), "%s\t%s\t%s\n", c.Value, c.Display, c.Description)
	}
	return nil
}
