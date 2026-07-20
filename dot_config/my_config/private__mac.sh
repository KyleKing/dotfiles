#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# General Mac Aliases

# Open with Dropover!
alias odo="open -a Dropover"

# Open in finder
alias o="open ."

# Load alternate nvim configs (from: https://github.com/nvim-lua/kickstart.nvim/#FAQ)
alias astronvim='NVIM_APPNAME="nvim-astronvim" nvim'
alias plainvim='NVIM_APPNAME="nvim-plain" nvim'

# Pick up the live ssh-agent socket, even in panes opened inside stale tmux sessions
if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
  ssh_auth_sock="$(launchctl print "gui/$(id -u)/com.openssh.ssh-agent" 2>/dev/null | awk '/SSH_AUTH_SOCK =>/{print $3}')"
  export SSH_AUTH_SOCK="$ssh_auth_sock"
fi
