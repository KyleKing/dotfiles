package cmd

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/KyleKing/dotfiles/completion-server/internal/daemon"
	"github.com/spf13/cobra"
)

var daemonCmd = &cobra.Command{
	Use:   "daemon",
	Short: "Run completion server as a daemon",
	Long: `Run the completion server as a background daemon listening on a Unix socket.

The daemon pre-loads the completion engine (sources, history, ranker) for fast
response times (<10ms). Clients connect via Unix socket and send JSON requests.

Socket location: /tmp/completion-server-$USER.sock`,
	RunE: runDaemon,
}

var socketPath string

func init() {
	rootCmd.AddCommand(daemonCmd)

	daemonCmd.Flags().StringVar(&socketPath, "socket", "", "Unix socket path (default: /tmp/completion-server-$USER.sock)")
}

func runDaemon(cmd *cobra.Command, args []string) error {
	// Create server with optional custom socket path
	var opts []daemon.ServerOption
	if socketPath != "" {
		opts = append(opts, daemon.WithSocketPath(socketPath))
	}

	server, err := daemon.NewServer(opts...)
	if err != nil {
		return fmt.Errorf("failed to create server: %w", err)
	}

	// Start server
	if err := server.Start(); err != nil {
		return fmt.Errorf("failed to start server: %w", err)
	}

	fmt.Fprintf(cmd.OutOrStdout(), "Daemon listening on %s\n", server.SocketPath())
	fmt.Fprintln(cmd.OutOrStdout(), "Press Ctrl+C to stop")

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	fmt.Fprintln(cmd.OutOrStdout(), "\nShutting down...")

	// Stop server
	if err := server.Stop(); err != nil {
		return fmt.Errorf("failed to stop server: %w", err)
	}

	fmt.Fprintln(cmd.OutOrStdout(), "Daemon stopped")
	return nil
}
