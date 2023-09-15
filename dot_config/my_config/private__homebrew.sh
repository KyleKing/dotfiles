#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Homebrew configuration

# Source homebrew-installed completions
# Explanation: https://docs.brew.sh/Shell-Completion
if type brew &> /dev/null; then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

    autoload -Uz compinit
    compinit
fi

# A few helpful snippets not included in the homebrew zsh plugin
alias bsh="brew search"
alias bio="brew info"
alias bil="brew install"
alias brm="brew rmtree"
alias buc="brew uninstall --cask"
alias bo="brew update && brew outdated"
alias bcbd="brew cleanup && brew doctor"
# Other useful commands: "brew uninstall <cask>" and "brew uses <...>"

# tmux plugin manager; installed by brew
alias tpm-install="/opt/homebrew/opt/tpm/share/tpm/bin/install_plugins"
alias tpm-update="/opt/homebrew/opt/tpm/share/tpm/bin/update_plugins"
alias tpm-clean="/opt/homebrew/opt/tpm/share/tpm/bin/clean_plugins"
