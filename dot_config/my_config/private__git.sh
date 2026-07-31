#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Customize git

# Work with no-tty for gpg & pinentry (https://stackoverflow.com/a/42265848)
GPG_TTY=$(tty)
export GPG_TTY
# helper for debugging GPG issues and git. From: https://stackoverflow.com/a/41054093/3219667
alias test-gpg='echo "test" | gpg --clearsign'

# Set the upstream branch and push
# From: https://github.com/ornicar/dotfiles/blob/7f0940aa42b7c79771ad1fe31be21cd49827f161/zsh/git-functions.zsh#L35-L40
git-set-upstream() {
    # Use: "git-set-upstream"
    repo=$1
    [ -z "$repo" ] && repo=origin
    branch=$(git rev-parse --abbrev-ref HEAD)
    git push "$repo" "$branch" --set-upstream
}

alias lzg='lazygit'
# jj (jujitsu) git-compatible VCS (installed with mise)
alias lzj='lazyjj'

# Navigate to top-level git directory (from: https://github.com/kakulukia/dotfiles/blob/eb4fd73d876727a6325362b21fad45dc7bd18913/.alias#L25C1-L25C115)
alias ,,='git rev-parse --git-dir >/dev/null 2>&1 && cd `git rev-parse --show-toplevel` || echo "Not in git repo"'

# Checkout by number: "gprc 12"
alias gprc="gh pr checkout"
# Open PR in default browser
alias openpr="gh pr view --web"
# Get current PR number
alias whichpr='gh pr view --json "number" | jq ".number"'

# Prune closed PRs and branches
alias gpoi='gh poi && gf --prune origin'

# And squash from the CLI
squash-me() {
    gh pr merge "$(whichpr)" --body='' --squash && gco master && gpoi && gl
}

# Wait for CI, check reviews, then squash-merge and clean up.
#
# Usage: git push && gh pr ready && pr-merge-watch
#   Blocks the terminal until done; macOS notifications fire on success or any
#   blocking condition. After a successful merge, switches to main and prunes.
#
# Alternatives:
#   - Skip the watch entirely and queue a server-side auto-merge at push time:
#       gh pr merge --auto --squash
#     Requires "Allow auto-merge" enabled in repo Settings > General. Merges
#     when required checks + required approvals clear, but gives no local
#     notification and won't gate on optional/async reviewers.
#   - For one-off CI watching without merging: gh pr checks --watch --fail-fast
pr-merge-watch() {
    echo "Waiting for CI checks to appear..."
    local attempt=0 max_attempts=10 delay=3
    while ! gh pr checks --json state >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if ((attempt >= max_attempts)); then
            osascript -e 'display notification "No CI checks ever showed up" with title "PR Blocked" sound name "Basso"'
            return 1
        fi
        sleep "$delay"
        delay=$((delay * 2))
    done

    echo "Waiting for CI checks..."
    if ! gh pr checks --watch --fail-fast; then
        osascript -e 'display notification "CI failed — check before merging" with title "PR Blocked" sound name "Basso"'
        return 1
    fi

    # Async reviewer bots post their review shortly after CI completes but
    # aren't a required check, so they won't appear in `gh pr checks`. Wait
    # 60s to give them time to finish before inspecting reviews. Remove this
    # sleep if you don't rely on any async/optional reviewer bots.
    echo "CI passed. Waiting 60s for optional/async reviewers..."
    sleep 60

    local blockers
    blockers=$(gh pr view --json reviews,reviewRequests \
        --jq '
            (.reviews // [] | map(select(.state == "CHANGES_REQUESTED")) | length) as $cr |
            (.reviewRequests // [] | length) as $pending |
            if $cr > 0 then "changes-requested(\($cr))"
            elif $pending > 0 then "pending-reviews(\($pending))"
            else ""
            end
        ')

    if [[ -n "$blockers" ]]; then
        osascript -e "display notification \"Blocked: $blockers\" with title \"PR Not Merged\" sound name \"Basso\""
        gh pr view --web
        return 1
    fi

    if gh pr merge --squash; then
        osascript -e 'display notification "Squash-merged successfully" with title "PR Merged" sound name "Glass"'
        gco main && gpoi && gl --prune
    else
        # Most likely cause: someone merged to main after your last push.
        # Fix: git fetch origin && git rebase origin/main, then re-push and re-run.
        osascript -e 'display notification "Merge failed — likely a conflict, rebase and retry" with title "PR Blocked" sound name "Basso"'
        return 1
    fi
}

# Commit with no pre-commit
alias gcnv='git commit --no-verify --message'

# Add shorthand alias for watchgha/watch_gha_runs (https://github.com/nedbat/watchgha)
gh-runs() {
    echo "$PWD"
    cd "$(git rev-parse --show-toplevel)" || return 1

    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    watch_gha_runs --wait-for-start
}
