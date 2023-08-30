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

# Source: https://github.com/jesseduffield/lazygit#changing-directory-on-exit
lzgcd() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

    lazygit "$@"

    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
        cd "$(cat $LAZYGIT_NEW_DIR_FILE)" || return
        rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
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
    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    watch_gha_runs --wait-for-start
}

# stern CLI helper
sternly() {
    # Usage: 'sternly' or 'sternly --include="error"'
    NA="null"

    pods=("chat-.*" "reviewer-.*" "boots-.*" "fluentd-sumologic-.*")
    # shellcheck disable=SC2128
    pod=$(gum choose $pods) || return 1
    echo "selected pod: $pod"

    containers=("$NA" "nginx" "chat-server" "celery-worker" "python-api" "boots-api")
    # shellcheck disable=SC2128
    container=$(gum choose $containers) || return 1
    if [[ "$container" == "$NA" ]]; then
        container=""
    else
        container="--container=$container"
    fi
    echo "selected container: $container"

    since_arg="--since=$(gum choose '5m' '30m' '90m' '1440m' --selected='30m')" || return 1
    echo "selected since: $since_arg"

    # Note: all inner spaces must be escaped
    excludes=("/readyz" "/metrics" "/healthz" "/livez" "GET\ /\ HTTP/1.1" "DarkMagic" "Health\ check")
    selected_excludes=$(printf "--selected=%s " "${excludes[@]}")
    # shellcheck disable=SC2128
    chosen_excludes=$(eval "gum choose $excludes --no-limit $selected_excludes") || return 1
    exclude_args=""
    if [[ -n "$chosen_excludes" ]]; then
        exclude_args=$(echo $chosen_excludes | xargs -I_ echo "--exclude=_" | tr '\n' ' ')
    fi
    echo "selected exclude: $exclude_args"

    echo "\nRunning: "
    echo "stern $pod $container $since_arg $exclude_args ${*} --output=raw | tail-jsonl"
    # shellcheck disable=SC2068
    stern $pod $container $since_arg $exclude_args ${@} --output=raw | tail-jsonl || return 1
}

# gh workflow CLI helpers
function find_workflow_name {
    local basenames=("$@")

    local workflow_dir=""
    workflow_dir="$(git rev-parse --show-toplevel)/.github/workflows"
    local checked=""
    for basename in "${basenames[@]}"; do
        for suffix in ".yaml" ".yml"; do
            local workflow_path="$workflow_dir/$basename$suffix"
            if [[ -e "$workflow_path" ]]; then
                echo "$basename$suffix"
                return 0
            fi
            checked="$checked\n$workflow_path"
        done
    done

    echo "No matching workflows were found:$checked" >&2
    return 1
}

deploy-list() {
    # Usage: 'deploy-list'
    workflow_name=$(find_workflow_name "deploy-application" "terraform-apply")

    echo "Running: gh run list --workflow=$workflow_name"
    gh run list --workflow=$workflow_name || return 1
}

deploy-branch() {
    # Usage: 'deploy-branch'
    environs=("dev" "stage" "prod")
    # shellcheck disable=SC2128
    aws_env=$(gum choose $environs) || return 1

    workflow_name=$(find_workflow_name "deploy-application" "terraform-apply")

    echo "Running: gh workflow run $workflow_name -f=\"aws-env=$aws_env\" --ref=\$(git rev-parse --abbrev-ref HEAD)"
    gh workflow run $workflow_name -f="aws-env=$aws_env" --ref="$(git rev-parse --abbrev-ref HEAD)" || return 1
}
