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
# > Copy Last Line
alias cll="fc -ln 0 | tail -n 1 | pbcopy"

# Useful combination of mkdir and cd
mkcd() {
    mkdir -p $1 && cd $1 || return
}
