# GitHub Personal Account Configuration Management

**Purpose**: Document how to manage GitHub repository configurations consistently across personal projects, including branch protections, auto-delete settings, and other repository defaults.

**Last Updated**: 2025-11-21

---

## Table of Contents

- [Overview](#overview)
- [Repository Settings](#repository-settings)
- [Branch Protection Rules](#branch-protection-rules)
- [Automation Scripts](#automation-scripts)
- [GitHub CLI Configuration](#github-cli-configuration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

Managing multiple GitHub repositories with consistent settings is challenging. This guide provides:

1. **Standard configurations** for personal repositories
2. **Automation scripts** using GitHub CLI (`gh`)
3. **Best practices** for repository management
4. **Troubleshooting** common issues

### Why This Matters

- ✅ **Consistency**: All repos follow same standards
- ✅ **Automation**: Reduce manual configuration
- ✅ **Best Practices**: Security and workflow improvements
- ✅ **Documentation**: Track configuration decisions

---

## Repository Settings

### Core Settings to Configure

#### 1. Automatically Delete Head Branches

**Setting**: Delete branch after PR merge

**Why**: Keeps repository clean, prevents stale branches

**How to Enable**:

```bash
# Using GitHub CLI
gh repo edit OWNER/REPO --delete-branch-on-merge

# Enable for current repository
gh repo edit --delete-branch-on-merge

# Enable for multiple repos
for repo in repo1 repo2 repo3; do
    gh repo edit "$repo" --delete-branch-on-merge
done
```

**Via Web UI**:
1. Go to repository settings
2. Scroll to "Pull Requests"
3. Check "Automatically delete head branches"

#### 2. Default Branch Settings

**Setting**: Use `main` as default branch

**Why**: Industry standard, clear naming

**How to Configure**:

```bash
# Set default branch
gh repo edit OWNER/REPO --default-branch main

# Rename existing master to main
git branch -m master main
git push -u origin main
gh repo edit --default-branch main
git push origin --delete master
```

#### 3. Allow Merge Types

**Settings**: Control how PRs can be merged

**Options**:
- **Merge commits**: Keep full history (recommended for personal projects)
- **Squash merging**: Clean history, single commit per PR
- **Rebase merging**: Linear history, preserves individual commits

**How to Configure**:

```bash
# Enable all merge types
gh repo edit OWNER/REPO --enable-merge-commit --enable-squash-merge --enable-rebase-merge

# Enable only squash merging
gh repo edit OWNER/REPO --enable-squash-merge --disable-merge-commit --disable-rebase-merge
```

**Recommendation for Personal Projects**:
- Enable squash merging (clean history)
- Enable merge commits (preserve context when needed)
- Disable rebase merging (less commonly used)

#### 4. Issue and PR Templates

**Setting**: Standardize issue/PR creation

**How to Configure**:

```bash
# Create templates directory
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p .github/PULL_REQUEST_TEMPLATE

# Create issue template
cat > .github/ISSUE_TEMPLATE/bug_report.md <<'EOF'
---
name: Bug Report
about: Report a bug
---

## Description
<!-- Clear description of the bug -->

## Steps to Reproduce
1.
2.
3.

## Expected Behavior
<!-- What should happen -->

## Actual Behavior
<!-- What actually happens -->

## Environment
- OS:
- Version:
EOF

# Create PR template
cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## Changes
<!-- Describe your changes -->

## Related Issues
<!-- Link related issues: Closes #123 -->

## Testing
<!-- How was this tested? -->

## Checklist
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No breaking changes
EOF
```

#### 5. Visibility Settings

**Settings**: Public vs Private repositories

**How to Configure**:

```bash
# Make repository private
gh repo edit OWNER/REPO --visibility private

# Make repository public
gh repo edit OWNER/REPO --visibility public
```

---

## Branch Protection Rules

### Why Branch Protection?

- 🛡️ **Prevent force pushes**: Protect history
- 🛡️ **Require reviews**: Catch issues before merge
- 🛡️ **Require status checks**: Ensure CI passes
- 🛡️ **Prevent direct commits**: All changes via PR

### Standard Protection Rules

#### 1. Basic Protection (Personal Projects)

**Recommended for small personal projects**:

```bash
# Enable basic protection on main branch
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field required_status_checks='null' \
    --field enforce_admins=false \
    --field required_pull_request_reviews='null' \
    --field restrictions='null' \
    --field required_linear_history=true \
    --field allow_force_pushes=false \
    --field allow_deletions=false
```

**What this does**:
- ✅ Requires linear history (no merge commits on main)
- ✅ Prevents force pushes
- ✅ Prevents branch deletion
- ❌ Does NOT require PR reviews (you're the only contributor)
- ❌ Does NOT require status checks (flexible for small projects)

#### 2. Enhanced Protection (Collaborative Projects)

**Recommended when working with others or for critical projects**:

```bash
# Enable enhanced protection
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field required_status_checks[strict]=true \
    --field required_status_checks[contexts][]='ci/test' \
    --field enforce_admins=true \
    --field required_pull_request_reviews[required_approving_review_count]=1 \
    --field required_pull_request_reviews[dismiss_stale_reviews]=true \
    --field restrictions='null' \
    --field required_linear_history=true \
    --field allow_force_pushes=false \
    --field allow_deletions=false
```

**What this does**:
- ✅ Requires CI tests to pass
- ✅ Requires at least 1 PR review
- ✅ Dismisses stale reviews on new commits
- ✅ Applies rules to admins too
- ✅ Requires linear history
- ✅ Prevents force pushes and deletions

#### 3. Minimal Protection (Archive/Experimental)

**For archived or experimental repos**:

```bash
# Minimal protection - just prevent force push
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field required_status_checks='null' \
    --field enforce_admins=false \
    --field required_pull_request_reviews='null' \
    --field restrictions='null' \
    --field allow_force_pushes=false \
    --field allow_deletions=true
```

### Protection Rule Components

#### Required Status Checks

**Purpose**: Ensure CI/tests pass before merge

```bash
# Require specific checks
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field required_status_checks[strict]=true \
    --field required_status_checks[contexts][]='ci/test' \
    --field required_status_checks[contexts][]='ci/lint' \
    --field required_status_checks[contexts][]='ci/build'
```

**Common check names**:
- GitHub Actions: `test`, `lint`, `build`
- CircleCI: `ci/circleci: test`
- Travis CI: `continuous-integration/travis-ci/pr`

#### Required Reviews

**Purpose**: Require peer review before merge

```bash
# Require 1 review, dismiss stale reviews
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field required_pull_request_reviews[required_approving_review_count]=1 \
    --field required_pull_request_reviews[dismiss_stale_reviews]=true \
    --field required_pull_request_reviews[require_code_owner_reviews]=false
```

**Options**:
- `required_approving_review_count`: Number of approvals (1-6)
- `dismiss_stale_reviews`: Dismiss reviews when new commits pushed
- `require_code_owner_reviews`: Require review from CODEOWNERS

#### Enforce for Administrators

**Purpose**: Apply rules to repo admins too

```bash
# Enforce for admins (recommended for teams)
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field enforce_admins=true

# Don't enforce for admins (personal projects)
gh api repos/OWNER/REPO/branches/main/protection \
    --method PUT \
    --field enforce_admins=false
```

**Recommendation**:
- Personal projects: `false` (flexibility for solo work)
- Team projects: `true` (lead by example)

---

## Automation Scripts

### Script 1: Apply Standard Configuration

Create `~/.config/my_config/github_config_repo.sh`:

```bash
#!/bin/bash -e
# Apply standard GitHub repository configuration

apply_standard_config() {
    local repo=$1
    echo "📦 Configuring repository: $repo"

    # Basic settings
    echo "  ⚙️  Enabling auto-delete branches..."
    gh repo edit "$repo" --delete-branch-on-merge

    echo "  ⚙️  Setting merge options..."
    gh repo edit "$repo" \
        --enable-squash-merge \
        --enable-merge-commit \
        --disable-rebase-merge

    echo "  ⚙️  Enabling issues and wiki..."
    gh repo edit "$repo" \
        --enable-issues \
        --enable-wiki

    # Branch protection (basic)
    echo "  🛡️  Applying basic branch protection..."
    gh api "repos/$repo/branches/main/protection" \
        --method PUT \
        --silent \
        --field required_status_checks='null' \
        --field enforce_admins=false \
        --field required_pull_request_reviews='null' \
        --field restrictions='null' \
        --field required_linear_history=false \
        --field allow_force_pushes=false \
        --field allow_deletions=false \
        2>/dev/null || echo "  ⚠️  Could not apply branch protection (may require admin)"

    echo "  ✅ Configuration complete for $repo"
}

# Usage examples:
# apply_standard_config "username/repo-name"
# apply_standard_config "$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Apply to current repository
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "$1" ]]; then
        # Get current repo if in git directory
        if git rev-parse --git-dir > /dev/null 2>&1; then
            current_repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
            apply_standard_config "$current_repo"
        else
            echo "Usage: $0 OWNER/REPO"
            echo "Or run from within a git repository"
            exit 1
        fi
    else
        apply_standard_config "$1"
    fi
fi
```

### Script 2: Audit Repository Configuration

Create `~/.config/my_config/github_audit_repos.sh`:

```bash
#!/bin/bash -e
# Audit GitHub repository configurations

audit_repo() {
    local repo=$1
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Auditing: $repo"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get repository info
    repo_info=$(gh api "repos/$repo")

    # Basic settings
    echo "🔧 Basic Settings:"
    echo "  Default branch: $(echo "$repo_info" | jq -r .default_branch)"
    echo "  Auto-delete branches: $(echo "$repo_info" | jq -r .delete_branch_on_merge)"
    echo "  Allow squash merge: $(echo "$repo_info" | jq -r .allow_squash_merge)"
    echo "  Allow merge commit: $(echo "$repo_info" | jq -r .allow_merge_commit)"
    echo "  Allow rebase merge: $(echo "$repo_info" | jq -r .allow_rebase_merge)"
    echo "  Visibility: $(echo "$repo_info" | jq -r .visibility)"

    # Branch protection
    echo ""
    echo "🛡️  Branch Protection (main):"
    protection=$(gh api "repos/$repo/branches/main/protection" 2>/dev/null || echo '{"message":"Not protected"}')

    if echo "$protection" | jq -e .message >/dev/null 2>&1; then
        echo "  ⚠️  No branch protection enabled"
    else
        echo "  ✅ Protection enabled"
        echo "  Require reviews: $(echo "$protection" | jq -r .required_pull_request_reviews.required_approving_review_count // 0)"
        echo "  Enforce for admins: $(echo "$protection" | jq -r .enforce_admins.enabled)"
        echo "  Linear history: $(echo "$protection" | jq -r .required_linear_history.enabled)"
        echo "  Allow force push: $(echo "$protection" | jq -r .allow_force_pushes.enabled)"
    fi

    echo ""
}

audit_all_repos() {
    echo "═══════════════════════════════════════════════════════"
    echo "  GitHub Repository Configuration Audit"
    echo "  Generated: $(date)"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Get all repos for authenticated user
    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
        audit_repo "$repo"
    done

    echo "═══════════════════════════════════════════════════════"
    echo "Audit Complete"
    echo "═══════════════════════════════════════════════════════"
}

# Usage:
# audit_repo "username/repo-name"
# audit_all_repos

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--all" ]]; then
        audit_all_repos
    elif [[ -n "$1" ]]; then
        audit_repo "$1"
    else
        echo "Usage: $0 OWNER/REPO"
        echo "       $0 --all"
        exit 1
    fi
fi
```

### Script 3: Bulk Configuration Update

Create `~/.config/my_config/github_bulk_config.sh`:

```bash
#!/bin/bash -e
# Apply configurations to multiple repositories

bulk_enable_auto_delete() {
    echo "🔄 Enabling auto-delete branches for all repositories..."

    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
        echo "  Processing: $repo"
        gh repo edit "$repo" --delete-branch-on-merge 2>/dev/null && echo "    ✅" || echo "    ❌ Failed"
    done

    echo "✅ Bulk update complete"
}

bulk_apply_standard() {
    echo "🔄 Applying standard configuration to all repositories..."

    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
        echo "  Processing: $repo"

        # Auto-delete branches
        gh repo edit "$repo" --delete-branch-on-merge 2>/dev/null || true

        # Merge options
        gh repo edit "$repo" \
            --enable-squash-merge \
            --enable-merge-commit \
            --disable-rebase-merge 2>/dev/null || true

        echo "    ✅"
    done

    echo "✅ Bulk configuration complete"
}

# Filter repos by pattern
bulk_apply_to_pattern() {
    local pattern=$1
    echo "🔄 Applying configuration to repositories matching: $pattern"

    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | grep "$pattern" | while read -r repo; do
        echo "  Processing: $repo"
        gh repo edit "$repo" --delete-branch-on-merge 2>/dev/null && echo "    ✅" || echo "    ❌"
    done
}

# Interactive selection
bulk_apply_interactive() {
    echo "📋 Select repositories to configure:"

    # Get list of repos
    repos=$(gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')

    # Use fzf for selection if available
    if command -v fzf &> /dev/null; then
        selected=$(echo "$repos" | fzf --multi --prompt="Select repos (Tab to select multiple): ")

        if [[ -n "$selected" ]]; then
            echo "$selected" | while read -r repo; do
                echo "  Configuring: $repo"
                gh repo edit "$repo" --delete-branch-on-merge
            done
        fi
    else
        echo "⚠️  fzf not installed. Install with: brew install fzf"
        echo ""
        echo "Available repositories:"
        echo "$repos"
    fi
}

# Usage examples:
# bulk_enable_auto_delete
# bulk_apply_standard
# bulk_apply_to_pattern "dotfiles"
# bulk_apply_interactive

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        --auto-delete)
            bulk_enable_auto_delete
            ;;
        --standard)
            bulk_apply_standard
            ;;
        --pattern)
            if [[ -z "$2" ]]; then
                echo "Usage: $0 --pattern PATTERN"
                exit 1
            fi
            bulk_apply_to_pattern "$2"
            ;;
        --interactive)
            bulk_apply_interactive
            ;;
        *)
            echo "Usage: $0 [--auto-delete|--standard|--pattern PATTERN|--interactive]"
            exit 1
            ;;
    esac
fi
```

---

## GitHub CLI Configuration

### gh Configuration File

Location: `~/.config/gh/config.yml`

**Example configuration**:

```yaml
# Default git protocol
git_protocol: ssh

# Default editor
editor: nvim

# Default prompt behavior
prompt: enabled

# Aliases for common operations
aliases:
    co: pr checkout
    pv: pr view
    rv: repo view

    # Apply standard config to current repo
    config-repo: |
        !gh repo edit --delete-branch-on-merge \
            --enable-squash-merge --enable-merge-commit --disable-rebase-merge

    # Audit current repo
    audit-repo: |
        !bash ~/.config/my_config/github_audit_repos.sh "$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# Default repo viewer in browser
browser: brave
```

### Useful gh Aliases

Add to `~/.config/my_config/private__git.sh`:

```bash
# GitHub repository configuration aliases
alias gh-config='bash ~/.config/my_config/github_config_repo.sh'
alias gh-audit='bash ~/.config/my_config/github_audit_repos.sh'
alias gh-bulk='bash ~/.config/my_config/github_bulk_config.sh'

# Quick audit current repo
gh-audit-here() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    bash ~/.config/my_config/github_audit_repos.sh "$repo"
}

# Quick config current repo
gh-config-here() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    bash ~/.config/my_config/github_config_repo.sh "$repo"
}
```

---

## Best Practices

### 1. Repository Organization

**Recommended structure**:

```
Personal Repos
├── Active Development
│   ├── Enable branch protection
│   ├── Auto-delete branches: ✅
│   ├── Require squash merge: ✅
│   └── CI/CD required: ✅
├── Maintenance Mode
│   ├── Basic branch protection
│   ├── Auto-delete branches: ✅
│   └── CI/CD optional: ⚠️
└── Archived
    ├── Minimal protection
    └── Auto-delete branches: ⚠️ (depends)
```

### 2. Configuration Workflow

**Initial Setup** (New Repository):

```bash
# 1. Create repository
gh repo create my-new-project --public

# 2. Apply standard configuration
gh-config-here

# 3. Add templates
cp -r ~/.github-templates/.github .

# 4. Commit and push
git add .github
git commit -m "chore: add GitHub templates"
git push
```

**Periodic Audit** (Quarterly):

```bash
# 1. Run full audit
gh-audit --all > ~/Downloads/github-audit-$(date +%Y-%m).txt

# 2. Review output
less ~/Downloads/github-audit-$(date +%Y-%m).txt

# 3. Fix inconsistencies
gh-bulk --interactive
```

### 3. Naming Conventions

**Repository names**:
- Use kebab-case: `my-project-name`
- Be descriptive: `python-data-processor` not `pdp`
- Include language/tech: `django-blog`, `react-dashboard`

**Branch names**:
- Feature: `feature/add-user-auth`
- Bug fix: `fix/login-error`
- Chore: `chore/update-deps`
- Documentation: `docs/api-guide`

**Commit messages**:
- Follow conventional commits: `type(scope): message`
- Types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`
- Example: `feat(auth): add OAuth2 support`

### 4. Security Practices

**Repository Settings**:
- ✅ Enable Dependabot alerts
- ✅ Enable Dependabot security updates
- ✅ Enable secret scanning
- ✅ Use branch protection on main
- ✅ Require signed commits (optional)

**Access Control**:
- Review collaborator access quarterly
- Use teams for organization repos
- Minimize admin access

---

## Troubleshooting

### Common Issues

#### Issue: "Resource not accessible by integration"

**Problem**: GitHub CLI can't modify repository settings

**Solutions**:

```bash
# 1. Re-authenticate with full permissions
gh auth login --scopes repo,admin:repo_hook,workflow

# 2. Check authentication status
gh auth status

# 3. Verify repo ownership
gh repo view --json owner -q .owner.login
```

#### Issue: Branch protection API returns 404

**Problem**: Branch doesn't exist yet

**Solution**:

```bash
# Create branch first
git checkout -b main
git push -u origin main

# Then apply protection
gh api repos/OWNER/REPO/branches/main/protection --method PUT ...
```

#### Issue: "Required status checks" not working

**Problem**: Status check names don't match

**Solutions**:

```bash
# 1. List recent status checks
gh api repos/OWNER/REPO/commits/main/status | jq -r '.statuses[].context'

# 2. View check runs
gh api repos/OWNER/REPO/commits/main/check-runs | jq -r '.check_runs[].name'

# 3. Use exact names in protection rules
```

#### Issue: Can't enable auto-delete on fork

**Problem**: Forked repositories have limited settings

**Solution**:
- Forks inherit some settings from parent
- Some settings require repository ownership
- Consider creating a template instead of forking

### Verification Commands

```bash
# Check current repository settings
gh repo view --json name,owner,deleteBranchOnMerge,defaultBranchRef

# Check branch protection
gh api repos/OWNER/REPO/branches/main/protection | jq

# List all repositories with settings
gh repo list --json name,deleteBranchOnMerge,defaultBranchRef --limit 1000 | jq

# Check authentication and permissions
gh auth status -h github.com
```

---

## Additional Resources

### Official Documentation

- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub API - Repos](https://docs.github.com/en/rest/repos/repos)
- [Conventional Commits](https://www.conventionalcommits.org/)

### Tools

- **gh** (GitHub CLI): `brew install gh`
- **jq** (JSON processor): Already installed
- **fzf** (Fuzzy finder): Already installed

### Related Scripts

- `~/.config/my_config/github_config_repo.sh` - Apply standard config
- `~/.config/my_config/github_audit_repos.sh` - Audit configurations
- `~/.config/my_config/github_bulk_config.sh` - Bulk operations

---

## Change Log

### 2025-11-21
- Initial documentation created
- Added automation scripts
- Added best practices and troubleshooting

---

## Notes

**Personal Account Limitations**:
- No organization-level settings
- No SAML/SSO
- No team management
- Limited to individual repositories

**Workarounds**:
- Use consistent naming conventions
- Automate with scripts
- Regular audits
- Document standards (this file!)

**Future Improvements**:
- Add GitHub Actions workflow for configuration checks
- Create repository template with standard configs
- Add script to generate compliance reports
- Integrate with mise tasks for scheduled audits
