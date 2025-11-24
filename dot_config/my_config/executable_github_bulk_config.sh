#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Apply configurations to multiple GitHub repositories

bulk_enable_auto_delete() {
    echo "🔄 Enabling auto-delete branches for all repositories..."
    echo ""

    local success=0
    local failed=0

    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
        echo "  Processing: $repo"
        if gh repo edit "$repo" --delete-branch-on-merge 2>/dev/null; then
            echo "    ✅"
            ((success++))
        else
            echo "    ❌ Failed"
            ((failed++))
        fi
    done

    echo ""
    echo "✅ Bulk update complete"
    echo "   Success: $success"
    echo "   Failed: $failed"
}

bulk_apply_standard() {
    echo "🔄 Applying standard configuration to all repositories..."
    echo ""

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

    echo ""
    echo "✅ Bulk configuration complete"
}

# Filter repos by pattern
bulk_apply_to_pattern() {
    local pattern=$1
    echo "🔄 Applying configuration to repositories matching: $pattern"
    echo ""

    gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' | grep "$pattern" | while read -r repo; do
        echo "  Processing: $repo"
        if gh repo edit "$repo" --delete-branch-on-merge 2>/dev/null; then
            echo "    ✅"
        else
            echo "    ❌ Failed"
        fi
    done

    echo ""
    echo "✅ Pattern-based configuration complete"
}

# Interactive selection
bulk_apply_interactive() {
    echo "📋 Select repositories to configure:"
    echo ""

    # Get list of repos
    repos=$(gh repo list --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')

    # Use fzf for selection if available
    if command -v fzf &> /dev/null; then
        selected=$(echo "$repos" | fzf --multi --prompt="Select repos (Tab to select multiple): ")

        if [[ -n "$selected" ]]; then
            echo ""
            echo "Configuring selected repositories..."
            echo ""
            echo "$selected" | while read -r repo; do
                echo "  Configuring: $repo"
                gh repo edit "$repo" --delete-branch-on-merge
                gh repo edit "$repo" \
                    --enable-squash-merge \
                    --enable-merge-commit \
                    --disable-rebase-merge
                echo "    ✅"
            done
            echo ""
            echo "✅ Interactive configuration complete"
        else
            echo "No repositories selected"
        fi
    else
        echo "⚠️  fzf not installed. Install with: brew install fzf"
        echo ""
        echo "Available repositories:"
        echo "$repos"
    fi
}

# Show summary of all repos
bulk_summary() {
    echo "📊 Repository Configuration Summary"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    local total=0
    local auto_delete_enabled=0
    local squash_enabled=0

    gh repo list --limit 1000 --json nameWithOwner,deleteBranchOnMerge,allowSquashMerge -q '.[] | [.nameWithOwner,.deleteBranchOnMerge,.allowSquashMerge] | @tsv' | \
    while IFS=$'\t' read -r name delete_branch squash; do
        ((total++))
        [[ "$delete_branch" == "true" ]] && ((auto_delete_enabled++))
        [[ "$squash" == "true" ]] && ((squash_enabled++))
    done

    echo "Total repositories: $total"
    echo "Auto-delete enabled: $auto_delete_enabled"
    echo "Squash merge enabled: $squash_enabled"
    echo ""
    echo "═══════════════════════════════════════════════════════"
}

# Usage examples:
# bulk_enable_auto_delete
# bulk_apply_standard
# bulk_apply_to_pattern "dotfiles"
# bulk_apply_interactive
# bulk_summary

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
        --summary)
            bulk_summary
            ;;
        *)
            echo "Usage: $0 [--auto-delete|--standard|--pattern PATTERN|--interactive|--summary]"
            echo ""
            echo "Options:"
            echo "  --auto-delete    Enable auto-delete branches on all repos"
            echo "  --standard       Apply standard configuration to all repos"
            echo "  --pattern TEXT   Apply configuration to repos matching pattern"
            echo "  --interactive    Use fzf to select repos interactively"
            echo "  --summary        Show summary of current configurations"
            exit 1
            ;;
    esac
fi
