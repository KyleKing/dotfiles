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

# Fix Brew Doctor warning about" config scripts exist outside your system or Homebrew directories"
# From: https://github.com/pyenv/pyenv
alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'

# A few helpful snippets not included in the homebrew zsh plugin
alias bs="brew search"
alias bi="brew info"
alias bcbd="brew cleanup && brew doctor"
