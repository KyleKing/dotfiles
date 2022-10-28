#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Homebrew configuration

# Source homebrew-installed completions
# Explanantion: https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null
then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

    autoload -Uz compinit
    compinit
fi

# # Fix Brew Doctor warning about" config scripts exist outside your system or Homebrew directories"
# # From: https://github.com/pyenv/pyenv
# alias brew='env PATH="${PATH//\/.asdf\/shims:/}" brew'

# A few helpful snippets not included in the homebrew zsh plugin
alias bsh="brew search"
alias bio="brew info"
alias bil="brew install"
alias brm="brew rmtree"
alias buc="brew uninstall --cask"
alias bo="brew update && brew outdated"
alias bcbd="brew cleanup && brew doctor"
# Other useful commands: "brew uninstall <cask>" and "brew uses <...>"
