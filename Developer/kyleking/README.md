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
├── __init__.py           # Package initialization
├── cli.py                # CLI interface (argparse)
├── core.py               # Core business logic (pure functions)
├── github_api.py         # GitHub API wrapper (functional)
├── formatters.py         # Output formatters (pure functions)
├── utils.py              # Generic reusable utilities
└── tests/                # Test suite with pytest-vcr
    ├── conftest.py       # Test fixtures
    ├── test_core.py      # Core logic tests
    ├── test_github_api.py # API tests with VCR
    ├── test_formatters.py # Formatter tests
    └── test_utils.py     # Utility tests
```

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- [uv](https://docs.astral.sh/uv/) for running the Python script
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
uv run Developer/kyleking/gh-orphaned-branches-v2.py --namespace USERNAME

# Or use the shorter path if in the directory
cd Developer/kyleking
uv run gh-orphaned-branches-v2.py -n USERNAME
```

### After package installation

```bash
gh-orphaned-branches --namespace USERNAME
```

### Advanced options

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

### Find stale branches older than 5 days
```bash
uv run gh-orphaned-branches-v2.py -n myusername --stale-days 5
```

### Generate a report for your organization
```bash
uv run gh-orphaned-branches-v2.py -n myorg --output markdown > orphaned-branches-report.md
```

### Check all repos including forks
```bash
uv run gh-orphaned-branches-v2.py -n myusername --include-forks
```

## Functional Programming Highlights

### Composable Utilities

The tool includes reusable functional utilities in `utils.py`:

- **Function composition**: `compose()`, `pipe()`
- **Data transformation**: `filter_map()`, `partition()`, `flatten()`
- **Pagination**: Generic `paginate()` helper
- **Date utilities**: Pure functions for date operations
- **Data extraction**: `safe_get()`, `extract_fields()`

Example:
```python
# Compose functions for data transformation
transform = pipe(
    lambda x: filter_map(is_stale, extract_info, x),
    lambda x: group_by(lambda b: b['repo'], x)
)
```

### Pure Core Logic

The core business logic (`core.py`) consists of pure functions:

- **Branch classification**: `classify_branch()` - pure predicate-based logic
- **Data transformation**: `create_branch_info()` - immutable data creation
- **Aggregation**: `calculate_summary()` - pure statistical functions

### API Abstraction

The GitHub API wrapper (`github_api.py`) uses:

- **Higher-order functions**: `create_paginated_fetcher()`
- **Function composition**: Combining API calls functionally
- **Error handling**: Pure error propagation

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

After running the report:

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

### Runtime
- `rich` - Terminal formatting and tables
- `python-dateutil` - Date parsing

### Development
- `pytest` - Test framework
- `pytest-vcr` - HTTP interaction recording
- `pytest-cov` - Code coverage reporting

All using **standard library alternatives** where possible (argparse instead of click).

## License

Part of the dotfiles repository. Use freely!
