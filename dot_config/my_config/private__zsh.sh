#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# General ZSH Configuration

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

# Based on: https://github.com/zsh-users/zsh-autosuggestions/issues/609#issuecomment-904204583
bindkey "^N" history-beginning-search-forward
bindkey "^P" history-beginning-search-backward

# Useful aliases for working with history
# > View JSON in CLI
alias ppj="pbaspate | jq"
alias ppjc="ppj | pbcopy"
# PLANNED: Support parsing non-JSON to json (this won't handle trailing commas...)
alias tojson="python -c 'import json; import sys; print(json.dumps(json.loads(sys.stdin.read())))'"
# > Copy Last Line
alias cll="fc -ln 0 | tail -n 1 | pbcopy"

# Useful combination of mkdir and cd
mkcd() {
    mkdir -p $1 && cd $1 || return
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
