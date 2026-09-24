---
name: pr-pass
description: Work a set of PRs (stacked or not) to green in repeated passes. Each pass merges the latest base, actions reviews, fixes CI, pushes, and cascades up any stack, with Sonnet workers running one PR at a time per checkout. Stops after four passes or once every PR is green with nothing left to action. Invoke explicitly.
argument-hint: "[PR numbers] [checkout dirs], e.g. '15740' or '15729 15742 . ../repo-2'"
disable-model-invocation: true
---

# PR pass

Target: `$ARGUMENTS`. Numbers are PRs, paths are checkout directories.
No PRs means every open PR the user authored in the current repo.
No directories means the current checkout alone.
Naming one PR of a stack pulls in the whole stack.

The main thread coordinates and never edits code.
Sonnet workers do the per-PR work, one PR per checkout at a time.
This skill owns the pass loop and the dispatch rules.
Per-PR work delegates to `change-review-apply` for reviews and `pr-stacking` for the
merge-forward rules; read those rather than restating them.
`pr-fleet` is the sweep-and-classify front end that hands its approved list here.

## Authority granted by invocation

Committing and pushing on the branches in scope, including the merge commits a sync
makes.
This overrides the push restrictions in the global rules and in `change-review-apply`.
It does not cover force-pushing, rebasing a branch an open PR depends on, touching any
branch outside the approved set, or flipping a PR's draft state.

## Pass 0: settle scope (once)

1. Check each directory: same `origin` as the others, `git status --porcelain` empty,
    no `MERGE_HEAD`, `rebase-merge`, or `CHERRY_PICK_HEAD` in its git dir.
    A dirty or mid-operation directory is probably the user or another agent.
    Report it and drop it from the pool; never clean, stash, or reset it.
    If `.jj/` exists, stop and ask, because the worker playbook assumes plain git
1. Run `${CLAUDE_SKILL_DIR}/scripts/status.py [PRs]` from one of the checkouts.
    It prints each unit (a stack bottom-up, or a single PR) and what every PR still
    needs: conflicts, commits behind its base, failed or pending checks, warning
    annotations, and reviews with open threads.
    Do not re-derive any of this with ad-hoc `gh` calls
1. Build the repo profile by reading the repo's `AGENTS.md`/`CLAUDE.md` and listing its
    project skills (`.claude/skills/`, `.agents/skills/`, or whatever the repo uses).
    Record, by what it does rather than by name:
    - the PR-writeup path: a repo script or skill that owns the PR summary comment, or
        `~/.config/my_config/ai-gh-pr.py` when there is none
    - skills for ordered artifacts a base merge invalidates (database migrations,
        changelog fragments, numbered fixtures)
    - the targeted-test command and the pre-push check skill, if any
    - commands the repo forbids (for example raw `gh pr comment`) and its branch rules
1. Assign each unit to one directory and keep it there for every pass, so the checkout
    stays warm.
    A stack never splits across directories.
    With more units than directories, queue them.
1. Show one table (unit, directory, what each PR needs) and the repo profile, then get a
    single approval with AskUserQuestion.
    From here the loop runs unattended, returning to the user only for questions.

Write the profile, the assignments, and the pass counter to
`$(git rev-parse --git-common-dir)/pr-pass.json` in the first checkout.
That file is the durable state, so a compaction loses nothing: re-read it at the start
of every pass instead of relying on memory.

## Each pass

1. Re-run `status.py --json` for the approved PRs.
    If `done` is true, stop and report.
    Stop too once four passes have completed
1. Dispatch per directory, bottom of each stack first.
    Each directory runs one worker at a time.
    Different directories run in parallel, so launch the first worker for every
    directory in one message, and start a directory's next PR as soon as its previous
    worker returns.
    The next PR in a stack is only ready once the one below it has pushed, since its
    sync merges that push
1. Worker prompt: `Agent` with `model: "sonnet"`, pointing at
    `${CLAUDE_SKILL_DIR}/references/worker.md` for the standing playbook, plus only that
    PR's status entry, its directory, the repo profile, and the pass number.
    Skip a PR whose entry is `done` and whose base did not move this pass
1. Collect each worker's report.
    Questions come back to you, never to the user directly: batch them into one
    AskUserQuestion per pause point, then act on the answers (post approved human-review
    replies with `ai-cr-review.py apply`, or `SendMessage` the worker to finish).
    A wrong conflict resolution costs far more than a question, so ask liberally
1. Append the pass's outcome to `pr-pass.json`: per PR, what was merged, fixed, pushed,
    and left open

## Between passes

Report the pass in a few lines: what moved, what is still red, what waits on the user.
Then say that this is a safe point to run `/compact`.
A built-in command cannot be run from inside a turn, so the user has to type it; the
state file is what makes that lossless.

Wait at least 15 minutes before the next pass, so CI and review bots can finish on the
pushes this pass made.
Start the wait as a background shell (`sleep 900` with `run_in_background`) and end the
turn; its completion re-invokes you.
Do not watch CI, arm a Monitor on checks, or poll `gh pr checks`.
The next pass's `status.py` run finds whatever CI and the bots turned up.

## Final report

The pass 0 table beside the final one, so the user sees what moved.
Then what is still open and why, anything waiting on a decision, and each escalation
with where it landed (ticket link or branch).
Lead with the lines that change the user's next action.
Delete `pr-pass.json` once the loop ends with every PR done; keep it when something is
still open, and say which.
