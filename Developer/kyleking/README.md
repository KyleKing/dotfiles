# GitHub Orphaned Branches Finder

A functional CLI tool to identify and report orphaned branches across all repositories in a GitHub namespace (user or organization).

## What it finds

1. **Branches with closed/merged PRs**: Branches that still exist after their associated pull request was closed or merged
2. **Stale branches without PRs**: Branches older than a configurable threshold (default: 7 days) that have no associated pull request
3. **Recent branches without PRs**: Active branches without PRs (informational only)

## Architecture

The tool is built with a **functional programming approach** featuring:

- **Pure functions** for data transformations
- **Composable logic** with small, reusable utilities
- **Immutable data structures** where practical
- **Separation of concerns** (API, core logic, formatters, CLI)
- **Generic reusable helpers** for common operations

### Project Structure

```
gh_orphaned_branches/
├── __init__.py            # Package initialization
├── cli.py                 # CLI interface (argparse)
├── core.py                # Core business logic (pure functions)
├── github_api.py          # GitHub API wrapper (httpx)
├── formatters.py          # Output formatters (Rich)
├── interactive.py         # Interactive mode (Rich prompts)
├── graph.py               # Branch relationship graph analysis
├── utils.py               # Generic reusable utilities
└── tests/                 # Test suite with pytest-vcr
    ├── conftest.py        # Test fixtures
    ├── test_core.py       # Core logic tests
    ├── test_github_api.py # API tests with VCR
    ├── test_formatters.py # Formatter tests
    ├── test_interactive.py # Interactive mode tests
    ├── test_graph.py      # Graph analysis tests
    └── test_utils.py      # Utility tests
```

## Prerequisites

- **GitHub Token**: Set `GITHUB_TOKEN` or `GH_TOKEN` environment variable, or have [`gh` CLI](https://cli.github.com/) authenticated
- [uv](https://docs.astral.sh/uv/) for running the Python script (or use pip)
- Python 3.11 or higher

## Installation

No installation required! The script uses uv's inline script metadata for dependency management.

Alternatively, install as a package:

```bash
cd Developer/kyleking
pip install -e .
```

## Usage

### Using the uv script (recommended)

```bash
# Basic usage
uv run Developer/kyleking/gh-orphaned-branches.py --namespace USERNAME

# Or use the shorter path if in the directory
cd Developer/kyleking
uv run gh-orphaned-branches.py -n USERNAME
```

### After package installation

```bash
gh-orphaned-branches --namespace USERNAME
```

### Interactive Mode

Use `--interactive` or `-i` to review and take actions on branches:

```bash
# Interactive mode
gh-orphaned-branches -n USERNAME --interactive

# Interactive with custom stale threshold
gh-orphaned-branches -n USERNAME -d 14 --interactive
```

**Interactive features:**
- 🔍 View commit details and branch comparison (ahead/behind)
- 🗑️ Delete branches individually or in batches
- 🔀 Create pull requests for branches
- ⚡ Batch operations with confirmation prompts
- 🎨 Rich terminal UI with colored prompts

### Branch Graph Mode

Use `--graph` or `-g` to explore branch relationships and create stacked PRs:

```bash
# Explore branch graph for a specific repository
gh-orphaned-branches -n USERNAME --graph REPO_NAME

# Example with real repo
gh-orphaned-branches -n myorg --graph my-project
```

**Graph features:**
- 📊 **Tree visualization** - see which branches are ahead/behind default branch
- 🔢 **Comparison matrix** - view ahead/behind counts for all branch pairs
- 🔗 **Stacked PRs** - create PR chains for dependent branches
- 🎯 **Smart ordering** - automatically calculate optimal PR dependency order
- 📋 **Multi-select** - choose multiple branches (e.g., `1,3,5` or `1-10` or `all`)

**Stacked PR workflow:**
1. View branch tree to understand relationships
2. Select multiple related branches
3. Tool calculates dependency order based on commit ancestry
4. Creates PRs in sequence (e.g., main←feature-a, feature-a←feature-b, feature-b←feature-c)

### Non-Interactive Options

```bash
# Change stale threshold to 14 days
gh-orphaned-branches -n USERNAME --stale-days 14

# Include forked repositories
gh-orphaned-branches -n USERNAME --include-forks

# Output as JSON
gh-orphaned-branches -n USERNAME --output json

# Output as Markdown
gh-orphaned-branches -n USERNAME --output markdown

# Combine options
gh-orphaned-branches -n USERNAME -d 5 --include-forks -o markdown
```

## Output Formats

### Table (default)
Rich formatted tables with color-coded results and action items.

### JSON
Machine-readable JSON output for integration with other tools:
```json
{
  "repo-name": {
    "closed_pr_branches": [...],
    "no_pr_branches_stale": [...],
    "no_pr_branches_recent": [...]
  }
}
```

### Markdown
Markdown-formatted report suitable for GitHub issues or documentation.

## Examples

### Interactive cleanup workflow
```bash
# Review and clean up branches interactively
uv run gh-orphaned-branches.py -n myusername --interactive

# Example interactive session:
# - View branch details (commits ahead/behind)
# - Delete closed PR branches in batch
# - Create PRs for branches without them
# - Skip branches that need review
```

### Explore branch relationships and create stacked PRs
```bash
# Visualize branch graph for a repository
uv run gh-orphaned-branches.py -n myorg --graph my-project

# Example graph session:
# 1. View tree: see branches ahead/behind default
# 2. View matrix: see all branch-to-branch comparisons
# 3. Select branches: e.g., "1,3,5" or "all"
# 4. Create stacked PRs: tool calculates optimal order
#    - If feature-b builds on feature-a which builds on main:
#      Creates: main←feature-a, feature-a←feature-b
```

### Find stale branches older than 5 days
```bash
uv run gh-orphaned-branches.py -n myusername --stale-days 5
```

### Generate a report for your organization
```bash
uv run gh-orphaned-branches.py -n myorg --output markdown > orphaned-branches-report.md
```

### Check all repos including forks
```bash
uv run gh-orphaned-branches.py -n myusername --include-forks
```

## Functional Programming Highlights

### Minimal, Focused Utilities

The tool includes only essential utilities in `utils.py`:

- **Pagination**: Generic `paginate()` helper for any paginated API
- **Date utilities**: Pure stdlib-only functions (`parse_iso_date`, `days_ago`, `create_age_threshold`)

Design principle: **No unused code**. All functions are actually used in the codebase.

### Pure Core Logic

The core business logic (`core.py`) consists of pure functions:

- **Branch classification**: `classify_branch()` - pure predicate-based logic
- **Data transformation**: `create_branch_info()` - immutable data creation
- **Aggregation**: `calculate_summary()` - pure statistical functions

### API Abstraction

The GitHub API wrapper (`github_api.py`) uses:

- **httpx for direct HTTP**: No subprocess overhead, enables VCR testing
- **Higher-order functions**: `_create_paginated_fetcher()`
- **Private functions**: All helpers prefixed with `_`, clear public API
- **Error handling**: HTTP-native error propagation
- **Write operations**: DELETE for branch deletion, POST for PR creation

### Interactive Features

The interactive module (`interactive.py`) provides:

- **Rich prompts**: Menu-driven interface with `Prompt` and `Confirm`
- **Branch actions**: View details, delete, create PR
- **Batch operations**: Handle multiple branches with single confirmation
- **Safe operations**: All destructive actions require confirmation

## Development

### Running Tests

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run all tests
pytest

# Run with coverage
pytest --cov=gh_orphaned_branches --cov-report=html

# Run specific test file
pytest gh_orphaned_branches/tests/test_utils.py

# Run VCR tests (with real API - requires gh authentication)
pytest -v -m 'not skip' gh_orphaned_branches/tests/test_github_api.py
```

### Test Structure

Tests use:
- **pytest** for the test framework
- **pytest-vcr** for recording/replaying HTTP interactions
- **pytest monkeypatch** for mocking (no external dependencies)
- **Pure function testing** - easy to test without complex setup

### Code Quality

The codebase emphasizes:
- **Type hints** throughout for better IDE support
- **Docstrings** for all public functions
- **Pure functions** where possible for testability
- **Functional composition** over imperative loops

## Understanding the Output

The tool categorizes branches into three groups:

1. **Branches with Closed/Merged PRs** (Red/Magenta)
   - Safe to delete immediately
   - The PR has been closed or merged but the branch remains

2. **Stale Branches without PR** (Yellow/Red)
   - Review before deleting
   - No PR exists and the branch is older than the threshold
   - May be abandoned work or experiments

3. **Recent Branches without PR** (Blue)
   - Informational only
   - Active work that may not have a PR yet
   - Monitor these for future action

## Suggested Actions

### Option 1: Interactive Mode (Recommended)

Use `--interactive` for a guided workflow:

```bash
gh-orphaned-branches -n USERNAME --interactive
```

Interactive mode provides:
- Category-level actions (delete all, skip, review individually)
- Per-branch actions (view details, delete, create PR, skip)
- Batch deletion with confirmation
- Commit comparison (ahead/behind)
- Safe confirmation prompts for all destructive operations

### Option 2: Manual Cleanup

After running the report in table/JSON/markdown mode:

1. **Delete branches with closed/merged PRs**
   ```bash
   cd REPO_NAME
   git push origin --delete BRANCH_NAME
   ```

2. **Review stale branches**
   - Check with team members if unsure
   - Create a PR if the work should be preserved
   - Delete if confirmed as abandoned

3. **Monitor recent branches**
   - Follow up with developers if needed
   - Check back after a few days

## Performance

The script uses GitHub's API efficiently:
- Paginated requests for large result sets
- Only fetches necessary data
- Progress indicators for long-running operations
- Functional approach minimizes memory overhead

For organizations with many repositories, the script may take several minutes to complete.

## Troubleshooting

### "gh: command not found"
Install GitHub CLI: https://cli.github.com/

### Authentication errors
Make sure you're authenticated with gh:
```bash
gh auth login
```

### Rate limiting
The script uses the GitHub CLI which respects your authentication. If you hit rate limits, wait an hour or authenticate with a token that has higher limits.

### Module import errors
If using as a package, make sure to install it:
```bash
cd Developer/kyleking
pip install -e .
```

## Design Principles

This tool follows functional programming principles:

1. **Pure functions** - No side effects except for I/O boundaries
2. **Immutability** - Data structures are not mutated in place
3. **Composition** - Small functions combined to create complex behavior
4. **Separation** - Logic, I/O, and presentation are clearly separated
5. **Testability** - Pure functions are easy to test

## Dependencies

### Runtime (minimal)
- `rich` - Terminal formatting and tables
- `httpx` - HTTP client for GitHub API

### Development
- `pytest` - Test framework
- `pytest-vcr` - HTTP interaction recording
- `pytest-cov` - Code coverage reporting

**Zero unnecessary dependencies:**
- ✅ stdlib `datetime` instead of python-dateutil
- ✅ stdlib `argparse` instead of click
- ✅ `httpx` for direct HTTP (enables VCR testing)
- ✅ pytest's `monkeypatch` instead of pytest-mock

## License

Part of the dotfiles repository. Use freely!
