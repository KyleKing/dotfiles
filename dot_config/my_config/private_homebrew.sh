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

# FIXME: install fd once we can upgrade our OS
