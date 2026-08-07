#!/usr/bin/env bash
# Wraps `gh pr` so an AI-authored PR keeps a stable, singleton description per
# the rule in ~/.claude/CLAUDE.md: a description I wrote myself is never
# touched; an empty/WIP one gets replaced, once, with a pointer to a comment
# that starts with "AI Summary:" and is PATCHed in place on every update.
#
# Usage:
#   ai-gh-pr.sh create [--ready] [-- <extra gh pr create args>]
#   ai-gh-pr.sh comment <body>
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") create [--ready] [-- <extra gh pr create args>]" >&2
  echo "       $(basename "$0") comment <body>" >&2
  exit 1
}

[ $# -ge 1 ] || usage
cmd=$1
shift

case "$cmd" in
  create)
    draft=1
    extra_args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --ready)
          draft=0
          shift
          ;;
        --)
          shift
          extra_args=("$@")
          break
          ;;
        *)
          extra_args+=("$1")
          shift
          ;;
      esac
    done

    title=$(git log -1 --pretty=%s)
    args=(--title "$title" --body "WIP" --assignee "@me")
    [ "$draft" -eq 1 ] && args+=(--draft)

    gh pr create "${args[@]}" "${extra_args[@]}"
    # Run `gh pr ready` once the PR is ready for review.
    ;;

  comment)
    [ $# -eq 1 ] || usage
    body=$1

    number=$(gh pr view --json number -q .number)
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)

    existing_id=$(gh api "repos/$repo/issues/$number/comments" \
      -q '[.[] | select(.body | startswith("AI Summary:"))][0].id // empty')

    if [ -n "$existing_id" ]; then
      gh api -X PATCH "repos/$repo/issues/comments/$existing_id" -f body="$body" >/dev/null
      echo "Updated AI Summary comment on #$number"
      exit 0
    fi

    comment_url=$(gh pr comment "$number" --body "$body")
    echo "Posted AI Summary comment: $comment_url"

    current_body=$(gh pr view "$number" --json body -q .body)
    if [ -z "$current_body" ] || [ "$current_body" = "WIP" ]; then
      gh pr edit "$number" --body "$(printf 'WIP\n\nSee full AI Summary below: %s' "$comment_url")"
      echo "Replaced empty description with pointer"
    fi
    ;;

  *)
    usage
    ;;
esac
