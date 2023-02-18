#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# FYI: must be in .zprofile and .zshrc so that 'z' is available at login (zsh -lc 'z --help') for Z Sublime Package, chezmoi cd, etc.

# zoxide (z): https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh)"
# zoxide query  --list --score
# z foo              # cd into highest ranked directory matching foo
# z foo bar          # cd into highest ranked directory matching foo and bar
#
# z ~/foo            # z also works like a regular cd command
# z foo/             # cd into relative path
# z ..               # cd one level up
# z -                # cd into previous directory
#
# zi foo             # cd with interactive selection (using fzf)
#
# z foo<SPACE><TAB>  # show interactive completions (zoxide v0.7.10+, bash/fish/zsh only)
