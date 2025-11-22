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

### Current (v0.3.0)

**Completion Sources:**
- [x] **Carapace-bin integration** (1000+ commands)
  - Export format parsing
  - Prefix filtering
  - Graceful error handling
- [x] **jdx/usage CLI integration**
  - --help parsing for any command
  - Flag completion with short/long forms
  - Flag value completion with choices
  - Context-aware completion

**Intelligent Ranking:**
- [x] **Atuin history integration**
  - SQLite database queries
  - Frequency, recency, success rate tracking
  - Per-flag usage statistics
  - Graceful fallback if unavailable
- [x] **Multi-factor ranking algorithm**
  - Logarithmic frequency scaling
  - Exponential recency decay (24h half-life)
  - Success rate weighting
  - Context-aware boosting
  - Configurable weights
- [x] **Git context detection**
  - Repository detection via directory tree walk
  - Boosts git-related flags in git repos
  - Working directory tracking

**Performance:**
- [x] **Daemon mode with Unix socket**
  - Pre-loaded completion engine
  - <10ms response times
  - JSON protocol
  - Concurrent connection handling
  - Graceful shutdown

**User Interface:**
- [x] **Floating overlay with lipgloss**
  - Main panel showing top 5 completions
  - Detail panel with metadata
  - Adaptive positioning (left/right/hidden)
  - Toggleable above/below prompt
  - ANSI escape code rendering
- [x] **ZSH widget integration**
  - Auto-trigger on typing (configurable delay)
  - Keyboard navigation (arrows, Enter, Esc)
  - Position toggle (Shift-Tab)
  - Manual trigger mode

**Testing & Quality:**
- [x] **Comprehensive test coverage**
  - 67+ tests across all packages
  - API-level integration tests
  - Mock infrastructure for testability
  - All tests parallelized
  - 45+ enabled linters (golangci-lint)

### Planned

- [ ] TLDR pages integration
- [ ] Man page parsing fallback
- [ ] SQLite caching layer for completions
- [ ] Fuzzy matching for partial completions
- [ ] Integration with existing ZSH completion system
- [ ] WezTerm Lua integration (optional)
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

### Quick Start (Recommended)

1. **Start the daemon:**
   ```bash
   completion-server daemon &
   ```

2. **Load the ZSH widget** (add to your `.zshrc`):
   ```bash
   source /path/to/completion-server/zsh/completion-widget.zsh
   ```

3. **Use completions:**
   - Press `Ctrl-X Ctrl-C` to trigger completions
   - Navigate with `Up`/`Down` or `Ctrl-P`/`Ctrl-N`
   - Accept with `Enter`, cancel with `Escape`
   - Toggle position with `Shift-Tab`

See [zsh/README.md](zsh/README.md) for full widget documentation.

### Commands

#### Daemon Mode

Run as a background daemon for <10ms response times:

```bash
# Start daemon
completion-server daemon

# With custom socket
completion-server daemon --socket /tmp/custom.sock
```

The daemon pre-loads all completion sources and history, enabling fast queries.

#### Query Command

Get completions directly (useful for testing):

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
    "score": 150.5,
    "source": "carapace",
    "metadata": {}
  }
]
```

Text format:
```bash
completion-server query "git checkout " --format text
```

#### Show Command (Demo)

Display the UI with completions:

```bash
completion-server show "fd "
```

This demonstrates the floating overlay UI with main panel, detail panel, and different positions.

## Development

### Project Structure

```
completion-server/
├── cmd/                    # CLI commands
│   ├── root.go            # Root command
│   ├── query.go           # Query subcommand
│   ├── daemon.go          # Daemon mode
│   └── show.go            # UI demo command
├── internal/
│   ├── completion/        # Completion engine
│   │   └── engine.go
│   ├── context/           # Context detection (git repo, etc.)
│   ├── daemon/            # Unix socket server
│   │   └── server.go
│   ├── history/           # History providers (Atuin)
│   │   └── atuin.go
│   ├── ranker/            # Multi-factor ranking
│   │   └── ranker.go
│   ├── sources/           # Completion sources
│   │   ├── source.go      # Source interface
│   │   ├── carapace.go    # Carapace-bin source
│   │   └── usage.go       # jdx/usage source
│   ├── testutil/          # Testing utilities
│   └── ui/                # Lipgloss UI rendering
│       ├── model.go       # UI state model
│       ├── renderer.go    # Rendering logic
│       └── styles.go      # Lipgloss styles
├── pkg/
│   ├── protocol/          # Daemon JSON protocol
│   └── types/             # Shared types
├── zsh/                   # ZSH widget integration
│   ├── completion-widget.zsh
│   └── README.md
├── main.go                # Entry point
├── mise.toml              # Mise configuration
├── hk.pkl                 # Git hooks (pre-commit, pre-push)
└── .golangci.toml         # 45+ linter configuration
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
| carapace-bin | 1000+ commands | 100 | ✅ Implemented |
| jdx/usage | Any command with --help | 90 | ✅ Implemented |
| TLDR | ~300 commands | 80 | 🚧 Planned |
| Man pages | All installed commands | 70 | 🚧 Planned |
| ZSH completions | Existing ZSH functions | 85 | 🚧 Planned |

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
