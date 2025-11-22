package cmd

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"

	"github.com/KyleKing/dotfiles/completion-server/internal/ui"
	"github.com/KyleKing/dotfiles/completion-server/pkg/protocol"
	"github.com/spf13/cobra"
)

var showCmd = &cobra.Command{
	Use:   "show [command]",
	Short: "Show completions with UI (demo)",
	Long: `Connect to the daemon and display completions with the floating overlay UI.

This is a demonstration command that shows how the UI renders completions.
In practice, the ZSH widget will handle the interactive display.

Example:
  completion-server show "fd "
  completion-server show "git checkout "`,
	Args: cobra.MinimumNArgs(1),
	RunE: runShow,
}

var (
	showCursor int
	showMax    int
	showSocket string
)

func init() {
	rootCmd.AddCommand(showCmd)

	showCmd.Flags().IntVar(&showCursor, "cursor", -1, "Cursor position")
	showCmd.Flags().IntVar(&showMax, "max", 5, "Maximum results")
	showCmd.Flags().StringVar(&showSocket, "socket", "", "Socket path")
}

func runShow(cmd *cobra.Command, args []string) error {
	commandLine := args[0]

	// Determine socket path
	socketPath := showSocket
	if socketPath == "" {
		user := os.Getenv("USER")
		if user == "" {
			user = "default"
		}
		socketPath = filepath.Join("/tmp", fmt.Sprintf("completion-server-%s.sock", user))
	}

	// Connect to daemon
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return fmt.Errorf("failed to connect to daemon (is it running?): %w", err)
	}
	defer conn.Close()

	// Send request
	req := protocol.Request{
		CommandLine: commandLine,
		CursorPos:   showCursor,
		MaxResults:  showMax,
	}

	encoder := json.NewEncoder(conn)
	if err := encoder.Encode(req); err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	// Read response
	var resp protocol.Response
	decoder := json.NewDecoder(conn)
	if err := decoder.Decode(&resp); err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	if resp.Error != "" {
		return fmt.Errorf("daemon error: %s", resp.Error)
	}

	// Render UI
	model := ui.NewModel(resp.Completions)
	model.Width = 100  // Demo width
	model.Height = 24  // Demo height

	renderer := ui.NewRenderer()

	// Display different views
	fmt.Println("=== Main Panel Only ===")
	model.ShowDetail = false
	output := renderer.Render(model)
	fmt.Println(output)

	fmt.Println("\n=== With Detail Panel ===")
	model.ShowDetail = true
	model.DetermineDetailPosition()
	output = renderer.Render(model)
	fmt.Println(output)

	fmt.Println("\n=== After Moving Down ===")
	model.NextItem()
	output = renderer.Render(model)
	fmt.Println(output)

	fmt.Println("\n=== Position Above (with ANSI codes) ===")
	model.Position = ui.PositionAbove
	output = renderer.RenderWithPosition(model, 10, 5)
	fmt.Println(output)

	return nil
}
