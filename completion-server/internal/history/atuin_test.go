package history_test

import (
	"database/sql"
	"path/filepath"
	"testing"
	"time"

	_ "github.com/mattn/go-sqlite3"

	"github.com/KyleKing/dotfiles/completion-server/internal/history"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// createTestDB creates a test Atuin database with sample data
func createTestDB(t *testing.T) string {
	t.Helper()

	// Create temp directory
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test-history.db")

	// Create database
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatalf("failed to create test database: %v", err)
	}
	defer db.Close()

	// Create history table (simplified Atuin schema)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS history (
			id TEXT PRIMARY KEY,
			timestamp INTEGER NOT NULL,
			duration INTEGER NOT NULL,
			exit INTEGER NOT NULL,
			command TEXT NOT NULL,
			cwd TEXT NOT NULL,
			session TEXT NOT NULL,
			hostname TEXT NOT NULL
		)
	`)
	if err != nil {
		t.Fatalf("failed to create table: %v", err)
	}

	// Insert test data
	now := time.Now().UnixNano()
	hour := int64(time.Hour)
	day := int64(24 * time.Hour)

	testData := []struct {
		id       string
		command  string
		timestamp int64
		duration int64
		exit     int
	}{
		// fd command with various flags
		{"1", "fd", now - 1*hour, 100_000_000, 0},
		{"2", "fd --hidden", now - 2*hour, 150_000_000, 0},
		{"3", "fd --hidden", now - 3*hour, 120_000_000, 0},
		{"4", "fd --type f", now - 4*hour, 200_000_000, 0},
		{"5", "fd --type d", now - 1*day, 180_000_000, 0},
		{"6", "fd --help", now - 2*day, 50_000_000, 0},
		{"7", "fd --hidden --type f", now - 3*day, 250_000_000, 0},
		{"8", "fd some-pattern", now - 4*day, 300_000_000, 1}, // Failed command

		// git commands
		{"9", "git status", now - 1*hour, 80_000_000, 0},
		{"10", "git commit -m 'test'", now - 2*hour, 500_000_000, 0},
		{"11", "git push", now - 3*hour, 1_000_000_000, 0},
		{"12", "git pull", now - 4*hour, 900_000_000, 0},
		{"13", "git log", now - 1*day, 100_000_000, 0},

		// Other commands
		{"14", "ls -la", now - 1*hour, 50_000_000, 0},
		{"15", "grep pattern file.txt", now - 2*hour, 200_000_000, 0},
	}

	for _, data := range testData {
		_, err = db.Exec(`
			INSERT INTO history (id, timestamp, duration, exit, command, cwd, session, hostname)
			VALUES (?, ?, ?, ?, ?, '/home/test', 'session', 'hostname')
		`, data.id, data.timestamp, data.duration, data.exit, data.command)
		if err != nil {
			t.Fatalf("failed to insert test data: %v", err)
		}
	}

	return dbPath
}

func TestNewAtuinProvider(t *testing.T) {
	t.Parallel()

	// This test will fail if Atuin is not installed, which is expected
	// We're mainly testing the error path here
	_, err := history.NewAtuinProvider()
	if err != nil {
		// Expected if Atuin is not installed
		t.Logf("Atuin not found (expected in test environment): %v", err)
	}
}

func TestNewAtuinProviderWithPath(t *testing.T) {
	t.Parallel()

	dbPath := createTestDB(t)

	provider, err := history.NewAtuinProviderWithPath(dbPath)
	if err != nil {
		t.Fatalf("failed to create provider: %v", err)
	}
	defer provider.Close()

	if provider == nil {
		t.Fatal("expected provider to be non-nil")
	}
}

func TestAtuinProvider_GetCommandStats(t *testing.T) {
	t.Parallel()

	dbPath := createTestDB(t)

	provider, err := history.NewAtuinProviderWithPath(dbPath)
	if err != nil {
		t.Fatalf("failed to create provider: %v", err)
	}
	defer provider.Close()

	testCases := []struct {
		name          string
		command       string
		limit         int
		expectError   bool
		validateStats func(*testing.T, []types.HistoryStats)
	}{
		{
			name:    "fd command stats",
			command: "fd",
			limit:   10,
			validateStats: func(t *testing.T, stats []types.HistoryStats) {
				t.Helper()

				if len(stats) == 0 {
					t.Fatal("expected at least one stat")
				}

				// Should have stats for different flags
				foundHidden := false

				for _, stat := range stats {
					if stat.Command != "fd" {
						t.Errorf("expected command to be 'fd', got %q", stat.Command)
					}

					if stat.Frequency <= 0 {
						t.Errorf("expected frequency > 0, got %d", stat.Frequency)
					}

					if stat.SuccessRate < 0 || stat.SuccessRate > 1 {
						t.Errorf("expected success rate between 0 and 1, got %f", stat.SuccessRate)
					}

					if stat.Flag == "--hidden" {
						foundHidden = true
					}
				}

				if !foundHidden {
					t.Error("expected to find --hidden flag in stats")
				}
			},
		},
		{
			name:    "git command stats",
			command: "git",
			limit:   10,
			validateStats: func(t *testing.T, stats []types.HistoryStats) {
				t.Helper()

				if len(stats) == 0 {
					t.Fatal("expected at least one stat")
				}

				// Should have stats for git subcommands
				foundCommit := false
				foundStatus := false

				for _, stat := range stats {
					if stat.Flag == "commit" {
						foundCommit = true
					}
					if stat.Flag == "status" {
						foundStatus = true
					}
				}

				if !foundCommit {
					t.Error("expected to find 'commit' in stats")
				}
				if !foundStatus {
					t.Error("expected to find 'status' in stats")
				}
			},
		},
		{
			name:    "unknown command returns empty",
			command: "unknown-command",
			limit:   10,
			validateStats: func(t *testing.T, stats []types.HistoryStats) {
				t.Helper()

				if len(stats) != 0 {
					t.Errorf("expected 0 stats for unknown command, got %d", len(stats))
				}
			},
		},
		{
			name:    "limit is respected",
			command: "fd",
			limit:   2,
			validateStats: func(t *testing.T, stats []types.HistoryStats) {
				t.Helper()

				if len(stats) > 2 {
					t.Errorf("expected at most 2 stats (limit=2), got %d", len(stats))
				}
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			stats, err := provider.GetCommandStats(tc.command, tc.limit)

			if tc.expectError && err == nil {
				t.Fatal("expected error but got none")
			}

			if !tc.expectError && err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if tc.validateStats != nil {
				tc.validateStats(t, stats)
			}
		})
	}
}

func TestAtuinProvider_GetFlagStats(t *testing.T) {
	t.Parallel()

	dbPath := createTestDB(t)

	provider, err := history.NewAtuinProviderWithPath(dbPath)
	if err != nil {
		t.Fatalf("failed to create provider: %v", err)
	}
	defer provider.Close()

	testCases := []struct {
		name          string
		command       string
		flags         []string
		expectError   bool
		validateStats func(*testing.T, map[string]types.HistoryStats)
	}{
		{
			name:    "fd flags",
			command: "fd",
			flags:   []string{"--hidden", "--type"},
			validateStats: func(t *testing.T, stats map[string]types.HistoryStats) {
				t.Helper()

				if len(stats) == 0 {
					t.Fatal("expected at least one flag stat")
				}

				if stat, ok := stats["--hidden"]; ok {
					if stat.Frequency <= 0 {
						t.Errorf("expected frequency > 0 for --hidden, got %d", stat.Frequency)
					}
					if stat.SuccessRate <= 0 {
						t.Errorf("expected success rate > 0 for --hidden, got %f", stat.SuccessRate)
					}
				}
			},
		},
		{
			name:    "empty flags returns empty map",
			command: "fd",
			flags:   []string{},
			validateStats: func(t *testing.T, stats map[string]types.HistoryStats) {
				t.Helper()

				if len(stats) != 0 {
					t.Errorf("expected empty map for no flags, got %d entries", len(stats))
				}
			},
		},
		{
			name:    "unknown flags return empty map",
			command: "fd",
			flags:   []string{"--nonexistent-flag"},
			validateStats: func(t *testing.T, stats map[string]types.HistoryStats) {
				t.Helper()

				if len(stats) != 0 {
					t.Errorf("expected empty map for unknown flags, got %d entries", len(stats))
				}
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			stats, err := provider.GetFlagStats(tc.command, tc.flags)

			if tc.expectError && err == nil {
				t.Fatal("expected error but got none")
			}

			if !tc.expectError && err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if tc.validateStats != nil {
				tc.validateStats(t, stats)
			}
		})
	}
}

func TestAtuinProvider_Close(t *testing.T) {
	t.Parallel()

	dbPath := createTestDB(t)

	provider, err := history.NewAtuinProviderWithPath(dbPath)
	if err != nil {
		t.Fatalf("failed to create provider: %v", err)
	}

	err = provider.Close()
	if err != nil {
		t.Fatalf("failed to close provider: %v", err)
	}

	// Calling Close again should not panic
	err = provider.Close()
	if err != nil {
		t.Logf("second close returned error (expected): %v", err)
	}
}
