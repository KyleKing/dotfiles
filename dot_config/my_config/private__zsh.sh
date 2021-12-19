# General ZSH Configuration

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Ensure 256 Color
export TERM=xterm-256color

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='subl --add'
fi

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

# Useful combination of mkdir and cd
mkcd() {
  mkdir -p $1 && cd $1
}
