# Jujutsu (jj) Stacked Diffs Workflow with jj-stack

This guide covers using jj with jj-stack for managing stacked PRs on GitHub.

## Prerequisites

### Installation

All required tools are managed through this dotfiles repo:

- **jj**: Installed via Homebrew (`brew install jj`) - see `Brewfile.personal-m2`
- **jj-stack**: Installed via npm (`npm install -g jj-stack`) - see `dot_default-npm-packages`
- **gh**: GitHub CLI for authentication (`brew install gh`) - see `Brewfile.personal-m2`
- **lazyjj**: TUI for jj (`brew install lazyjj`) - see `Brewfile.personal-m2`

### Authentication Setup

jj-stack needs GitHub authentication. Priority order:

1. **GitHub CLI (Recommended)**:
   ```bash
   gh auth login
   ```

2. **Environment Variable**:
   ```bash
   export GITHUB_TOKEN="your_token_here"
   # Or
   export GH_TOKEN="your_token_here"
   ```

3. **Create Personal Access Token**:
   - Visit: https://github.com/settings/tokens
   - Scope needed: `repo`

**Verify authentication**:
```bash
jst auth test
```

## Basic Workflow

### 1. Initialize a Repository

For a new Git repo:
```bash
# Clone with Git
git clone git@github.com:user/repo.git
cd repo

# Initialize jj (it will colocate with Git)
jj git init --colocate
```

For existing jj repo:
```bash
jj clone git@github.com:user/repo.git
```

### 2. Create Stacked Changes

**Single change**:
```bash
# Start from main
jj new main -m "Add feature X"

# Make your changes...
# Edit files, write code

# Create a bookmark for this change
jj bookmark create feature-x -r @

# Continue working...
jj describe -m "Add feature X implementation"
```

**Stacked changes**:
```bash
# First change
jj new main -m "Refactor module A"
jj bookmark create refactor-a -r @
# Make changes...

# Second change (stacked on first)
jj new refactor-a -m "Add feature using refactored A"
jj bookmark create feature-b -r @
# Make changes...

# Third change (stacked on second)
jj new feature-b -m "Add tests for feature B"
jj bookmark create tests-b -r @
# Make changes...
```

### 3. Submit to GitHub

**Submit a single PR**:
```bash
jst submit feature-x
```

**Submit a stack**:
```bash
# Submit all at once (jst will determine the order)
jst submit refactor-a feature-b tests-b

# Or submit one at a time
jst submit refactor-a
jst submit feature-b  # Will automatically target refactor-a as base
jst submit tests-b    # Will automatically target feature-b as base
```

jj-stack automatically:
- Determines the correct base branch (parent bookmark or main/master/trunk)
- Creates PRs with titles from commit descriptions
- Adds navigation comments showing the stack hierarchy

### 4. Update PRs After Changes

**Make changes to any commit in the stack**:
```bash
# Edit a specific revision
jj edit <revision-id>
# Make changes...
jj commit -m "Address review feedback"

# Or describe changes into existing commit
jj new <revision-id>
# Make changes...
jj squash  # Squash into parent
```

**Push updates**:
```bash
# Push specific bookmarks
jst submit feature-x

# Or use jj directly
jj git push -c @
# Or force push if you rewrote history
jj git push --force -c @
```

**Update entire stack**:
```bash
# After making changes anywhere in the stack
jst submit refactor-a feature-b tests-b
```

### 5. After PR Merges

**When bottom of stack merges**:
```bash
# Fetch latest from GitHub
jj git fetch

# Rebase remaining work onto main
jj rebase -d main

# Update remaining PRs
jst submit feature-b tests-b
```

jj automatically:
- Removes merged bookmark after fetch
- Abandons unreachable commits
- You just need to rebase and re-submit

**Clean workflow**:
```bash
# Fetch and rebase in one go
jj git fetch && jj rebase -d main

# Submit updated stack
jst submit $(jj bookmark list | grep -v 'main' | awk '{print $1}')
```

## Common Workflows

### Viewing Your Stack

```bash
# View current stack
jj log -r ::@

# View all bookmarks
jj bookmark list

# Use lazyjj TUI for visual exploration
lazyjj
```

### Addressing Review Comments

**Option 1: Add commits (common)**:
```bash
# Make changes
# ...
jj commit -m "Address review feedback"

# Update PR
jst submit feature-x
```

**Option 2: Rewrite commits (clean history)**:
```bash
# Edit the commit that needs changes
jj edit <revision-id>
# Make changes...
jj squash  # Or jj amend in newer versions

# Force push
jj git push --force -c @

# Update PR
jst submit feature-x
```

### Rebasing a Stack

**Rebase onto updated main**:
```bash
jj git fetch
jj rebase -d main
jst submit feature-x feature-y
```

**Rebase middle of stack**:
```bash
# Move feature-b to different base
jj rebase -b feature-b -d new-base
```

### Working with Multiple Stacks

```bash
# View all your bookmarks
jj bookmark list

# Switch between different stacks
jj edit <revision-id>

# Create parallel stacks
jj new main -m "Stack 2 feature A"
jj bookmark create stack2-a -r @
```

## Advanced Tips

### Aliases

The `.jjconfig.toml` includes helpful aliases:

```bash
# Git-like commands
jj st          # status
jj l           # log
jj d           # diff
jj commit      # describe
jj branch      # bookmark

# Stack management
jj stack       # Show current stack
jj rebase-main # Rebase onto main
```

### Revset Queries

```bash
# Show your bookmarks (not remote)
jj log -r 'bookmarks() & ~remote_bookmarks()'

# Show stack from main to current
jj log -r 'main..@'

# Show all changes not in main
jj log -r 'main..'
```

### Integration with difftastic

The config uses difftastic for better diffs:

```bash
# View diff with syntax highlighting
jj diff

# Compare specific revisions
jj diff -r <rev1> -r <rev2>
```

## Troubleshooting

### jst fails with "jj not found"

```bash
# Ensure jj is in PATH
which jj

# If using cargo, ensure ~/.cargo/bin is in PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Authentication fails

```bash
# Test authentication
jst auth test

# Re-authenticate with gh
gh auth login

# Or set token manually
export GITHUB_TOKEN="your_token"
```

### PRs have wrong base branch

```bash
# Check bookmark graph
jj log -r 'bookmarks()'

# Verify parent relationship
jj log -r 'feature-x~'

# Manually rebase if needed
jj rebase -b feature-x -d correct-base
```

### Conflicts after rebase

```bash
# View conflicts
jj status

# Resolve conflicts in files, then
jj diff  # Verify resolution

# Continue
jj squash  # Or commit
```

## Comparison with Git

| Git | Jujutsu | Description |
|-----|---------|-------------|
| `git status` | `jj status` | Show working tree status |
| `git checkout -b feature` | `jj new -m "feature"` | Create new change |
| `git branch feature` | `jj bookmark create feature` | Create bookmark/branch |
| `git add .` | (automatic) | Changes are auto-tracked |
| `git commit` | `jj describe` | Describe current change |
| `git rebase main` | `jj rebase -d main` | Rebase onto main |
| `git log` | `jj log` | View history |
| `git diff` | `jj diff` | View changes |
| `git push` | `jj git push` | Push to remote |
| `git push -f` | `jj git push --force` | Force push |
| `git pull` | `jj git fetch && jj rebase` | Fetch and rebase |

## Resources

- [jj Official Docs](https://jj-vcs.github.io/jj/)
- [jj-stack GitHub](https://github.com/keanemind/jj-stack)
- [Working with GitHub](https://jj-vcs.github.io/jj/latest/github/)
- [Steve's jj Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/)
- [jj for Git Users](https://www.paped.com/guides/a-short-guide-to-jujutsu-jj-for-git-users/)

## Quick Reference

```bash
# Initialize
jj git init --colocate

# Create change
jj new main -m "description"
jj bookmark create name -r @

# Submit to GitHub
jst submit bookmark-name

# Update after changes
jj describe -m "updated description"
jst submit bookmark-name

# After PR merge
jj git fetch
jj rebase -d main
jst submit remaining-bookmarks

# View status
jj status
jj log
lazyjj

# Authentication
gh auth login
jst auth test
```
