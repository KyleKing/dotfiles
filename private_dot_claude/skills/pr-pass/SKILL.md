---
name: pr-pass
description: Work a set of PRs (stacked or not) to green in repeated passes. Each pass merges the latest base, actions reviews, fixes CI, pushes, and cascades up any stack, with Sonnet workers running one PR at a time per checkout. Stops after four passes or once every PR is green with nothing left to action. Invoke explicitly.
argument-hint: <all|non-draft|PR numbers> [plain-text instructions, dir globs to use or skip], e.g. 'all overnight' or '15729 15742 irm-1-* skip irm-2-*'
disable-model-invocation: true
---

# PR pass

Target: `$ARGUMENTS`.
The first word selects PRs: `all` is every open PR the user authored, `non-draft` drops
units with no ready PR (`status.py --non-draft`), and numbers name PRs.
Naming one PR of a stack pulls in the whole stack.
The rest is plain text: instructions that bind the whole run (for example "overnight",
"max 2 passes") and globs or paths of directories to use or skip.

Directories come from where the skill runs.
From inside a checkout with no directory named, the pool is that checkout alone.
From a parent of several checkouts, every child git checkout is a candidate: group them
by `origin`, and each repo with open PRs by the user becomes its own pool, narrowed by
any use or skip globs.
Repos run in the same passes, each directory staying inside its own repo.

The main thread coordinates and never edits code.
Sonnet workers do the per-PR work, one PR per checkout at a time.
This skill owns the pass loop and the dispatch rules.
Per-PR work delegates to `change-review-apply` for reviews and `pr-stacking` for the
merge-forward rules; read those rather than restating them.
`pr-fleet` is the sweep-and-classify front end that hands its approved list here.

## Authority granted by invocation

Committing and pushing on the branches in scope, including the merge commits a sync
makes.
In an unattended run, it also covers prepending a blockers block to a PR's description
(see Unattended runs).
This overrides the push restrictions in the global rules and in `change-review-apply`.
It does not cover force-pushing, rebasing a branch an open PR depends on, touching any
branch outside the approved set, or flipping a PR's draft state.

## Pass 0: settle scope (once)

1. Check each directory: same `origin` as the rest of its pool, `git status --porcelain`
    empty,
    no `MERGE_HEAD`, `rebase-merge`, or `CHERRY_PICK_HEAD` in its git dir.
    A dirty or mid-operation directory is probably the user or another agent.
    Report it and drop it from the pool; never clean, stash, or reset it.
    If `.jj/` exists, stop and ask, because the worker playbook assumes plain git
1. Run `${CLAUDE_SKILL_DIR}/scripts/status.py [PRs] [--non-draft]` from one checkout
    per repo.
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
    - which targeted-test commands need Docker, and which checkouts already have a
        running stack (`docker ps`), since a hot stack is the cheapest place to test
    - per-checkout env the Docker targets depend on (`COMPOSE_ID` from
        `mise.local.toml`, for instance) and how a non-interactive shell gets it
        (`mise exec --`), because worker shells do not load it
    - which hook steps are memory-heavy (typecheckers such as tsgo or pyright) and
        whether they run at commit, push, or both, so the report can say what the
        heavy-job lock is serializing
1. Assign each unit to one directory and keep it there for every pass, so the checkout
    stays warm.
    Classify each PR by the paths it touches (`gh pr diff --name-only`): a PR is a Docker
    PR when its targeted tests need Docker.
    Queue every Docker PR sequentially in at most two Docker directories, hot stacks
    first, so builds stay warm and at most two stacks ever run; every other directory is
    Docker-free and takes the rest.
    A longer Docker queue is the accepted cost.
    A stack stays in one directory, except that its Docker PRs may move to a Docker
    directory; they still start only after the PR below has pushed.
    With more units than directories, queue them, balancing PR count per directory.
1. Show one table (unit, directory, what each PR needs) and the repo profile, then get a
    single approval with AskUserQuestion.
    From here the loop runs unattended, returning to the user only for questions.

Write the profile, the assignments, and the pass counter to
`$(git rev-parse --git-common-dir)/pr-pass.json` in the first checkout of each repo.
That file is the durable state, so a compaction loses nothing: re-read it at the start
of every pass instead of relying on memory.
Beside it, write `pr-pass-rules.md`: the authority line, the heavy-job rule, the Docker
lanes (which directories may use Docker, only their own stack), the unattended rule when
it applies, known CI noise, and the repo profile.
Record the lanes in `pr-pass.json`; a directory added mid-run is re-laned the same way.
Every worker prompt points at that file rather than restating it.

## Resource-aware dispatch

Before dispatching each pass, check machine health, not just the approved-PR list:
`uptime` (1-minute load average against `sysctl -n hw.ncpu` cores) and free memory
(`vm_stat`, or `memory_pressure -Q` if available).
A 1-minute load average past
roughly 1.5x the core count, or memory that's tight enough to be swapping, means the
machine is already saturated — often a stuck job (check `lockq.sh` for a holder past
~20 minutes) or simply too many Docker stacks and dev servers running at once
(`docker ps`, `docker stats --no-stream` show which).
A single wedged command can hold the
heavy-job lock for hours and stall every lane behind it without any single process
looking like a runaway on its own — check wall-clock time held, not just CPU%.

When the machine is saturated, cut back on the intensive lanes rather than piling on
more: run only one Docker lane's worker this round (queue the other Docker
directory's next PR for the following pass) while still dispatching every no-docker
directory's worker as normal — those don't touch the heavy-job lock's Docker slot and
stay cheap.
Re-check at the start of the next pass and every time `lockq.sh` or a
worker's report suggests things are slow; resume the normal two-Docker-lane cap once
load has settled.
Never spin up a Docker stack "just to keep it warm" while load is
already high — an idle stack a lane isn't actively using is a candidate to stop, not
a reason to add a third.

## Each pass

1. Re-run `status.py --json` for the approved PRs.
    A PR behind trunk with nothing else open counts as done (squash merge needs no
    sync), and a test annotation on a file outside the PR's diff is not the PR's.
    New PRs the user opened mid-run stay out unless the user adds them.
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
    PR's status entry, its directory, `pr-pass-rules.md`, the pass number, and what the
    PR below it just pushed.
    Skip a PR whose entry is `done` and whose base did not move this pass.
    The heavy-job rule in the rules file is what stops parallel hook typecheckers from
    several checkouts exhausting the laptop's memory, so never drop it from that file
1. While workers run, `${CLAUDE_SKILL_DIR}/scripts/lockq.sh` shows the heavy-job lock's
    holder and queue.
    Check it whenever a worker reports waiting for long.
    A holder past about 20 minutes is suspect: inspect it (container CPU and memory,
    whether the database is doing work) and kill a run that is thrashing, then send its
    worker narrower targets.
    If `lockq.sh` alone looks clear but things still feel slow, re-run the
    Resource-aware dispatch check above — overall load can be high with no single
    holder to blame
1. Collect each worker's report.
    Questions come back to you, never to the user directly: batch them into one
    AskUserQuestion per pause point, then act on the answers (post approved human-review
    replies with `ai-cr-review.py apply`, or `SendMessage` the worker to finish).
    A wrong conflict resolution costs far more than a question, so ask liberally.
    In an unattended run, questions become blockers instead (below)
1. Append the pass's outcome to `pr-pass.json`: per PR, what was merged, fixed, pushed,
    and left open

## Unattended runs

When the instructions say the run is unattended ("overnight", "while I'm away"), never
pause on AskUserQuestion after pass 0.
A question that blocks a PR goes at the top of that PR's description instead, written in
the user's voice as a short list of what is blocked and the decision needed:
`${CLAUDE_SKILL_DIR}/scripts/blockers.py set <pr> --file <md>` from a checkout.
It replaces any earlier block in place and leaves the rest of the body untouched.
This is the one sanctioned edit of a PR body, overriding the global and repo rules
against editing descriptions or raw `gh pr` calls, and it covers nothing else.
Keep working everything on that PR the question does not block.
On later passes, read the block and any replies first.
If the user answered, act on it and run `blockers.py clear <pr>` once nothing is left.
Otherwise leave it and do not re-ask.

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
