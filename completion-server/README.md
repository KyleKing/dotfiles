# completion-server

IDE-like completion server for shell commands, providing rich, ranked completion suggestions with descriptions.

## Overview

`completion-server` brings IDE-quality completion to your shell by:

- **Rich Completions**: Shows flag descriptions, types, and examples
- **Smart Ranking**: Weights by frequency, recency, and context from shell history
- **Multiple Sources**: Integrates carapace-bin, usage, TLDR, man pages, and ZSH completions
- **Fast**: Written in Go for speed, with SQLite caching
- **Portable**: Works with any terminal (WezTerm, iTerm2, Alacritty, etc.)

## Features

### Current (v0.1.0)

- [x] Query command for getting completions
- [x] Carapace-bin integration
- [x] JSON and text output formats
- [x] Basic completion engine

### Planned

- [ ] Atuin history integration for ranking
- [ ] TLDR pages integration
- [ ] Man page parsing
- [ ] SQLite caching layer
- [ ] Context-aware ranking (git repo detection, file types)
- [ ] Bubbletea TUI for interactive selection
- [ ] ZSH widget for seamless integration
- [ ] WezTerm Lua integration

## Installation

### Prerequisites

```bash
# Install mise (if not already installed)
brew install mise

# Install dependencies
mise install
```

### Build

```bash
# Build the binary
mise run build

# Install to ~/.local/bin
mise run build:install
```

## Usage

### Query Completions

Get completions for a command:

```bash
completion-server query "fd " --cursor 3 --max 5
```

Output (JSON):
```json
[
  {
    "value": "--hidden",
    "display": "-H, --hidden",
    "description": "Search hidden files and directories",
    "score": 100,
    "source": "carapace"
  },
  {
    "value": "--type",
    "display": "-t, --type <type>",
    "description": "Filter by type (f=file, d=dir, l=symlink)",
    "score": 100,
    "source": "carapace"
  }
]
```

### Text Format

```bash
completion-server query "git checkout " --format text
```

Output:
```
--hidden    -H, --hidden    Search hidden files and directories
--type      -t, --type      Filter by type (f=file, d=dir, l=symlink)
```

## Development

### Project Structure

```
completion-server/
├── cmd/                    # CLI commands
│   ├── root.go            # Root command
│   └── query.go           # Query subcommand
├── internal/
│   ├── completion/        # Completion engine
│   │   └── engine.go
│   ├── ranker/            # Ranking algorithms
│   ├── sources/           # Completion sources
│   │   ├── source.go      # Source interface
│   │   ├── carapace.go    # Carapace-bin source
│   │   └── usage.go       # jdx/usage source
│   └── ui/                # Bubbletea UI (future)
├── pkg/
│   └── types/             # Shared types
│       └── types.go
├── main.go                # Entry point
├── mise.toml              # Mise configuration
├── hk.pkl                 # Task runner config
└── .golangci.toml         # Linter config
```

### Available Tasks

```bash
# Format code
mise run format

# Run linters
mise run lint
mise run lint-fix

# Run tests
mise run test
mise run test:coverage

# Build
mise run build

# Update dependencies
mise run update

# Run all CI checks
mise run ci
```

### Git Hooks

Install git hooks with `hk`:

```bash
# Install hooks
hk install --mise

# Pre-commit hook runs:
# - gofumpt (formatting)
# - golines (line length)
# - go mod tidy

# Pre-push hook runs:
# - All formatters
# - golangci-lint
# - go test
```

## Architecture

See [docs/wezterm-ide-completion-plan.md](../docs/wezterm-ide-completion-plan.md) for the full design plan.

### Data Flow

```
User Input → ZSH Widget → completion-server query
                         ↓
          [Completion Engine]
                         ↓
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   Carapace         Usage/TLDR       Atuin History
        ↓                ↓                ↓
        └────────────────┼────────────────┘
                         ↓
                [Ranking Engine]
                         ↓
                [Top N Results]
                         ↓
                   JSON Output
                         ↓
            ZSH Widget / Bubbletea TUI
```

### Completion Sources

| Source | Coverage | Priority | Status |
|--------|----------|----------|--------|
| carapace-bin | 1000+ commands | High | ✅ Implemented |
| jdx/usage | Any command with --help | Medium | 🚧 Planned |
| TLDR | ~300 commands | Low | 🚧 Planned |
| Man pages | All installed commands | Low | 🚧 Planned |
| ZSH completions | Existing ZSH functions | High | 🚧 Planned |

### Ranking Algorithm

```
score = base_score
      + (frequency * freq_weight)
      + (recency * recency_weight)
      + (success_rate * success_weight)
      + (context_boost)
```

Where:
- **Frequency**: Times used in history (from atuin)
- **Recency**: Time since last use (exponential decay)
- **Success Rate**: Ratio of successful executions
- **Context Boost**: Git repo, file type, directory matches

## Integration

### ZSH Widget (Planned)

Add to `.zshrc`:

```bash
# Completion widget
function _completion_widget() {
  local result=$(completion-server query "$BUFFER" --cursor $CURSOR --format json)
  # TODO: Parse and display with fzf or custom UI
}

zle -N completion-widget _completion_widget
bindkey '^T' completion-widget  # Ctrl+T to trigger
```

### WezTerm (Planned)

Add to `.wezterm.lua`:

```lua
-- TODO: Add WezTerm integration example
```

## Contributing

This is a personal project, but contributions are welcome! Please:

1. Follow the existing code style
2. Run `mise run ci` before submitting
3. Add tests for new features
4. Update documentation

## License

MIT

## See Also

- [WezTerm IDE Completion Design Plan](../docs/wezterm-ide-completion-plan.md)
- [carapace-bin](https://github.com/carapace-sh/carapace-bin) - Universal completion engine
- [jdx/usage](https://github.com/jdx/usage) - CLI spec parser
- [Bubbletea](https://github.com/charmbracelet/bubbletea) - TUI framework
- [atuin](https://github.com/atuinsh/atuin) - Shell history in SQLite
