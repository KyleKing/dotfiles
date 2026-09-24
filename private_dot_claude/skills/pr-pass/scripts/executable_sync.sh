#!/usr/bin/env bash
# Check out a PR's branch in the current checkout and merge its base into it.
# The base comes from GitHub, never from the caller, so the merge can only run
# downward-base into upward-dependent (the direction that cannot auto-close a PR).
# Usage: sync.sh <pr-number>
# Exit: 0 merged cleanly or already up to date, 1 conflicts left in the tree,
#       2 precondition failed (dirty tree, mid-operation, branch diverged).
set -euo pipefail

pr="${1:?usage: sync.sh <pr-number>}"
git_dir=$(git rev-parse --git-dir)

# Untracked files stay: git refuses the switch itself if the target would overwrite one.
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "dirty tree; refusing to switch branches:" >&2
  git status --short --untracked-files=no >&2
  exit 2
fi
for marker in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD; do
  if [ -e "$git_dir/$marker" ]; then
    echo "checkout is mid-operation ($marker); refusing" >&2
    exit 2
  fi
done

meta=$(gh pr view "$pr" --json headRefName,baseRefName,state)
head=$(jq -r .headRefName <<<"$meta")
base=$(jq -r .baseRefName <<<"$meta")
state=$(jq -r .state <<<"$meta")
if [ "$state" != "OPEN" ]; then
  echo "#$pr is $state; refusing" >&2
  exit 2
fi

git fetch --quiet origin "$head" "$base"
if git show-ref --verify --quiet "refs/heads/$head"; then
  git switch --quiet "$head"
  if ! git merge --ff-only --quiet "origin/$head"; then
    echo "local $head has diverged from origin/$head; resolve by hand" >&2
    exit 2
  fi
else
  git switch --quiet -c "$head" --track "origin/$head"
fi

behind=$(git rev-list --count "HEAD..origin/$base")
echo "#$pr: $head <- origin/$base ($behind commits behind)"
if [ "$behind" -eq 0 ]; then
  exit 0
fi

if merge_out=$(git merge --no-edit "origin/$base" 2>&1); then
  echo "merged cleanly: $(git log -1 --format='%h %s')"
  exit 0
fi
if [ ! -e "$git_dir/MERGE_HEAD" ]; then
  echo "merge failed without leaving conflicts:" >&2
  echo "$merge_out" >&2
  exit 2
fi

echo "conflicts:"
git diff --name-only --diff-filter=U | sed 's/^/  /'
exit 1
