#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Python, pipx, and pyenv Configuration

# Turn On Better Exceptions for Python
export BETTER_EXCEPTIONS=1

# Configure pyenv
# https://github.com/pyenv/pyenv/issues/849#issuecomment-285229619
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# > pipx completions require bashcompinit
# autoload -U bashcompinit
# bashcompinit
eval "$(register-python-argcomplete pipx)"

# Some useful aliases for calcipy-related projects
alias prdl="poetry run doit list"
alias prdr="poetry run doit run"
alias prdc="poetry run doit --continue"
