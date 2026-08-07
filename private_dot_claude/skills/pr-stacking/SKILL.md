---

## name: pr-stacking description: Plan and scaffold a stack of up to 4 dependent PRs for a feature, walking-skeleton first, using merge-forward sync instead of rebase so GitHub's diff view stays stable across review rounds. Use when asked to stack a feature, split work into stacked PRs, plan a PR stack, or design an incremental rollout of a large change across dependent branches.

# PR stacking

Two-phase skill: draft a stacking plan, get explicit approval, then scaffold the
approved plan's branches and draft PRs.
Never skip straight to execution — the plan is cheap to get wrong and expensive to
unwind once branches and PRs exist.

## Phase 1: plan

Given a feature description (or ticket), produce a stack of at most 4 PRs.
Fewer is fine and often better — collapse stages that don't need their own review cycle.
If the feature genuinely needs more than 4, say so explicitly and ask before proposing a
longer stack.

Default shape, adapt as needed:

1. **Walking skeleton** — the thinnest possible path through every layer the feature
    touches (schema/accessor through to caller/UI/endpoint), wired end-to-end with the happy
    path only.
    No edge cases, minimal tests, no polish.
    The point is to prove the shape of the interfaces before investing further, and to give
    the reviewer something they can see actually used, not an isolated layer they have to
    take on faith.
1. **Additional vertical slice(s)** (0–2 PRs) — only if the feature has more than one
    materially independent slice (e.g. two unrelated entry points into the same core logic).
    Each slice should still be a complete path end to end, not a layer.
1. **Edge cases and extended logic** — validation, error handling, less-common paths,
    hardening on top of the skeleton.
    This is where it's fine to touch only one layer at a time, since the reviewer already
    has the working end-to-end shape from PR 1 as context.
1. **Polish** (optional) — observability, docs, test coverage beyond what shipped inline.
    Only break this out if it's large enough to deserve its own review pass; otherwise fold
    it into the PR it belongs to.

For each PR in the plan, write:

- Branch name and base (the branch below it in the stack, or `main` for the first).
- One-paragraph scope: what this PR does and, just as important, what it explicitly defers
    to a later PR.
- A review note when a PR introduces an interface (new accessor, new query shape, new
    endpoint signature) that a reviewer can't fully judge without seeing its caller.
    Point at which later PR in the stack has the caller, rather than asking the reviewer to
    take the shape on faith.

Do not describe the split using "horizontal" or "vertical" without checking which
direction you mean — those terms are used inconsistently across the industry.
Say directly whether a given PR cuts across all layers (skeleton, slices) or stays
within one layer (edge-case hardening), since that's the property that actually matters
for review order.

Present the plan and stop. Wait for explicit approval before touching git.

## Phase 2: scaffold (on approval)

Create the branches and draft PRs for the approved plan, bottom-up:

```
git checkout -b <branch-1> main
# implementation happens here, out of scope for this skill
git push -u origin <branch-1>
gh pr create --base main --head <branch-1> --draft --title "..." --body "..."

git checkout -b <branch-2> <branch-1>
git push -u origin <branch-2>
gh pr create --base <branch-1> --head <branch-2> --draft --title "..." --body "..."
```

Continue for each PR in the plan. Mark PRs as drafts unless told otherwise —
implementation still needs to happen on each branch after scaffolding.

Each PR description should link the PR below it (its base) and note it's part of a
stack, so a reviewer landing on any single PR can find the rest.

## Syncing the stack (merge-forward, not rebase)

This is the one non-negotiable: never rebase or force-push a branch that's part of an
open stack.
Force-pushes rewrite history GitHub has already rendered a diff for, which breaks
incremental re-review and discards inline comment anchoring.
Squashed, one-commit-per-PR history is not a goal here — multiple commits per branch are
fine.

When a lower PR in the stack changes after review feedback:

1. Commit the fix on the lower branch normally, push (not force-push).
1. Starting from the branch directly above it and working upward through the stack,
    `git merge` the updated lower branch into each branch above it:
    ```
    git checkout <branch-2>
    git merge <branch-1>
    git push
    git checkout <branch-3>
    git merge <branch-2>
    git push
    ```
    This creates merge commits and leaves prior history intact.
    GitHub's diff view for each PR keeps showing only that PR's own changes.

When the bottom PR of the stack merges to `main`:

1. Retarget the next PR's base to `main` (`gh pr edit <n> --base main`, or let GitHub's
    native stacked-PR retargeting handle it if available).
1. `git merge main` into that branch to drop the now-landed diff from its view, push,
    repeat up the stack.

Squash-merge or regular merge to `main` is fine per PR; the constraint above is only
about not force-pushing branches that other open PRs in the stack are based on.

### Direction matters: only merge downward-base into upward-dependent

Every merge in a stack goes exactly one way: from the branch a PR is based on, into the
branch that depends on it (i.e. from lower in the stack to higher).
Never the reverse. Merging an upper branch into the branch below it — even by accident,
even as a "just sync everything" step — makes the lower branch a superset of the upper
one.
GitHub reads that as the upper branch's PR being satisfied and **auto-merges and closes
it**, and then auto-retargets any PR that was based on the upper branch onto the upper
branch's own base, silently pulling unrelated content into that PR's diff.

This is easy to trigger by checking out the wrong branch before running
`git merge <other-branch>` — the direction depends on which branch you're currently on,
and `git merge` gives no warning either way.
Before merging in a stack, confirm direction with:

```
git merge-base --is-ancestor <branch-you-are-on> <other-branch> && echo "safe: other-branch is downstream, ok to merge it in"
```

If that check fails, you're about to merge the wrong way.

**Symptoms this already happened:** a PR you didn't touch shows as merged/closed in
`gh pr list --state all`, or a sibling PR's `baseRefName` changed on its own.

**Recovery**, since a merged PR cannot be reopened:

1. Find the branch's tip *before* the accidental merge: `git reflog show <branch>` — look
    for the entry just before the `merge <other-branch>` line.
1. Force-push the branch back to that SHA (`git push --force-with-lease`, after confirming
    the remote hasn't moved further — `git fetch && git rev-parse origin/<branch>` should
    match the SHA you're about to overwrite).
1. Open a fresh PR replacing the one that auto-merged (same base/head as before) — a
    one-line stub body plus an `AI Summary:` comment explaining the history is enough; no
    need to re-litigate the original description.
1. Retarget any PR that got auto-shifted back to its correct base:
    `gh pr edit <n> --base <correct-branch>`.

## Validating a fix before it propagates

Keep the gate on each branch minimal — hk's pre-commit hooks (ruff, oxfmt, pyright,
i18n, alembic-head checks) already run per commit and catch the bulk of what a full
local suite would.
Don't re-derive that coverage by hand.

- Trust the commit hook's output. If it passed, format/lint/type-check are already covered
    — no need for a separate `make check`/`ruff` pass.
- Run targeted tests, not full suites: `pytest -k <test_name_or_module>` (or the
    `make test-api EXP="..."`/`test-common EXP="..."` equivalent) against the specific test
    file(s) the fix touches.
    A full `make test-api` / `test-common` run is rarely worth the wall-clock time mid-stack
    — it's redundant with what CI runs on push anyway.
- Let CI be the full-suite backstop. Push, open/refresh the PR, and if CI flags something
    a targeted run missed, fix forward with another small commit and re-sync upward — don't
    block the merge-forward cascade on running every suite locally first.
- Reach for a broader local run only when the fix is genuinely cross-cutting (touches
    shared infra many suites depend on) or CI is slow/flaky enough that a quick local check
    is faster than waiting on it.
- If the shared dev stack's migration state doesn't match the branch you're testing
    (checked out a lower branch that's behind or ahead of what's currently migrated), reset
    it with `make run-backend-reset-db` rather than building parallel test infrastructure —
    this repo's fixtures are designed to be cheap to regenerate.
    **Never spin up an ad-hoc container or scratch database to work around this — ask the
    user first** if a reset isn't appropriate (e.g. it would discard state they explicitly
    asked you to preserve).

## Inserting a PR into the middle of an existing stack

Sometimes a fix belongs between two branches that are already stacked and reviewed (e.g.
a bug found while demoing the top of the stack needs to land below the PR that surfaced
it, not on top of it).
This differs from Phase 2 scaffolding because the branches above the insertion point
already have commits and open PRs:

1. Branch the new PR off the branch it sits above in the final stack:
    `git checkout -b <new-branch> <lower-branch>`.
    Implement and commit the fix there, push, and open its PR with `--base <lower-branch>`.
1. Rebase the branch that used to sit directly on `<lower-branch>` onto `<new-branch>`
    instead: `git checkout <upper-branch>` then
    `git rebase --onto <new-branch> <lower-branch> <upper-branch>`.
    This is the one case where rebasing a branch in an existing stack is fine — that
    specific rebase only replays `<upper-branch>`'s own commits on a new base; it does not
    rewrite history any other open PR has already diffed against, since `<new-branch>` is
    brand new and unreviewed.
1. Force-push `<upper-branch>` (`git push --force-with-lease`) and retarget its PR's base
    with `gh pr edit <upper-branch-pr-number> --base <new-branch>` — GitHub does not infer
    the new base from the rebase alone.
1. Verify with `gh pr diff <n> --name-only` on both the new PR and the retargeted one: the
    new PR should show only the inserted fix, and the retargeted one should show only its
    own original changes, with no overlap.

This still respects the merge-forward rule everywhere else in the stack: branches
*above* `<upper-branch>` are unaffected and don't need rebasing, since
`<upper-branch>`'s commit content (not just its tip SHA) is unchanged by the rebase —
only its base moved.
