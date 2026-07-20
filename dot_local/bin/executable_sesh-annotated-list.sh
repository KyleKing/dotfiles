#!/usr/bin/env bash
# Wraps `sesh list --json` to annotate each row with its source (tmux/cfg/
# tmxr/dir) and a marker for projects that have a doing.txt (see
# sesh-preview.sh for the matching preview-pane rendering).
#
# Emits TSV: <raw-name>\t<decorated-line>
# Callers must `cut -f1` the fzf selection to recover the raw, connectable
# name before handing it to `sesh connect` -- sesh's own icon-stripping only
# understands sesh's icons, not this wrapper's tags, so the decorated text
# can never reach `sesh connect` directly. See sesh-picker.sh.
set -euo pipefail

sesh list --json | jq -r '.[] | [.Src, .Name, .Path, (.Windows // 0)] | @tsv' |
while IFS=$'\t' read -r src name path windows; do
  case "$src" in
    tmux | tmux-pane) tag="tmux" ;;
    config | config_wildcard) tag="cfg" ;;
    tmuxinator) tag="tmxr" ;;
    zoxide) tag="dir" ;;
    *) tag="$src" ;;
  esac

  extra=""
  if [ "$tag" = "tmux" ] && [ "$windows" != "0" ]; then
    extra=" ${windows}w"
  fi

  marker=""
  [ -f "$path/doing.txt" ] && marker=" 📝"

  printf '%s\t[%s%s]%s %s\n' "$name" "$tag" "$extra" "$marker" "$name"
done
