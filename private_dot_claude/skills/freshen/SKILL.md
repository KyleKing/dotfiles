---

## name: freshen description: Freshens the repos listed in mani.yaml - syncs each with upstream, runs local gates, fixes CI on the default branch, and rolls template releases out to copier children. Arguments are a space-separated subset of repo names from mani.yaml; default is every repo. disable-model-invocation: true

# Freshen

Bring every target repo to a sound state: in sync with origin, local gates passing, CI
green on the default branch, and copier children on the latest template release.
The repo inventory is ~/Developer/kyleking/mani.yaml.

## Orchestration model

The main session thread is for coordination only: preflight, launching agents, the
disposition review, user questions, and the final report.
Everything else runs elsewhere:

- Per-repo work (Phase 1 assessment, Phase 3 soundness, Phase 4 child updates) goes to
    parallel subagents, one per repo, launched in a single batch per phase
- Waiting on CI or releases is never done by polling in the main thread.
    Give each repo's subagent its own watch loop, or arm a Monitor with an until-loop and
    keep coordinating
- Subagents return structured facts and terse action summaries, not logs.
    The .freshen.md files are the durable per-repo record; the main thread reads those
    instead of re-deriving state
- Sequencing constraint: template subagents must finish (tag verified) before their
    children's update subagents start.
    Non-template repos run in parallel with everything

## Authority granted by invocation

Invoking this skill authorizes, for the target repos only:

- committing (CC-style messages in the user's voice, no AI attribution, per global rules)
- pushing directly to the default branch
- rerunning GitHub Actions workflows

Every commit made under this skill sets `GIT_COMMITTER_NAME=freshen-bot` so a freshen
pass is greppable after the fact (`git log --format='%h %cn %s'`).
Author and both email addresses stay untouched: the commit still reads as Kyle's, the
ssh signature still verifies, and the committer email stays a verified address on his
GitHub account.

Everything else in the global CLAUDE.md still applies, especially minimal targeted
changes and root-cause fixes (never skip a failing test or widen a timeout without
understanding why it fails).

## Standing policies

- Staged-but-uncommitted files the agent did not create ride along in the freshening
    commit as-is.
    Never unstage or restore them. Exception: a pre-existing change set that looks
    mid-operation (a staged copier update, a half-applied refactor) is assumed incomplete.
    Verify what it was meant to do, and confirm with the user before committing it
- When fixing a copier child reveals a fix that belongs in the template (lint config
    drift, task-runner setup, CI workflow bugs), back-port it to the template first,
    release, then apply the new template version to the children.
    Child-local fixes that the template would overwrite on the next update are wasted work
- Ignore the content of doing.txt and roadmap/next-steps files.
    If one is staged, it commits along with everything else
- If a repo contains freshen.txt in its root, complete those instructions in addition to
    the normal steps
- Track per-repo actions in .freshen.md in that repo's root (globally gitignored, see
    Preflight).
    Each pass appends one `## <YYYY-MM-DD> · session <id>` heading followed by terse action
    lines, newest section at the top.
    The file persists across passes so a repo carries its own freshen history; never
    truncate it.
    The id is the first 8 characters of `$CLAUDE_CODE_SESSION_ID`, resolved once by the
    orchestrator and passed to every worker so all repos in one pass share it
- Concurrent-work guard: immediately before any commit, re-run `git status --porcelain`
    and compare against the state when work started.
    If files changed that the agent did not touch, stop that repo and flag it in the report
    instead of committing
- Parallel workers share one scratchpad directory.
    `copier update` refuses to run with untracked files present, so a worker that stashes
    something aside must use a path namespaced by its repo
    (`<scratchpad>/<repo-name>/doing.txt`, never `<scratchpad>/doing.txt`).
    Two workers moving same-named files to the same path will silently restore each other's
    content into the wrong repo.
    Prefer `git stash push -- <pathspec>` or a temporary `.git/info/exclude` entry over
    moving files out of the tree at all
- CI passing means the latest completed run of every non-Dependabot workflow on the
    default branch is green, checked via `gh run list --branch <default>`.
    A repo with no workflows is noted, not failed.
    A failure from transient infrastructure (network timeout, runner outage) gets one
    `gh run rerun --failed` before any code change
- Never push a CI fix that only addresses the one error CI happened to report first.
    A red job stops at its first failure, so the log names one instance of what is usually a
    class.
    Before pushing, run the failing command locally under the same conditions CI uses, then
    sweep the repo for every other instance of that class and fix them in the same commit:
    the same lint rule elsewhere, the same renamed API at its other call sites, the same
    missing pin in the sibling workflow.
    Say in the commit body only what the sweep found beyond the reported error, and only
    when that is non-obvious.
    Each avoided round trip saves a full CI cycle
- CI fix loop cap: if CI is still failing after three fix-and-push iterations and the
    newest failure has no crisply identified new root cause, stop and list the repo as
    follow-up.
    A distinct, provable root cause with an unambiguous fix justifies one more iteration;
    say so in the report
- Pushing a fix/feat commit triggers the Bump Version workflow, which pushes a `bump:`
    commit back to main.
    Expect non-fast-forward rejections: `git pull --rebase` then push again, and re-sync
    local after workflows finish
- Batch template fixes before pushing; every push cuts a release tag, and children should
    update once against the final tag, not per-fix.
    Batching is about pushes, not commits: prefer one commit per distinct fix so each is
    reviewable and revertable on its own
- Hooks that rewrite files (ctt renders, TOML re-sorting, formatters) turn a series of
    small commits into a series of fix-the-hook-churn commits.
    When making several commits that will be pushed together, commit the intermediate ones
    with `--no-verify`, then run the full hook suite once (`hk fix`, `prek run --all-files`,
    or the repo's fix task) before the final commit and push.
    Amend or add a cleanup commit for whatever the hooks rewrite.
    Never `--no-verify` a commit that is being pushed on its own, and never use it to
    sidestep a hook that is failing for a real reason

## Phase 0: Preflight

1. Confirm `.freshen.md` is in the global git excludes file
    (`git config --get core.excludesFile`).
    Add it if missing
1. Confirm `gh auth status` succeeds
1. Resolve the pass id: `${CLAUDE_CODE_SESSION_ID:0:8}`.
    Every worker prompt carries it, and every worker writes it into that repo's .freshen.md
    heading
1. Read mani.yaml for the target list. If args were given, restrict to those names
1. In each target repo, run `git remote set-head origin -a`.
    A dangling origin/HEAD (left by a deleted branch) breaks the hk pre-push commitizen
    check

## Phase 1: Assess (read-only)

Run `${CLAUDE_SKILL_DIR}/scripts/assess.sh [names...]` to gather the facts: local
presence, branch, ahead/behind, dirty counts, copier `_src_path`/`_commit`, template
flag, freshen.txt, archived flag, default branch, and latest CI conclusion per workflow.
It emits one JSON object per line; do not re-derive any of this with ad-hoc shell.

Interpretation:

- `exists_locally: false` goes to disposition (likely `mani sync`)
- `error: not found on GitHub` is an error to surface, not skip
- `archived: true` skips the repo entirely (but shows in the report)
- For each red CI conclusion, fetch the failing job's log tail
    (`gh run view --log-failed`) via a subagent before the disposition review

## Phase 2: Disposition review (one confirmation)

Present a single summary table: repo, state (branch, ahead/behind, dirty, CI), proposed
action.
Call out anything needing manual guidance:

- not on the default branch (ask: freshen the PR narrowly, or skip this pass?)
- missing locally or on GitHub
- archived (auto-skip, but show it)
- pre-existing staged changes that look mid-operation (for example a half-finished copier
    update)

Get one approval, then run unattended. Return to the user only for product decisions,
the concurrent-work guard, or the three-iteration cap.

## Phase 3: Make each repo individually sound

One subagent per repo, all launched together (parallel across repos, sequential within a
repo).
Keep each prompt short: point the agent at `${CLAUDE_SKILL_DIR}/references/worker.md`
for the standing playbook and paste in only that repo's assessment JSON plus its
approved disposition.
Agents watch CI with `${CLAUDE_SKILL_DIR}/scripts/wait-ci.sh <owner/repo> <sha>`
(blocking, prints per-workflow conclusions and a filtered failure tail) instead of
hand-rolled poll loops.
Each subagent owns its repo end to end and reports back a terse outcome:

1. Resolve local state per the approved disposition: pull if behind, commit dirty work with
    a sensible CC message, push if ahead
1. Discover and run the local gates: prefer a repo skill or CLAUDE.md instruction, else
    `mise tasks` / `./run --list` / hk.
    Fix what fails
1. Check CI on the default branch. Fix, push, and re-check, up to the iteration cap
1. Resolve open Dependabot alerts (`dependabot_alerts` in the assessment; details via
    `gh api repos/<slug>/dependabot/alerts?state=open`) with targeted upgrades:
    - If an open Dependabot PR fixes the alert and its checks are green, merge it
        (`gh pr merge --squash`) and pull, instead of duplicating the bump
    - Otherwise bump only the vulnerable module to the minimum patched version named in the
        advisory (Go: `go get <module>@<fixed-version> && go mod tidy`), never a blanket update
        of all dependencies
    - Transitive-only vulnerabilities that no release of the direct dependency fixes yet get a
        note in the report, not a forced replace directive
    - One `fix(deps):` commit per advisory (or per module when one bump clears several), gates
        re-run before each push
1. Log each action to .freshen.md

## Phase 4: Templates, then children

Order matters: a child should update against the template's newest release.

1. For each `*template*` repo: after Phase 3 it is pushed and green.
    Verify the release automation cut a tag for the new head (`git tag` vs `gh release list`
    or the Bump Version workflow).
    Rerun the workflow once if it failed transiently.
    If no tag appears, flag for the user
1. While reviewing template changes, note improvement opportunities: things the template
    got wrong, shared code children could adopt, and process friction worth fixing in the
    template itself.
    Put these in the final report rather than acting unilaterally
1. For each copier child (identified in Phase 1): invoke the copier-template skill to run
    the update against the latest tag, resolve .rej conflicts carefully, run local gates,
    commit, push, and watch CI per the iteration cap.
    Two .rej traps: each .rej holds LOCAL customizations that failed to re-apply, so a hunk
    that is pure local content (project docs, project config) must be re-applied by hand,
    while a hunk the new template already supersedes is discarded; and files listed in the
    template's `_skip_if_exists` are never updated by copier, so when a template change
    touches one (check the template diff), sync the child by hand from the template's
    `.ctt/default/` render
1. Non-template, non-child repos need nothing beyond Phase 3 and can proceed in parallel
    with this phase

## Phase 5: Report and per-repo follow-ups

Produce a table of initial state versus final state per repo (branch, ahead/behind, CI
before and after, template version before and after).
Follow with a numbered list of items needing the user, each with the repo, the blocker,
and the decision required.

Always also write each repo's follow-up items into that repo itself, so they survive the
session: doing.txt under a dated heading, or NEXT_STEPS.md where that is the repo's
convention, one line per item.
The chat report is the summary; the repo notes are the durable copy.

When template maintenance is committed in this repo's checkout of the template, also run
`hk fix` (or the repo's fix task) BEFORE the final commit: the hooks re-sort TOML and
strip blank lines, and committing first wastes an iteration on hook churn.
Re-run ctt after any hook fixes. Per the standing policy above, intermediate commits in
the batch can use `--no-verify` and let that one pass clean up after all of them.

Repo-specific gate notes worth knowing before you go looking:

- mdformat-plugin-template has no `hk.pkl`; it uses `prek` with `.pre-commit-config.yaml`.
    Shelling in without `mise x --` picks up the global mise env and fails
    `run-tox-test-min-in-ctt-default` with "No interpreter found for CPython 3.10"
- `.ctt/` output is a generated artifact, but copier's `_skip_if_exists` files silently
    never re-render into it once they exist.
    Any template change to such a file leaves the `.ctt` render stale, which also breaks the
    documented hand-sync path for children
