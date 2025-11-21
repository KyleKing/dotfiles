#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
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
