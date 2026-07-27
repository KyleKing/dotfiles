#!/usr/bin/env bash
# Emit one JSON object per line for each repo in mani.yaml (or the names given
# as arguments). Read-only. Requires: yq, jq, gh, git.
set -euo pipefail

BASE_DIR="${FRESHEN_BASE_DIR:-$HOME/Developer/kyleking}"
MANI="$BASE_DIR/mani.yaml"

repos=("$@")
if [ ${#repos[@]} -eq 0 ]; then
  while IFS= read -r name; do repos+=("$name"); done < <(yq -r '.projects | keys | .[]' "$MANI")
fi

for name in "${repos[@]}"; do
  dir="$BASE_DIR/$name"
  slug="KyleKing/$name"

  if [ ! -d "$dir/.git" ]; then
    jq -cn --arg name "$name" '{name: $name, exists_locally: false}'
    continue
  fi

  git -C "$dir" fetch --quiet 2>/dev/null || true

  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
  counts=$(git -C "$dir" rev-list --left-right --count "origin/$branch...$branch" 2>/dev/null || echo "-1 -1")
  behind=${counts%%[[:space:]]*}
  ahead=${counts##*[[:space:]]}
  staged=$(git -C "$dir" diff --cached --name-only | wc -l | tr -d ' ')
  unstaged=$(git -C "$dir" diff --name-only | wc -l | tr -d ' ')
  untracked=$(git -C "$dir" ls-files --others --exclude-standard | wc -l | tr -d ' ')

  copier_src=""; copier_commit=""
  if [ -f "$dir/.copier-answers.yml" ]; then
    copier_src=$(yq -r '._src_path // ""' "$dir/.copier-answers.yml")
    copier_commit=$(yq -r '._commit // ""' "$dir/.copier-answers.yml")
  fi

  gh_meta=$(gh repo view "$slug" --json isArchived,defaultBranchRef \
    -q '{archived: .isArchived, default_branch: .defaultBranchRef.name}' 2>/dev/null || echo '{"error": "not found on GitHub"}')

  alerts=$(gh api "repos/$slug/dependabot/alerts?state=open&per_page=100" \
    -q '[group_by(.security_advisory.severity) | .[] | {(.[0].security_advisory.severity): length}] | add // {}' 2>/dev/null || echo 'null')

  default_branch=$(jq -r '.default_branch // "main"' <<<"$gh_meta")
  ci=$(gh run list -R "$slug" --branch "$default_branch" --limit 10 \
    --json workflowName,status,conclusion,headSha 2>/dev/null |
    jq -c '[.[] | select(.workflowName != "Dependabot Updates")] | group_by(.workflowName)
           | map(.[0] | {workflow: .workflowName, status, conclusion, sha: .headSha[:7]})' || echo '[]')

  jq -cn \
    --arg name "$name" --arg branch "$branch" \
    --argjson ahead "$ahead" --argjson behind "$behind" \
    --argjson staged "$staged" --argjson unstaged "$unstaged" --argjson untracked "$untracked" \
    --arg copier_src "$copier_src" --arg copier_commit "$copier_commit" \
    --argjson is_template "$(case "$name" in *template*) echo true;; *) echo false;; esac)" \
    --argjson has_freshen_txt "$([ -f "$dir/freshen.txt" ] && echo true || echo false)" \
    --argjson gh "$gh_meta" --argjson ci "$ci" --argjson alerts "$alerts" \
    '{name: $name, exists_locally: true, branch: $branch, ahead: $ahead, behind: $behind,
      staged: $staged, unstaged: $unstaged, untracked: $untracked,
      copier_src: $copier_src, copier_commit: $copier_commit,
      is_template: $is_template, has_freshen_txt: $has_freshen_txt} + $gh
     + {ci: $ci, dependabot_alerts: $alerts}'
done
