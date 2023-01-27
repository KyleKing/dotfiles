#!/bin/bash
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

# Some useful aliases for calcipy-related projects
alias prdl="poetry run doit list"
alias prdr="poetry run doit run"
alias prdc="poetry run doit --continue"
alias prpc="poetry run pre-commit run --hook-stage commit --all-files"
# Based on the full command for deploying from DEVELOPER_GUIDE.md
alias prpub="prdr cl_bump lock document deploy_docs publish cl_write document deploy_docs"
