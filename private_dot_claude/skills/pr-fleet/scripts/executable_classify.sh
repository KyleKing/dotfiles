#!/usr/bin/env bash
# Emit one JSON object per line for each open PR authored by @me in <owner/repo>,
# classified by stack position and conflict state. Read-only. Requires: gh, jq.
#
# CodeRabbit thread counts are not included here — they need a per-PR GraphQL
# call (see change-review-apply step 2 / ai-cr-review.py status).
set -euo pipefail

repo="${1:?usage: classify.sh <owner/repo>}"

default_branch=$(gh repo view "$repo" --json defaultBranchRef -q '.defaultBranchRef.name')

prs=$(gh pr list --repo "$repo" --author @me --state open --limit 50 \
  --json number,title,headRefName,baseRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup)

jq --arg default "$default_branch" '
  . as $all
  | ($all | map(.headRefName)) as $heads
  | $all
  | map(
      . as $pr
      | ($heads | index($pr.baseRefName)) as $base_idx
      | {
          number: $pr.number,
          title: $pr.title,
          isDraft: $pr.isDraft,
          base: $pr.baseRefName,
          stack: (
            if $pr.baseRefName == $default then "bottom"
            elif $base_idx != null then "stacked on #\($all[$base_idx].number)"
            else "orphan (base has no open PR, not \($default))"
            end
          ),
          conflicted: (
            if $pr.mergeable == "CONFLICTING" then true
            elif $pr.mergeable == "UNKNOWN" then "unknown (re-poll)"
            else false
            end
          ),
          failing_checks: (
            [$pr.statusCheckRollup[]? | (.conclusion // .state // "") | select(. == "FAILURE" or . == "ERROR")] | length
          )
        }
    )
  | .[]
' <<<"$prs"
