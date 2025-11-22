# GitHub Orphaned Branches Finder

A CLI tool to identify and report orphaned branches across all repositories in a GitHub namespace (user or organization).

## What it finds

1. **Branches with closed/merged PRs**: Branches that still exist after their associated pull request was closed or merged
2. **Stale branches without PRs**: Branches older than a configurable threshold (default: 7 days) that have no associated pull request
3. **Recent branches without PRs**: Active branches without PRs (informational only)

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- [uv](https://docs.astral.sh/uv/) for running the Python script
- Python 3.11 or higher

## Installation

No installation required! The script uses uv's inline script metadata for dependency management.

## Usage

### Basic usage

```bash
# Analyze all repositories for a user
uv run Developer/kyleking/gh-orphaned-branches.py --namespace USERNAME

# Analyze an organization
uv run Developer/kyleking/gh-orphaned-branches.py --namespace ORG_NAME
```

### Advanced options

```bash
# Use shorter alias
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME

# Change stale threshold to 14 days
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME --stale-days 14

# Include forked repositories
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME --include-forks

# Output as JSON
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME --output json

# Output as Markdown
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME --output markdown

# Combine options
uv run Developer/kyleking/gh-orphaned-branches.py -n USERNAME -d 5 --output markdown
```

## Output Formats

### Table (default)
Rich formatted tables with color-coded results and action items.

### JSON
Machine-readable JSON output for integration with other tools.

### Markdown
Markdown-formatted report suitable for GitHub issues or documentation.

## Examples

### Find stale branches older than 5 days
```bash
uv run Developer/kyleking/gh-orphaned-branches.py -n myusername --stale-days 5
```

### Generate a report for your organization
```bash
uv run Developer/kyleking/gh-orphaned-branches.py -n myorg --output markdown > orphaned-branches-report.md
```

### Check all repos including forks
```bash
uv run Developer/kyleking/gh-orphaned-branches.py -n myusername --include-forks
```

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

## License

Part of the dotfiles repository. Use freely!
