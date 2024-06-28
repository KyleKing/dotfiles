#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# Configure CLI Tools

# See local weather. Full docs: https://github.com/chubin/wttr.in
alias wttr="curl v2d.wttr.in"

# Support fzf for completion from https://github.com/cheat/cheat#autocompletion
#   Note that brew install the cheat.zsh script
export CHEAT_USE_FZF=true
# The cheat.zsh file isn't working as expected, so use this snippet instead
#   From: https://github.com/cheat/cheat/issues/594#issuecomment-1228307435
cheatz() {
    cheat -l | tail -n +2 | fzf | awk '{{ print $1 }}' | xargs -I {} cheat {}
}

# Alias common ripgrep (rg) searches
export RIPGREP_CONFIG_PATH=~/.config/ripgrep/.ripgreprc
# FYI: Add -A/-B/-C for context before/after the match
alias rgh='rg --hidden'
alias rgfs='rgh --fixed-strings --'
rgso() {
    _search=$1
    echo "Searching with: '$_search'"
    if [[ -z "$_search" ]]; then
        echo "The search strings must be specified. Expected: 'rgso ...'"
        return 1
    else
        paths=$(rgh --fixed-strings --files-with-matches -- "$_search")
        echo "Found: '$paths'"
        # for path in $paths;
        #     do $EDITOR "$path";
        # done
        echo "^ FIXME: These paths aren't absolute and raise other errors..."
    fi
}

# Replace ls with eza
alias ls='eza --icons'
alias lsa='ls --all'
alias lsl='ls --long --header --created --git'
alias lst='lsl -TL 2'

# UI folder navigation from the terminal using tere (alternative is walk)
cdt() {
    result=$(tere "$@")
    [ -n "$result" ] && cd -- "$result" || return
}

# Use fd to filter files based on gitignore rules
# From: https://github.com/junegunn/fzf/tree/d01ae551090bb2f7c7ad6a9013937b65e08921cc#respecting-gitignore
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# Preview fzf results with bat syntax highlighting
# > cd ~/.config && fzf-bat
fzf-bat() {
    fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
btail() {
    tail -f "$1" | bat --paging=never -l "${2:-${1##*.}}"
}

# FYI: I'm now using atuin instead of hstr and mcfly
# # Configuration for McFly for menu-based history search
# # All keybindings: https://github.com/copy/mcfly/blob/7a952c68c4910bcdeebaae2ab8b2cc82c60e4677/src/interface.rs#L541-L676
# #   tab to paste without run
# export MCFLY_DISABLE_MENU=TRUE
# export MCFLY_FUZZY=2
# export MCFLY_RESULTS=50
# # HSTR configuration - add this to ~/.zshrc
# alias hh=hstr                         # hh to be alias for hstr
# setopt histignorespace                # skip cmds w/ leading space from history
# export HSTR_CONFIG=hicolor            # get more colors
# bindkey -s "\C-r" "\C-a hstr -- \C-j" # bind hstr to Ctrl-r (for Vi mode check doc)

# FYI: I've uninstalled rpg-cli, which was fun, but not all that useful
# # rpg-cli: a filesystem dungeon
# # https://github.com/facundoolano/rpg-cli#shell-integration
# alias rpg=rpg-cli
# rcd() {
#     rpg-cli cd "$@" || return 1
#     cd "$(rpg-cli pwd)" || return 1
#     rpg-cli ls || return 1
#     rpg-cli pwd
# }
# rpz() {
#     z "$@" || return 1
#     rpg-cli cd "$PWD" || return 1
#     rpg-cli ls || return 1
#     rpg-cli pwd
# }
# rph() {
#     # Heal
#     _last="$PWD"
#     # TODO: Should be a for loop until home
#     # # Shellcheck doesn't understand zsh syntax:
#     # repeat 10 '{ echo '---' && rpg cd "~" }'
#     for _ in {1..10}; do rpg cd "~"; done || return 1
#     # TODO: Should be a for loop to return to _last until battle (then stop and print _last)
#     rpg-cli cd "$_last" || return 1
# }
# alias rpl="rpg-cli ls"
# rpin() {
#     rpg-cli pwd || return 1
#     rcd ~ || return 1
#     rpg-cli ls || return 1
#     echo "~~ Stats ~~"
#     rpg-cli stat || return 1
#     printf "\n~~ Shop ~~"
#     rpg-cli buy || return 1
#     printf "\n~~ Quests ~~"
#     rpg-cli todo || return 1
# }

# gojq (go-based jq replacement)
alias jq='gojq'

# Using htmlq (jq for HTML), extract the website's title
get-title() {
    resp=$(curl --silent "$1")
    if [[ -z "$resp" ]]; then
        echo "Failed to call: 'curl $1'"
        return 1
    fi
    title=$(echo "$resp" | htmlq --text title)
    if [[ -z "$title" ]]; then
        echo "For '$1', failed to extract the title from: '$resp'"
        return 1
    fi
    echo "$title"
}
# Output a readable markdown link with the webpage title
url-to-md-link() {
    title=$(get-title "$1")
    if [[ "$?" == "1" ]]; then
        return 1
    fi
    echo "[$title]($1)"
}

# # Tip: check current $PATH with (thanks to ChatGPT!):
# echo $PATH | awk '{gsub(/:/, "\n"); print}'
