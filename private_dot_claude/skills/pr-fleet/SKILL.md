---
name: pr-fleet
description: Sweep every open PR across one or more repos, classify each by stack position, unactioned review, merge conflict, and CI state, agree a plan, then hand each repo's approved PRs to pr-pass to work to green. Invoke explicitly.
argument-hint: "[optional checkout dirs, e.g. '. ../repo-a ../repo-b']"
disable-model-invocation: true
---

# PR fleet

The front end for `pr-pass` when the target is "all my open PRs" across more than one
repo.
This skill owns the cross-repo sweep and the plan approval.
`pr-pass` owns the checkout pool, the per-PR pipeline, the gate policy, and the pass
loop; do not restate them here.

## Step 1: settle the working directories

`$ARGUMENTS` may name them. If it does not, ask with AskUserQuestion before running
anything: existing sibling checkouts (`../repo-0`, `../repo-2`), which already carry a
built virtualenv, `node_modules`, and a migrated dev database.
Never create a git worktree, a scratch database, or a container to work around a
checkout whose state does not match the branch.

Group the directories by upstream, because more than one repo can be in flight at once:

```sh
for d in "$@"; do printf '%s\t%s\n' "$d" "$(git -C "$d" remote get-url origin)"; done
```

Directories sharing an origin form one repo group.
Each group is independent and becomes one `pr-pass` run with that group's directories
as its pool.

## Step 2: sweep and classify

Per repo group, from one of its checkouts, run
`~/.claude/skills/pr-pass/scripts/status.py` with no PR numbers.
It covers every open PR the user authored there: stack units bottom-up, conflicts,
commits behind base, failed and pending checks, warning annotations, and reviews with
open threads.
Do not re-derive this with ad-hoc shell.

Present one table per repo, one row per PR, then stop and get approval on which PRs are
in scope.
Nothing touches git before that.

## Step 3: hand off

Run `pr-pass` once per repo group with the approved PR numbers and that group's
directories.
Its pass 0 approval is already covered by step 2 here, so skip straight to its first
pass.
Groups in different repos can run side by side; within a group, `pr-pass`'s
one-worker-per-checkout rule holds.

## Report

One table per repo, before and after, then what is still open and why.
