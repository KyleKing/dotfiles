#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Homebrew configuration

export HOMEBREW_NO_ENV_HINTS=1

# A few helpful snippets not included in the homebrew zsh plugin
alias bsh="brew search"
alias bio="brew info"
alias bil="brew install"
alias brm="brew rmtree"
alias bo="brew update && brew outdated"
alias bcbd="brew cleanup && brew doctor"
# What did I install by name, and what shows no sign of use? ("brew leaves" hides
# anything another formula depends on, so daily tools like fzf and rg fall off it)
# A function, not an alias: zsh-syntax-highlighting cannot expand $HOME while it
# highlights, so an alias to this path always shows up as a broken command
binv() { "$HOME/.config/my_config/brew_inventory.py" "$@"; }
# Full post-upgrade + size-gated dev-cache sweep: see _cache_cleanup.sh for "bcbd-deep", "cache-status", "cache-sweep"
# Other useful commands: "brew uninstall <cask>" and "brew uses <...>"

# tmux plugin manager; installed by brew
alias tpm-install="/opt/homebrew/opt/tpm/share/tpm/bin/install_plugins"
alias tpm-update="/opt/homebrew/opt/tpm/share/tpm/bin/update_plugins"
alias tpm-clean="/opt/homebrew/opt/tpm/share/tpm/bin/clean_plugins"

# for steipete CLIs (gifgrep)
export GIFGREP_INLINE=kitty
