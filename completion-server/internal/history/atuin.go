package history

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "github.com/mattn/go-sqlite3" // SQLite driver

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Provider interface for history data
type Provider interface {
	GetCommandStats(command string, limit int) ([]types.HistoryStats, error)
	GetFlagStats(command string, flags []string) (map[string]types.HistoryStats, error)
	Close() error
}

// AtuinProvider queries Atuin's SQLite database for history
type AtuinProvider struct {
	db *sql.DB
}

// NewAtuinProvider creates a new Atuin history provider
func NewAtuinProvider() (*AtuinProvider, error) {
	// Find Atuin database path
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}

	dbPath := filepath.Join(home, ".local", "share", "atuin", "history.db")

	// Check if database exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("atuin database not found at %s: %w", dbPath, err)
	}

	// Open database in read-only mode
	db, err := sql.Open("sqlite3", fmt.Sprintf("file:%s?mode=ro", dbPath))
	if err != nil {
		return nil, fmt.Errorf("failed to open atuin database: %w", err)
	}

	return &AtuinProvider{db: db}, nil
}

// NewAtuinProviderWithPath creates a provider with a custom database path (for testing)
func NewAtuinProviderWithPath(dbPath string) (*AtuinProvider, error) {
	db, err := sql.Open("sqlite3", fmt.Sprintf("file:%s?mode=ro", dbPath))
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	return &AtuinProvider{db: db}, nil
}

// GetCommandStats retrieves usage statistics for a command
func (a *AtuinProvider) GetCommandStats(command string, limit int) ([]types.HistoryStats, error) {
	// Query format:
	// - Get all history entries starting with the command
	// - Calculate frequency, last used, avg duration, success rate
	// - Group by the first flag (for flag-level stats)

	query := `
		WITH command_entries AS (
			SELECT
				command,
				timestamp,
				duration,
				exit
			FROM history
			WHERE command LIKE ? || '%'
			ORDER BY timestamp DESC
			LIMIT 1000
		)
		SELECT
			? as base_command,
			COALESCE(
				CASE
					WHEN instr(substr(command, length(?) + 2), ' ') > 0
					THEN substr(
						substr(command, length(?) + 2),
						1,
						instr(substr(command, length(?) + 2), ' ') - 1
					)
					ELSE substr(command, length(?) + 2)
				END,
				''
			) as flag,
			COUNT(*) as frequency,
			MAX(timestamp) as last_used,
			AVG(duration) as avg_duration,
			SUM(CASE WHEN exit = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as success_rate
		FROM command_entries
		GROUP BY flag
		ORDER BY frequency DESC
		LIMIT ?
	`

	rows, err := a.db.Query(query, command, command, command, command, command, command, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query history: %w", err)
	}
	defer rows.Close()

	var stats []types.HistoryStats

	for rows.Next() {
		var (
			baseCommand    string
			flag           string
			frequency      int
			lastUsedNs     int64
			avgDurationNs  float64
			successRate    float64
		)

		err := rows.Scan(&baseCommand, &flag, &frequency, &lastUsedNs, &avgDurationNs, &successRate)
		if err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}

		stat := types.HistoryStats{
			Command:     baseCommand,
			Flag:        flag,
			Frequency:   frequency,
			LastUsed:    time.Unix(0, lastUsedNs),
			AvgDuration: int64(avgDurationNs / 1_000_000), // Convert ns to ms
			SuccessRate: successRate,
		}

		stats = append(stats, stat)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating rows: %w", err)
	}

	return stats, nil
}

// GetFlagStats retrieves statistics for specific flags
func (a *AtuinProvider) GetFlagStats(command string, flags []string) (map[string]types.HistoryStats, error) {
	if len(flags) == 0 {
		return make(map[string]types.HistoryStats), nil
	}

	// Get stats for each flag individually
	result := make(map[string]types.HistoryStats)

	for _, flag := range flags {
		pattern := fmt.Sprintf("%%%s %s%%", command, flag)

		var (
			baseCommand   string
			frequency     int
			lastUsedNs    sql.NullInt64
			avgDurationNs sql.NullFloat64
			successRateNullable sql.NullFloat64
		)

		err := a.db.QueryRow(`
			SELECT
				? as base_command,
				COUNT(*) as frequency,
				MAX(timestamp) as last_used,
				AVG(duration) as avg_duration,
				SUM(CASE WHEN exit = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as success_rate
			FROM history
			WHERE command LIKE ?
		`, command, pattern).Scan(&baseCommand, &frequency, &lastUsedNs, &avgDurationNs, &successRateNullable)

		if err == sql.ErrNoRows {
			continue
		} else if err != nil {
			return nil, fmt.Errorf("failed to query flag stats: %w", err)
		}

		// Skip if no matches found (frequency = 0)
		if frequency == 0 {
			continue
		}

		lastUsed := time.Now()
		if lastUsedNs.Valid {
			lastUsed = time.Unix(0, lastUsedNs.Int64)
		}

		avgDuration := int64(0)
		if avgDurationNs.Valid {
			avgDuration = int64(avgDurationNs.Float64 / 1_000_000) // Convert ns to ms
		}

		successRate := 0.0
		if successRateNullable.Valid {
			successRate = successRateNullable.Float64
		}

		result[flag] = types.HistoryStats{
			Command:     baseCommand,
			Flag:        flag,
			Frequency:   frequency,
			LastUsed:    lastUsed,
			AvgDuration: avgDuration,
			SuccessRate: successRate,
		}
	}

	return result, nil
}

// Close closes the database connection
func (a *AtuinProvider) Close() error {
	if a.db != nil {
		return a.db.Close()
	}

	return nil
}
