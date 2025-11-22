package types

import "time"

// Candidate represents a single completion candidate
type Candidate struct {
	// Value is the text to be inserted
	Value string `json:"value"`

	// Display is the text shown in the UI (e.g., "-H, --hidden")
	Display string `json:"display"`

	// Description is the help text for this completion
	Description string `json:"description"`

	// Score is the ranking score (higher is better)
	Score float64 `json:"score"`

	// Source indicates where this completion came from
	Source string `json:"source"`

	// Metadata contains additional information
	Metadata map[string]interface{} `json:"metadata,omitempty"`
}

// CommandSpec represents the parsed specification for a command
type CommandSpec struct {
	// Name is the command name
	Name string `json:"name"`

	// Flags are the available flags
	Flags []FlagSpec `json:"flags"`

	// Args are positional arguments
	Args []ArgSpec `json:"args,omitempty"`

	// Subcommands are available subcommands
	Subcommands []string `json:"subcommands,omitempty"`

	// Source indicates where this spec came from
	Source string `json:"source"`

	// UpdatedAt is when this spec was last updated
	UpdatedAt time.Time `json:"updated_at"`
}

// FlagSpec represents a single flag specification
type FlagSpec struct {
	// Long is the long form (e.g., "--hidden")
	Long string `json:"long"`

	// Short is the short form (e.g., "-H")
	Short string `json:"short,omitempty"`

	// Description is the help text
	Description string `json:"description"`

	// ArgType indicates if the flag takes an argument
	ArgType string `json:"arg_type,omitempty"` // "", "required", "optional"

	// Choices are valid values if the flag takes an argument
	Choices []string `json:"choices,omitempty"`

	// Deprecated indicates if this flag is deprecated
	Deprecated bool `json:"deprecated,omitempty"`
}

// ArgSpec represents a positional argument
type ArgSpec struct {
	// Name is the argument name
	Name string `json:"name"`

	// Description is the help text
	Description string `json:"description"`

	// Required indicates if this argument is required
	Required bool `json:"required"`

	// Multiple indicates if this argument accepts multiple values
	Multiple bool `json:"multiple,omitempty"`

	// Choices are valid values if restricted
	Choices []string `json:"choices,omitempty"`
}

// HistoryStats represents usage statistics for a command/flag
type HistoryStats struct {
	// Command is the base command
	Command string `json:"command"`

	// Flag is the specific flag (empty for command-level stats)
	Flag string `json:"flag,omitempty"`

	// Frequency is how many times this was used
	Frequency int `json:"frequency"`

	// LastUsed is when this was last used
	LastUsed time.Time `json:"last_used"`

	// AvgDuration is the average execution time in milliseconds
	AvgDuration int64 `json:"avg_duration_ms"`

	// SuccessRate is the ratio of successful executions (0.0-1.0)
	SuccessRate float64 `json:"success_rate"`

	// CoOccurrences tracks flags used together
	CoOccurrences map[string]int `json:"co_occurrences,omitempty"`
}

// QueryContext represents the context for a completion query
type QueryContext struct {
	// CommandLine is the full command line text
	CommandLine string `json:"command_line"`

	// CursorPos is the cursor position
	CursorPos int `json:"cursor_pos"`

	// ParsedCommand is the detected command name
	ParsedCommand string `json:"parsed_command"`

	// ParsedArgs are the arguments before the cursor
	ParsedArgs []string `json:"parsed_args"`

	// InGitRepo indicates if the current directory is in a git repo
	InGitRepo bool `json:"in_git_repo,omitempty"`

	// WorkingDir is the current working directory
	WorkingDir string `json:"working_dir"`
}
