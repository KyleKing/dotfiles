#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
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
