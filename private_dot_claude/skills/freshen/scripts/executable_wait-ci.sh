#!/usr/bin/env bash
# Block until every workflow run for a commit completes, then print one line
# per workflow. On failure, print an ANSI-stripped tail of the failed steps.
# Usage: wait-ci.sh <owner/repo> <sha> [timeout_seconds]
# Exit: 0 all success, 1 any failure, 2 timeout or no runs appeared.
set -euo pipefail

slug="$1"; sha="$2"; timeout="${3:-900}"
deadline=$(( $(date +%s) + timeout ))
short=${sha:0:7}

while true; do
  runs=$(gh run list -R "$slug" --limit 20 --json workflowName,status,conclusion,headSha,databaseId \
    -q "[.[] | select(.headSha | startswith(\"$short\"))]")
  count=$(jq 'length' <<<"$runs")
  pending=$(jq '[.[] | select(.status != "completed")] | length' <<<"$runs")
  if [ "$count" -gt 0 ] && [ "$pending" -eq 0 ]; then break; fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "TIMEOUT after ${timeout}s ($count runs, $pending pending)"
    exit 2
  fi
  sleep 30
done

jq -r '.[] | "\(.workflowName): \(.conclusion)"' <<<"$runs"

failed=$(jq -r '[.[] | select(.conclusion == "failure")] | .[].databaseId' <<<"$runs")
if [ -n "$failed" ]; then
  for id in $failed; do
    echo "--- failed run $id (filtered tail) ---"
    gh run view "$id" -R "$slug" --log-failed 2>/dev/null |
      sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\[[0-9;]*m//g' |
      grep -viE "post job|git config|cleaning up|temporarily overriding|adding repo|removing (ssh|http|credentials|includeif)|includeif|git-credentials|submodule foreach" |
      tail -40
  done
  exit 1
fi
