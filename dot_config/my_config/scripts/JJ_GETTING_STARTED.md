# Getting Started with jj and jj-stack

Quick start guide for using Jujutsu (jj) with jj-stack for stacked PRs.

## Initial Setup

### 1. Authenticate with GitHub

```bash
# Option 1: GitHub CLI (Recommended)
gh auth login

# Option 2: Environment Variable
export GITHUB_TOKEN="ghp_your_token_here"

# Verify authentication
jst auth test
```

### 2. Initialize jj in a repository

For existing Git repository:
```bash
cd ~/path/to/repo
jinit  # Helper function that runs: jj git init --colocate
```

For new repository:
```bash
jj clone git@github.com:user/repo.git
cd repo
```

## Your First Stacked PRs

### Example: Create a 3-PR Stack

```bash
# 1. Create first change
jnew refactor-utils "Refactor utility functions"
# Edit files for refactoring...
# jj automatically tracks changes

# 2. Stack second change on first
jstack-on add-feature "Add new feature using refactored utils"
# Edit files for new feature...

# 3. Stack third change on second
jstack-on add-tests "Add tests for new feature"
# Write tests...

# 4. View your stack
jstack
# or use the TUI
lzj  # lazyjj

# 5. Submit entire stack to GitHub
jst submit refactor-utils add-feature add-tests
```

This will create:
- PR #1: `refactor-utils` → `main`
- PR #2: `add-feature` → `refactor-utils`
- PR #3: `add-tests` → `add-feature`

### After Review Comments

```bash
# Edit any commit in the stack
je <revision-id>  # or use lazyjj to find the revision

# Make changes...
# Then commit
jj commit -m "Address review feedback"

# Re-submit the affected PRs
jst submit refactor-utils  # Updates PR and all dependent PRs
```

### After First PR Merges

```bash
# When refactor-utils is merged on GitHub:

# 1. Clean up and rebase
jclean-merged  # Fetches, rebases onto main

# 2. Re-submit remaining PRs
jst submit add-feature add-tests

# Now your PRs are:
# - PR #2: add-feature → main (updated!)
# - PR #3: add-tests → add-feature
```

## Daily Workflow Cheat Sheet

### Creating Changes
```bash
jnew <name> "description"       # New change from main
jstack-on <name> "description"  # Stack on current
je <revision>                   # Edit specific revision
jdesc -m "new description"      # Update description
```

### Viewing Status
```bash
js                  # Status
jss                 # Status + stack (or jstat)
jl                  # Log
jstack              # Current stack
jmyb                # My bookmarks
lzj                 # lazyjj TUI
```

### Submitting PRs
```bash
jst submit <bookmark>           # Submit single PR
jst submit <b1> <b2> <b3>      # Submit stack
jsubmit-stack                   # Submit all bookmarks
```

### Syncing
```bash
jgf                 # Fetch from remote
jrebase-main        # Fetch + rebase onto main
jclean-merged       # Fetch, rebase, clean up
```

### Git Operations
```bash
jgp                 # Git push
jgpc                # Git push current change
jgpf                # Git push force current
```

## Tips

### Use lazyjj for Visual Workflows
```bash
lzj  # Opens interactive TUI
```
- Navigate commits visually
- Edit, squash, describe changes
- Much easier than remembering revision IDs

### Check Before Submitting
```bash
# Review what will be submitted
jstack
jl -r main..@

# Check diff
jd
```

### Bookmark Management
```bash
# List all bookmarks
jbl

# Create bookmark at current commit
jbc my-feature -r @

# Delete bookmark
jbd old-feature
```

## Troubleshooting

### "jj not found" error with jst
```bash
# Ensure jj is in PATH
which jj

# Add cargo bin to PATH (add to .zshrc)
export PATH="$HOME/.cargo/bin:$PATH"
```

### Can't authenticate with jst
```bash
# Re-authenticate
gh auth login

# Or set token
export GITHUB_TOKEN="your_token"

# Test
jst auth test
```

### PR has wrong base branch
```bash
# Check bookmark relationships
jl -r 'bookmarks()'

# Rebase to fix
jj rebase -b feature-b -d correct-parent
```

## Learn More

- Full workflow guide: `~/.config/my_config/scripts/JJ_STACK_WORKFLOW.md`
- Quick help: `jhelp`
- Official jj docs: https://jj-vcs.github.io/jj/
- jj-stack repo: https://github.com/keanemind/jj-stack

## Common Patterns

### Parallel Stacks
```bash
# Work on multiple independent features
jnew feature-a "Feature A"
# ... work on A

jnew feature-b "Feature B"  # From main, not stacked on A
# ... work on B

jst submit feature-a feature-b  # Two independent PRs
```

### Fixing Earlier Commit in Stack
```bash
# Current stack: A → B → C (you're at C)
# Need to fix A

# Method 1: Edit A directly
je <revision-A>
# Make fixes
jj commit -m "Fix A"

# Method 2: Create fix and squash
jn <revision-A>
# Make fixes
jj squash  # Squash into A

# Conflicts in B or C will be automatically flagged
jss  # Check status
```

### Splitting a Change
```bash
# Current change has too many unrelated changes
jsplit  # Interactive split (or jj split)
# Mark which changes go in first vs second commit
```
