
# # FYI: Causes unexpected behaviour when changing the top-level directory while working in a sub-directory
# # Source: https://github.com/jesseduffield/lazygit#changing-directory-on-exit
# lzg() {
#     export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

#     lazygit "$@"

#     if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
#             cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
#             rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
#     fi
# }
alias lzg='lazygit'

export PR_CHECKOUT_DIR=~/developer/checkouts
if [[ -d $PR_CHECKOUT_DIR ]] {
    alias clone-pr() {
        cd $PR_CHECKOUT_DIR && gh repo clone $1 $1/pr$2 && cd $1/pr$2 && gh pr checkout $2 --force
    }
}
# clone-pr timothycrosley/pdocs 25
# clone-pr dash_charts 25
