#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320

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
    [ -z $repo ] && repo=origin
    branch=$(git-current-branch)
    git push $repo $branch --set-upstream
}

alias lzg='lazygit'

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

# Commit with no pre-commit
alias gcnv='git commit --no-verify --message'

# Add aliases for interactive selection of the ref branch
alias pick-branch='echo $(gh pr list -L100 | fzf | cut -f3)'
alias gh-run-pick='gh workflow run --ref=$(gh pr list -L100 | fzf | cut -f3)'

# Add shorthand alias for watchgha/watch_gha_runs (https://github.com/nedbat/watchgha)
gh-runs() {
    echo "$PWD"
    cd "$(git rev-parse --show-toplevel)" || return 1

    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    watch_gha_runs --wait-for-start
}
