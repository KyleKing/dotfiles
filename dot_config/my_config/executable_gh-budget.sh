#!/usr/bin/env bash
# Exit 1 with the reset time when fewer than <min> GraphQL points remain. `gh api rate_limit` is free.
# Usage: gh-budget.sh <min_points>
set -euo pipefail

min="${1:?usage: gh-budget.sh <min_points>}"
read -r remaining reset < <(gh api rate_limit --jq '.resources.graphql | "\(.remaining) \(.reset)"')
if [ "$remaining" -lt "$min" ]; then
  echo "gh-budget: $remaining GraphQL points left (need $min), resets $(date -r "$reset" '+%H:%M')" >&2
  exit 1
fi
