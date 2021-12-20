#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320

# Source: https://github.com/jesseduffield/lazygit#changing-directory-on-exit
lzgcd() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

    lazygit "$@"

    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
            cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
            rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}
alias lzg='lazygit'

export PR_CHECKOUT_DIR=~/developer/checkouts
if [[ -d $PR_CHECKOUT_DIR ]] {
    alias clone-pr() {
        mkcd $PR_CHECKOUT_DIR && gh repo clone $1 $1/pr$2 && cd $1/pr$2 && gh pr checkout $2 --force
    }
}
# clone-pr timothycrosley/pdocs 25
# clone-pr dash_charts 25
