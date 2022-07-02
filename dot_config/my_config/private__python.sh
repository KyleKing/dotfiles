#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Python, pipx, and pyenv Configuration

# Ensure that pre-commit always uses color
# https://github.com/pre-commit/pre-commit/blob/354b900f15e88a06ce8493e0316c288c44777017/pre_commit/color.py#L105
export PRE_COMMIT_COLOR=always

# Turn On Better Exceptions for Python
export BETTER_EXCEPTIONS=1

# # Configure pyenv
# # Following: https://github.com/pyenv/pyenv#homebrew-in-macos
# # Path configuration is in .zshprofile
# # Note: https://github.com/pyenv/pyenv/issues/849#issuecomment-285229619
# eval "$(pyenv init -)"

# > pipx completions require bashcompinit
# autoload -U bashcompinit
# bashcompinit
eval "$(register-python-argcomplete pipx)"

# Some useful aliases for calcipy-related projects
alias prdl="poetry run doit list"
alias prdr="poetry run doit run"
alias prdc="poetry run doit --continue"
# Based on the full command for deploying from DEVELOPER_GUIDE.md
alias prpub="prdr cl_bump lock document deploy_docs publish cl_write document deploy_docs"
