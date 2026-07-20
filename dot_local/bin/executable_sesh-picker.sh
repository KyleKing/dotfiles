#!/usr/bin/env bash
# Shared picker behind both the tmux <prefix>s binding (dot_tmux.conf.tmpl)
# and the `sz` shell alias (private__zsh.sh). Pipes the annotated session
# list (sesh-annotated-list.sh) into the fzf variant given as arguments, then
# connects to whichever raw name (field 1) was selected.
#
# Usage: sesh-picker.sh <fzf-binary-and-flags...>
set -euo pipefail

selected=$(
  sesh-annotated-list.sh |
    "$@" --delimiter=$'\t' --with-nth=2 --preview 'sesh preview {1}'
)

[ -z "$selected" ] && exit 0

name=$(printf '%s' "$selected" | cut -f1)
sesh connect "$name"
