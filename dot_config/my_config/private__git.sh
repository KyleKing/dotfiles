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


export PR_CHECKOUT_DIR=~/developer/checkouts
clone-pr() {
    # Use with: "clone-pr timothycrosley/pdocs 25" or "clone-pr dash_charts 25"
    mkcd $PR_CHECKOUT_DIR
    gh repo clone $1 $1-pr$2
    cd $1-pr$2 || return
    gh pr checkout $2 --force
    subl . --new-window
    z .

    # FIXME: Make setup of pyright in a new repo easier. This file is specific to reviewer-api
    cp ~/.config/my_config/pyrightconfig.json pyrightconfig.json
}

# FIXME: Create new project file per project with path to the .venv Python
# Then open with subl using the "--project" arg
# // https://www.sublimetext.com/docs/projects.html
# // https://www.sublimelinter.com/en/stable/settings.html#project-settings
# // Check "show_hover_line_report" and "show_hover_region_report"
# {
#     "folders": [{"path": "/Users/kyleking/Developer/recipes"}],,
#     "settings": {
#         "SublimeLinter.linters.flake8.args": [
#             "--max-line-length=88",
#             "--ignore=B902,D100,D103,D205,D209,D400,D401,D403,E203,E501,E722,W503",
#             "--select=A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
#         ],
#         "SublimeLinter.linters.flake8.python": "$project_path/.env/bin/python",
#         "SublimeLinter.linters.pylint.args": [
#             "--disable=E0012,E0401,W0613,C0115,C0116,W1203",
#             "--rcfile=./reviewer-api/.pylintrc"
#         ],
#         "SublimeLinter.linters.pylint.python": "$project_path/.env/bin/python"
#     }
# }

# TODO: need script to walk the PR_CHECKOUT_DIR for git directories, check if the branch was merged, then delete the folder
# FYI: Make sure to check for a "git stash" and error on any that have one
# These aliases could possibly be a gh plugin? Could fork "gh poi" or "gh tidy"?
alias prune-clones="echo 'WIP'"
