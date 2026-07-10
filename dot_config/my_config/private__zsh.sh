#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
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

# sesh: fuzzy-pick a tmux session from the shell (tmux/config/zoxide, incl. SSH
# hosts defined in ~/.config/sesh/sesh.toml). Attaches or creates; works outside
# tmux too. In-tmux equivalent: <prefix> s (see dot_tmux.conf.tmpl)
alias sz='sesh connect "$(sesh list --icons | fzf --height 40% --reverse --border --prompt "⚡ ")"'
