# General ZSH Configuration

# Don't put duplicate lines in the history: https://www.eriwen.com/bash/effective-shorthand/
export HISTCONTROL=ignoredups

HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
bindkey -e

# Based on: https://github.com/zsh-users/zsh-autosuggestions/issues/609#issuecomment-904204583
bindkey "^N" history-beginning-search-forward
bindkey "^P" history-beginning-search-backward

# Useful aliases for working with history
alias ppj="pbaspate | jq"
alias copy-l="fc -ln 0 | tail -n 1 | pbcopy"

# The following lines were added by compinstall
zstyle :compinstall filename '~/.zshrc'
