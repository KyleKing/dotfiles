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

# Automate accepting copier commands by sending 'Enter' via STDIN
alias copier-update="copier update --UNSAFE --conflict=rej"
alias copier-auto-update="copier-update --defaults"
