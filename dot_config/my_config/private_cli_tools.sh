#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# Configure CLI Tools

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
        paths=$(rgh --fixed-strings --files-with-matches -- $_search)
        echo "Found: '$paths'"
        # for path in $paths;
        #     do $EDITOR "$path";
        # done
        echo "^ FIXME: These paths aren't absolute and raise other errors..."
    fi
}

# Map exa to ll (quicker ls) with some default options
alias ls='exa --icons'
alias lsa='ls --all'
alias lsl='ls --long --header --created --git'
alias lst='lsl -TL 2'

# UI folder navigation from the terminal
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
fzf-bat () {
    fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
btail() {
    tail -f $1 | bat --paging=never -l ${2:-${1##*.}}
}

# HSTR configuration - add this to ~/.zshrc
alias hh=hstr                    # hh to be alias for hstr
setopt histignorespace           # skip cmds w/ leading space from history
export HSTR_CONFIG=hicolor       # get more colors
bindkey -s "\C-r" "\C-a hstr -- \C-j"     # bind hstr to Ctrl-r (for Vi mode check doc)

# rpg-cli: a filesystem dungeon
# https://github.com/facundoolano/rpg-cli#shell-integration
alias rpg=rpg-cli
rcd () {
    rpg-cli ls
    rpg-cli cd "$@"
    cd "$(rpg-cli pwd)" || return
}
rpz () {
    z "$@"
    rpg-cli ls
    rpg-cli cd "$PWD" || return
}
rph () {
    # Heal
    _last="$PWD"
    # TODO: Should be a for loop until home
    # # Shellcheck doesn't understand zsh syntax:
    # repeat 10 '{ echo '---' && rpg cd "~" }'
    for _ in {1..10}; do rpg cd "~"; done
    # TODO: Should be a for loop to return to _last until battle (then stop and print _last)
    rpg-cli cd "$_last" || return
}
rpl () {
    rpg-cli ls
    lsl
}
rpin () {
    echo "$(rpg-cli pwd)"
    rcd ~
    rpg-cli ls
    echo "~~ Stats ~~"
    rpg-cli stat
    echo "\n~~ Shop ~~"
    rpg-cli buy
    echo "\n~~ Quests ~~"
    rpg-cli todo
}

# gojq (go-based jq replacement)
alias jq='gojq'

# ttyper TUI to learn Touch Typing from: https://github.com/max-niederman/ttyper
export PATH=$PATH:~/.cargo/bin

# Tip: check current path with (thanks to ChatGPT!):
# echo $PATH | awk '{gsub(/:/, "\n"); print}'
