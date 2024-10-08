#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# General ZSH Configuration

# Use with modifications to ~/.zsrhc
alias time-zsh-startup="ZPROF=1 zsh -i -c exit"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Ensure 256 Color
export TERM=xterm-256color

# Don't put duplicate lines in the history: https://www.eriwen.com/bash/effective-shorthand/
export HISTCONTROL=ignoredups

# Variable descriptions: https://stackoverflow.com/a/19454838/3219667
HISTFILE="$HOME/.histfile"
export HISTSIZE=25000 # number of lines or commands that are stored in memory in a history list while your bash session is ongoing.
export SAVEHIST=25000 # is the number of lines or commands that (a) are allowed in the history file at startup time of a session, and (b) are stored in the history file at the end of your bash session for use in future sessions
bindkey -e

# Bash History Commands: https://www.gnu.org/software/bash/manual/html_node/Commands-For-History.html
#   end-of-history (M->)
#   FYI: `M-` is the meta key, which is either ESC (<C-[>) then the key or sometimes Alt + key
bindkey "\C-n" history-beginning-search-forward
bindkey "\C-p" history-beginning-search-backward

# Sort and Format JSON
alias sfj="json5 | jq"
alias clip-sfj="pbpaste | sfj | pbcopy"

# Copy Last Line (FYI: omz plugin <C-o> will copy current line)
alias cll="fc -ln 0 | tail -n 1 | pbcopy"

# Useful combination of mkdir and cd
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# From: https://github.com/kakulukia/dotfiles/blob/eb4fd73d876727a6325362b21fad45dc7bd18913/.alias#L92C1-L130C24
function mvf() {
    # Move without repeating the filename
    if [[ "$#" -ne 1 ]] || [[ ! -f "$1" ]]; then
        command mv -iv "$@"
        return
    fi

    new_filename="$1"
    vared new_filename
    command mv -iv -- "$1" "$new_filename"
}
witch() {
    # Better which
    local format="${2:-path}" # Default to path output
    if [[ "$1" = "--full" ]]; then
        format="full"
        shift 1
    fi
    IFS=$'\n'
    set -f
    found=false
    for LINE in $(type -a "$1"); do
        COMMAND=$(echo "$LINE" | cut -d ' ' -f 3)
        if [[ $COMMAND = /* ]]; then
            version=$("$COMMAND" --version 2> /dev/null)
            [[ -n $version ]] && version="($version)"
            found=true
            if [[ $format == 'full' ]]; then
                echo "$1 is $COMMAND $version"
                ll "$COMMAND"
            else
                echo "$COMMAND"
                break
            fi
        fi
    done
    if [[ $found = false ]]; then
        return 1
    fi
}
# alias wi="which --full"
