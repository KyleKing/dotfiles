#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# FYI: must be in .zprofile and .zshrc so that 'z' is available at login (zsh -lc 'z --help') for Z Sublime Package, chezmoi cd, etc.

# zoxide (z): https://github.com/ajeetdsouza/zoxide
# Keep tool/plugin internals out of the frecency db (and out of `sesh list`,
# which merges zoxide dirs alongside tmux/config sessions) -- these are
# never places worth cd-ing/sesh-ing into, just noise from being visited by
# scripts or plugin managers. Manually stripped the same categories out of
# the existing db once with `zoxide remove`; this only prevents regrowth.
export _ZO_EXCLUDE_DIRS="$HOME/Library/*:$HOME/.local/share/nvim/*:$HOME/.local/share/opencode/*:$HOME/.local/share/mise/*:$HOME/.local/share/rtx/*:$HOME/go/pkg/*:$HOME/go/bin:$HOME/.config/nvim-checkouts/*:$HOME/.cache/*"
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
