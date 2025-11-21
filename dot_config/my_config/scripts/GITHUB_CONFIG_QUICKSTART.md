# GitHub Configuration Management - Quick Start Guide

**5-Minute Setup Guide** for managing GitHub repository configurations consistently.

---

## Prerequisites

```bash
# Verify gh CLI is installed and authenticated
gh auth status

# If not authenticated:
gh auth login --scopes repo,admin:repo_hook,workflow
```

---

## Quick Commands

### 🔍 Audit Your Repositories

```bash
# Audit a specific repository
gh-audit-here  # From within the repo directory

# Or specify a repo
gh-audit username/repo-name

# Audit ALL your repositories
gh-audit --all > ~/Downloads/github-audit.txt
```

### ⚙️ Configure a Repository

```bash
# Apply standard config to current repo
gh-config-here  # From within the repo directory

# Or specify a repo
gh-config username/repo-name
```

### 🔄 Bulk Operations

```bash
# Show summary of all repos
gh-bulk --summary

# Enable auto-delete branches on all repos
gh-bulk --auto-delete

# Apply standard config to all repos
gh-bulk --standard

# Interactive selection (uses fzf)
gh-bulk --interactive

# Apply to repos matching pattern
gh-bulk --pattern "dotfiles"
```

---

## Standard Configuration

When you run `gh-config-here`, it applies:

✅ **Auto-delete head branches** after PR merge
✅ **Enable squash merge** (clean history)
✅ **Enable merge commits** (preserve context)
✅ **Disable rebase merge** (less commonly used)
✅ **Basic branch protection** on main (prevent force push)
✅ **Enable issues and wiki**

---

## Common Workflows

### New Repository Setup

```bash
# 1. Create repository
gh repo create my-new-project --public

# 2. Clone and navigate
git clone git@github.com:username/my-new-project.git
cd my-new-project

# 3. Apply standard config
gh-config-here

# 4. Verify
gh-audit-here
```

### Quarterly Audit

```bash
# 1. Run full audit (save to file)
gh-audit --all > ~/Downloads/github-audit-$(date +%Y-%m-%d).txt

# 2. Review the output
cat ~/Downloads/github-audit-$(date +%Y-%m-%d).txt | less

# 3. Fix any inconsistencies
gh-bulk --interactive
```

### Fix Specific Setting Across All Repos

```bash
# Enable auto-delete branches everywhere
gh-bulk --auto-delete

# Verify the change
gh-bulk --summary
```

---

## Troubleshooting

### "Resource not accessible by integration"

```bash
# Re-authenticate with full permissions
gh auth login --scopes repo,admin:repo_hook,workflow

# Verify scopes
gh auth status
```

### Scripts not found

```bash
# Reload shell configuration
source ~/.zshrc

# Or check if scripts exist
ls -la ~/.config/my_config/github_*.sh
```

### Branch protection fails

```bash
# Branch must exist first
git checkout -b main
git push -u origin main

# Then retry configuration
gh-config-here
```

---

## Key Aliases

```bash
gh-config-here    # Configure current repository
gh-audit-here     # Audit current repository
gh-audit          # Audit specified repo or --all
gh-bulk           # Bulk operations with options
```

---

## Next Steps

📖 **Full Documentation**: `~/.config/my_config/scripts/GITHUB_CONFIG_MANAGEMENT.md`

Contains:
- Detailed configuration options
- Branch protection rules explained
- Advanced automation scripts
- Best practices and security settings
- Troubleshooting guide

---

## Examples

### Example 1: Audit Current Project

```bash
$ cd ~/projects/my-app
$ gh-audit-here

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Auditing: username/my-app
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Basic Settings:
  Default branch: main
  Auto-delete branches: true
  Allow squash merge: true
  Allow merge commit: true
  Allow rebase merge: false
  Visibility: public

🛡️  Branch Protection (main):
  ✅ Protection enabled
  Require reviews: 0
  Enforce for admins: false
  Linear history: false
  Allow force push: false
```

### Example 2: Enable Auto-Delete on All Repos

```bash
$ gh-bulk --auto-delete

🔄 Enabling auto-delete branches for all repositories...

  Processing: username/repo1
    ✅
  Processing: username/repo2
    ✅
  Processing: username/repo3
    ✅

✅ Bulk update complete
```

### Example 3: Interactive Selection

```bash
$ gh-bulk --interactive

📋 Select repositories to configure:
# (fzf interface opens)
# Use arrow keys to navigate
# Press Tab to select multiple
# Press Enter to confirm

Configuring selected repositories...

  Configuring: username/selected-repo1
    ✅
  Configuring: username/selected-repo2
    ✅

✅ Interactive configuration complete
```

---

## Tips

💡 **Create a quarterly reminder** to run `gh-audit --all`

💡 **Use `gh-bulk --summary`** to track configuration consistency over time

💡 **Test on one repo first** before running bulk operations

💡 **Save audit reports** to track changes: `gh-audit --all > ~/audit-$(date +%Y-%m).txt`

---

## Help

```bash
# Show help for each script
gh-config --help
gh-audit --help
gh-bulk --help

# Read full documentation
cat ~/.config/my_config/scripts/GITHUB_CONFIG_MANAGEMENT.md | less
```

---

**Last Updated**: 2025-11-21
