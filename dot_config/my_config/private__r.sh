#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# R configuration

# Override 'r' as recommended by: https://github.com/randy3k/radian
# Must be installed with pipx (pipx install radian)
alias r="radian"
