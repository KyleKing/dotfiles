#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Jujutsu (jj) and jj-stack configuration and aliases

# ============================================================================
# Basic jj Aliases
# ============================================================================

# Note: 'jst' is reserved for jj-stack CLI, using 'js' for status
alias js='jj status'
alias jl='jj log'
alias jd='jj diff'
alias jn='jj new'
alias je='jj edit'
alias jdesc='jj describe'

# ============================================================================
# Bookmark Management
# ============================================================================

alias jb='jj bookmark'
alias jbl='jj bookmark list'
alias jbc='jj bookmark create'
alias jbd='jj bookmark delete'

# ============================================================================
# Git Integration
# ============================================================================

alias jgf='jj git fetch'
alias jgp='jj git push'
alias jgpc='jj git push -c @'  # Push current change
alias jgpf='jj git push --force -c @'  # Force push current

# ============================================================================
# Stacked Diff Workflows
# ============================================================================

# Submit current bookmark to GitHub
alias jsubmit='jst submit'

# Fetch and rebase onto main
alias jrebase-main='jj git fetch && jj rebase -d main'

# Fetch and rebase onto origin/main
alias jrebase-origin='jj git fetch && jj rebase -d origin/main'

# Show the current stack
alias jstack='jj log -r ::@'

# Show all my bookmarks (not remote)
alias jmyb='jj log -r "bookmarks() & ~remote_bookmarks()"'

# ============================================================================
# Helper Functions
# ============================================================================

# Create a new change with bookmark
jnew() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: jnew <bookmark-name> [description]"
    echo "Example: jnew feature-x 'Add feature X'"
    return 1
  fi

  local bookmark_name="$1"
  shift
  local description="$*"

  if [[ -z "$description" ]]; then
    description="$bookmark_name"
  fi

  jj new -m "$description"
  jj bookmark create "$bookmark_name" -r @
  echo "Created bookmark: $bookmark_name"
}

# Submit all bookmarks in current stack
jsubmit-stack() {
  local bookmarks=$(jj bookmark list | grep -v 'main\|master\|trunk' | awk '{print $1}' | tr '\n' ' ')
  if [[ -z "$bookmarks" ]]; then
    echo "No bookmarks found to submit"
    return 1
  fi

  echo "Submitting bookmarks: $bookmarks"
  jst submit $bookmarks
}

# Clean up merged bookmarks
jclean-merged() {
  echo "Fetching latest changes..."
  jj git fetch

  echo "Rebasing onto main..."
  jj rebase -d main 2>/dev/null || jj rebase -d origin/main

  echo "Cleaned up merged bookmarks"
}

# Create stacked change on current bookmark
jstack-on() {
  local current_bookmark=$(jj bookmark list | grep '@' | awk '{print $1}')

  if [[ -z "$current_bookmark" ]]; then
    echo "No current bookmark found. Creating from main."
    current_bookmark="main"
  fi

  if [[ $# -eq 0 ]]; then
    echo "Usage: jstack-on <new-bookmark-name> [description]"
    echo "Will stack on: $current_bookmark"
    return 1
  fi

  local new_bookmark="$1"
  shift
  local description="$*"

  if [[ -z "$description" ]]; then
    description="$new_bookmark"
  fi

  jj new -m "$description"
  jj bookmark create "$new_bookmark" -r @
  echo "Created $new_bookmark stacked on $current_bookmark"
}

# Quick status with stack visualization
jss() {
  echo "=== Status ==="
  jj status
  echo ""
  echo "=== Current Stack ==="
  jj log -r ::@ --limit 10
}
# Alias for the above (since js conflicts with jj status)
alias jstat='jss'

# Initialize jj in a git repo
jinit() {
  if [[ -d .git ]]; then
    echo "Initializing jj in existing git repo (colocated mode)..."
    jj git init --colocate
  else
    echo "Initializing new jj repo..."
    jj git init
  fi

  echo ""
  echo "jj initialized! Next steps:"
  echo "1. Configure git remotes if needed"
  echo "2. Run: jj git fetch"
  echo "3. Start creating changes with: jnew <bookmark-name>"
}

# Show help for jj-stack workflow
jhelp() {
  cat << 'EOF'
Jujutsu + jj-stack Quick Reference
==================================

Basic Workflow:
  jnew feature-x "Add feature"     Create new change with bookmark
  js                               Show status
  jstack                          Show current stack
  jst submit feature-x            Submit PR to GitHub

Stacked Changes:
  jnew feature-a "First"          Create first change
  jstack-on feature-b "Second"    Stack second on current
  jsubmit-stack                   Submit entire stack

After PR Merge:
  jclean-merged                   Fetch, rebase, clean up
  jsubmit-stack                   Re-submit remaining PRs

Making Changes:
  je <revision>                   Edit specific revision
  jdesc -m "new description"      Update description
  jgpc                           Push current change

Bookmarks:
  jbl                            List all bookmarks
  jmyb                           List your bookmarks only
  jbc name -r @                  Create bookmark at current
  jbd name                       Delete bookmark

Authentication:
  gh auth login                  Authenticate GitHub CLI
  jst auth test                  Test jj-stack auth

More info:
  See: ~/.config/my_config/scripts/JJ_STACK_WORKFLOW.md
EOF
}

# ============================================================================
# Advanced Aliases (Optional)
# ============================================================================

# Interactive rebase using lazyjj
alias jlazy='lazyjj'

# Show diff with difftastic
alias jdiff='jj diff'

# Show log with graph
alias jlog='jj log --limit 20'

# Squash current change into parent
alias jsquash='jj squash'

# Split current change
alias jsplit='jj split'
