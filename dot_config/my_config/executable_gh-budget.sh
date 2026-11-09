#!/usr/bin/env bash
# Exit 1 with the reset time and cheaper alternatives when fewer than <min> points remain.
# `gh api rate_limit` is free. Bulk callers pass --wait before each batch so they leave <min> for everyone else.
# Usage: gh-budget.sh [--rest] [--wait] <min>   (default bucket: GraphQL)
set -euo pipefail

bucket=graphql wait=0 min=""
for arg in "$@"; do
  case "$arg" in
    --rest) bucket=core ;;
    --wait) wait=1 ;;
    *) min="$arg" ;;
  esac
done
: "${min:?usage: gh-budget.sh [--rest] [--wait] <min>}"

while true; do
  read -r remaining reset other < <(gh api rate_limit --jq \
    ".resources | \"\(.${bucket}.remaining) \(.${bucket}.reset) \(.$([ "$bucket" = core ] && echo graphql || echo core).remaining)\"")
  [ "$remaining" -ge "$min" ] && exit 0
  at="$(date -r "$reset" '+%H:%M')"
  if [ "$wait" -eq 1 ]; then
    echo "gh-budget: $remaining $bucket left (keeping $min for others), waiting until $at" >&2
    sleep $(( reset - $(date +%s) + 5 ))
    continue
  fi
  if [ "$bucket" = core ]; then
    cat >&2 <<EOF
gh-budget: GitHub REST budget low: $remaining calls left (need $min), resets at $at. GraphQL has $other points left.
Instead of REST calls until then:
  - commits, diffs, blame, history: local git (git fetch is not API budget)
  - PR state, checks, reviews: gh pr view/list/checks --json, gh api graphql (GraphQL budget)
  - a PR page or Actions log: read it in Chrome (no API budget)
  - a failed run: gh-lazydispatch export diagnose <run-id> once, then reuse its output
  - bulk loops: gh-budget.sh --rest --wait 2500 before each batch
EOF
  else
    echo "gh-budget: $remaining GraphQL points left (need $min), resets at $at. REST has $other calls left." >&2
  fi
  exit 1
done
