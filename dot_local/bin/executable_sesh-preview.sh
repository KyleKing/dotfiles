#!/usr/bin/env bash
# Preview target for sesh's `default_session.preview_command` (see
# ~/.config/sesh/sesh.toml). sesh splits preview_command on spaces with no
# shell interpretation, so conditional logic (doing.txt or not) has to live
# in a script rather than an inline command.
#
# Convention: a `doing.txt` file at a project root is a running note of
# "what I'm doing here" (multi-line/markdown is fine). If present, it's
# rendered above the usual directory listing.
set -euo pipefail

path="$1"
doing="$path/doing.txt"

if [ -f "$doing" ]; then
  bat --style=plain --color=always --language=markdown "$doing"
  printf '\n'
fi

eza --all --git --icons --color=always "$path"
