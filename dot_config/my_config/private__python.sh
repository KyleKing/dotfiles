#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Python and pipx Configuration

# Ensure that pre-commit always uses color
# https://github.com/pre-commit/pre-commit/blob/354b900f15e88a06ce8493e0316c288c44777017/pre_commit/color.py#L105
export PRE_COMMIT_COLOR=always

# Turn On Better Exceptions for Python
export BETTER_EXCEPTIONS=1

# Ensure that poetry creates a .venv
export POETRY_VIRTUALENVS_IN_PROJECT=true

# > pipx completions require bashcompinit
# autoload -U bashcompinit
# bashcompinit
eval "$(register-python-argcomplete pipx)"

# Run pre-commit
alias pc-c="pre-commit run --hook-stage commit --all-files"
alias pc-p="pre-commit run --hook-stage push --all-files"

# Some useful aliases for calcipy/invoke-related projects
alias prc="poetry run calcipy"
alias prcv="poetry run calcipy -vvv"

# Wrap useful plugins
alias prsl="toml-sort pyproject.toml --in-place --all --trailing-comma-inline-array --sort-first=python && poetry relax && poetry relax --group=dev && poetry lock --no-update"

# Automate accepting copier commands by sending 'Enter' via STDIN
alias copier-auto-update='echo -e "\n\n\n\n\n\n\n\n\n\\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" | copier update'
