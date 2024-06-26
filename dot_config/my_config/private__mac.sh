#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# General Mac Aliases

# Open with Dropover!
alias odo="open -a Dropover"

# Open in finder
alias o="open ."

# Launch nvim using the local poetry environment
alias prn='poetry run nvim'
# Load alternate nvim configs (from: https://github.com/nvim-lua/kickstart.nvim/#FAQ)
alias astronvim='NVIM_APPNAME="nvim-astronvim" nvim'
alias plainvim='NVIM_APPNAME="nvim-plain" nvim'
