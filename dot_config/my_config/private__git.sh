#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320

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

# Get current PR number
alias whichpr='gh pr view --json "number" | jq ".number"'

local-pr-diff() {
    # Use with: "local-pr-diff" when in a PR checkout directory
    # Fallback, should support main, but less common
    up_branch=master
    dir_name=__only_for_dot_git
    # Get the upstream branch .git directory
    echo "Starting 'local-pr-diff'"
    mkdir -p $dir_name
    mv .git $dir_name
    cd $dir_name || exit
    git reset --hard HEAD
    git checkout origin/$up_branch
    mv .git ../.git
    cd ..
    rm -rf $dir_name
    echo "Completed 'local-pr-diff'"
}

export PR_CHECKOUT_DIR=~/developer/checkouts
clone-pr() {
    # Use with: "clone-pr timothycrosley/pdocs 25" or "clone-pr dash_charts 25"
    repo=$1
    pr_num=$2
    mkcd $PR_CHECKOUT_DIR
    gh repo clone $repo $repo-pr$pr_num
    cd $repo-pr$pr_num || return
    gprc $pr_num --force
    local-pr-diff || exit
    subl . --new-window
    z .

    # FIXME: Make setup of pyright in a new repo easier. This file is specific to reviewer-api
    cp ~/.config/my_config/pyrightconfig.json pyrightconfig.json
}

# TODO: need script to walk the PR_CHECKOUT_DIR for git directories, check if the branch was merged, then delete the folder
# FYI: Make sure to check for a "git stash" and error on any that have one
# FYI: Also check that there are no other branches
# These aliases could possibly be a gh plugin? Could fork "gh poi" or "gh tidy"?
alias prune-clones="echo 'WIP'"
