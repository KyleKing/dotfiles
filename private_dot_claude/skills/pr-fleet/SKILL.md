---
name: pr-fleet
description: Sweep every open PR across one or more repos, classify each by stack position, unactioned CodeRabbit review, and merge conflict, then work them to green in parallel across a pool of checkouts. Invoke explicitly.
argument-hint: "[optional checkout dirs, e.g. '. ../repo-a ../repo-b']"
disable-model-invocation: true
---

# PR fleet

One pass over the user's open PRs: find out what each needs, agree on the plan, then
fix them concurrently across separate checkouts.

This skill owns the sweep, the checkout pool, and the dispatch rules.
The per-PR work
is delegated: `change-review-apply` for reviews, `pr-stacking` for the merge-forward
cascade.
Do not restate those here, invoke them.
Merge conflicts are resolved inline (Step 4) — there's no separate conflict-resolution
skill to delegate to.

## Step 1: settle the working directories

`$ARGUMENTS` may name them. If it does not, ask with AskUserQuestion before running
anything: existing sibling checkouts (`../repo-0`, `../repo-2`), which already carry a
built virtualenv, `node_modules`, and a migrated dev database, so a PR can be tested in
one immediately.
Never create a git worktree, a scratch database, or a container to
work around a checkout whose state does not match the branch.

Group the directories by upstream, because more than one repo can be in flight at once:

```sh
for d in "$@"; do printf '%s\t%s\n' "$d" "$(git -C "$d" remote get-url origin)"; done
```

Directories sharing an origin form one repo group (`../calcipy` alone is one group,
`../corallium` and `../corallium-0-cero` together are another).
Each group is
independent and gets its own coordinator subagent.
Within a group the directories are a
pool: one PR checked out per directory at a time.

Before a directory enters the pool, it must be clean and mid-nothing:

```sh
git -C "$d" status --porcelain
ls "$d/.git/MERGE_HEAD" "$d/.git/rebase-merge" "$d/.git/CHERRY_PICK_HEAD" 2>/dev/null
```

A dirty directory is probably the user or another agent working in parallel.
Report it
and drop it from the pool. Do not clean it, stash it, or reset it.

## Step 2: sweep and classify

Per repo group, run `${CLAUDE_SKILL_DIR}/scripts/classify.sh <owner/repo>`.
It emits one JSON object per line — stack position (chained, bottom, or orphan),
conflict
state (re-polling an `UNKNOWN` `mergeable` rather than reporting it clean), and failing
check count.
Do not re-derive this classification with ad-hoc shell.

Add the one classification the script can't do read-only from `gh pr list` alone:
unresolved review threads authored by `coderabbitai[bot]`, from the GraphQL query in
`change-review-apply` step 2.
Count threads from *every* CodeRabbit review, not only the
newest, since a review can be skipped when a later push lands before it is actioned.

Present one table, one row per PR: number, stack position, conflicts, open CodeRabbit
threads, failing checks.
Then stop and get approval on the work plan.
Nothing touches
git before that.

## Step 3: dispatch

The unit of concurrency is a branch, not a PR.
Two agents holding the same branch will
lose each other's commits.

- A whole stack is one unit of work owned by one agent, worked bottom-up.
    The
    merge-forward cascade re-touches every branch above the one that changed, so the stack
    cannot be split across agents.
- Independent stacks and standalone PRs run concurrently, one per pool directory.
- When there are more units than directories, queue them.
    Do not double up.

Each subagent gets: its directory, its ordered PR list, the pipeline below, and the gate
policy.
Subagents report back to the coordinator rather than asking the user directly,
and the coordinator raises questions through AskUserQuestion.
Ask liberally: a wrong
conflict resolution is far more expensive than a question.

## Step 4: per-PR pipeline

Order matters. Each step assumes the one above it landed.

1. **Check out.** `gh pr checkout <n>` in the assigned directory.

1. **Get onto the latest base.** Merge the base in (per `pr-stacking`, never rebase a
    branch an open PR is based on).
    Conflicts surface here — resolve them by reading both sides' intent from the
    conflict markers and the commits that produced them (`git log -p` on each side),
    never by blindly preferring one side.
    Split this into two commits: first make the merge correct against the current base,
    then a follow-up that drops now-duplicated code in favor of what has since landed.
    A
    single commit doing both hides which half broke something.

1. **Reseat sequenced artifacts.** Anything ordered by a key rather than by content
    (database migrations, changelog fragments, numbered fixtures) is stale once the base
    moves.
    Use the project's own skill if it has one (`/alembic-rebase` in the platform repo), then
    restamp both the filename and the in-file header to UTC now:

    ```sh
    date -u +%Y%m%d%H%M%S
    ```

    Confirm the ordering is single-headed afterward (`alembic heads` or the project's
    equivalent) before moving on.

1. **Action the review.** Run `change-review-apply`.
    Then check explicitly for an earlier
    review whose threads are still open, because that skill scopes itself to one review id
    by default.

1. **Fix what is actually broken.** CI failures, and bugs you find while reading the
    diff.
    Ask when a fix is a judgment call.

1. **Cascade.** Push, then merge-forward up the stack per `pr-stacking`, running the
    direction check before each merge.
    Retarget bases when the bottom of a stack lands.

1. **Update the writeup.** Only when something changed that the summary should carry.
    Use the repo's own PR-writeup skill/script if it has one (`irm-pr` in the platform
    repo), else `~/.config/my_config/ai-gh-pr.py`.
    Either way: `get` first, edit the returned text in place (keep what's still true,
    update what changed, drop what's stale), then submit it whole with `comment "<body>"`.
    Never draft a fresh summary from memory, and never touch the PR body directly.

Invoking this skill authorizes committing and pushing on the branches in scope, which
overrides the "do not push" line in `change-review-apply`.
It does not authorize touching
branches outside the approved plan.

## Gate policy: fast path, then one audit

Speed comes from not gating twice. Per commit, hk's hooks already cover format, lint,
and types, so trust them.
Before a push or a merge-forward, run only the tests covering
the files touched.
Skip full suites entirely.

CI is the backstop. Do not watch or wait on it per PR.
Once the whole fleet is pushed,
make a single audit pass:

```sh
gh pr checks <n> --json name,state,link --jq '.[] | select(.state=="FAILURE")'
```

Fix forward with small commits and re-cascade.
A failure that only reproduces in CI is
worth a targeted local run before guessing at it.

## Report

The same table as step 2, before and after, so the user can see what moved.
Then what is
still open and why, and anything waiting on a decision.
Lead with the lines that change
their next action.
