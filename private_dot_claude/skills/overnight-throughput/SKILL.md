---
name: overnight-throughput
description: Keep an unattended orchestration session (overnight lanes, PR landing, subagent dispatch) productive. Use at the start of any multi-hour session that coordinates subagents across checkouts, and every time a turn is about to end while work is still pending.
---

# Overnight throughput

Wall-clock time goes to waiting on CI, merge queues, reviews, and agents.
The fix is to never
wait on one thing while other work is available.

## Applies all day, not only overnight

Daytime sessions get the same rule: a free lane gets work, and nothing waits on a review
or
CI while the lane is idle.
The one limit is the laptop. Before starting another agent, check
load and memory (`uptime`, `vm_stat`, or Activity Monitor) and cap concurrent local
gates
(`mise run ci`, e2e browsers, Docker-free test shards) at what the machine carries.
When it is
strained, finish a running gate before starting a new one, and run read-only or
review-wait
work in the idle lanes.
Never kill a user's processes to make room.

## Triage load before blaming the agents

Run this at the start of the session, before each new dispatch, and whenever load stays
above
the core count (`sysctl -n hw.ncpu`):

1. `uptime`, then `ps -Ao pid,ppid,pcpu,pmem,etime,comm -r | head -25` and the same sorted
    by
    memory (`-m`).
1. Sort what you see into three groups. Test fan-out under a lane (pytest-xdist workers,
    test
    Postgres servers, Playwright or Camoufox browsers) is expected: wait for the gate to end
    and cap new ones.
    System daemons (`fseventsd`, `mds`, endpoint-security agents) are not
    ours: report, never touch.
    An orphan (PPID 1, long `etime`, high CPU) is the suspect.
1. Before killing an orphan, prove it is ours and idle: `ps -p PID -o lstart,command`, then
    `lsof -p PID` for its cwd and any output file.
    It qualifies only when it writes to this
    session's task directory (or a path under a lane this session owns) AND its parent task
    is stopped or finished.
    A `python3 -` reading a deleted stdin file after a stopped
    background task is the usual case.
1. Send SIGTERM, recheck after a moment, and use SIGKILL only if SIGTERM failed.
    Never kill
    a process owned by another session, the user's own tools (browser, editors, `claude`),
    or anything you cannot trace to this session.
    Ask via `AskUserQuestion` instead.
1. Fix the cause. A background loop must stop on its own exit condition, so give every
    `Monitor` and `run_in_background` loop a bounded count or deadline.
    Stopping the task
    does not always stop its children.
1. At session end, list orphans (`ps -Ao pid,ppid,etime,command | awk '$2==1'`) and clear
    the ones you made.

Never run the full local gate (`mise run ci`, a full irm suite, `make` targets that wrap
them).
Each one fans out to about one xdist worker and one test Postgres per core, and three
at once reached a load of 102.
The pre-commit hooks (`hk`) catch most issues at commit time
and GitHub CI runs the whole suite, so:

- Run only targeted tests for what the change touches (`pytest path::test -n 0`, one file,
    or one `-k` expression), plus the type check of the touched package if it is quick.
- Commit normally so `hk` runs. Never `--no-verify`.
- Push, then check CI later with `gh pr checks N` and a `Monitor` until-loop.
    Do other work
    meanwhile (the lane-swap rule above).
    Read a failure with `gh run view --log-failed`
    filtered to the failing test, and fix forward with a targeted rerun.
- Tell each agent this in its brief. A brief that says "run `mise run ci`" is wrong.

Watch the shared GitHub budget. One token serves every agent, `gh` REST allows 5,000
calls an
hour, and a 30 s poll across six agents spends it by itself (it hit 0 at 15:23Z on
2026-10-30).
Poll at 60 to 120 s, prefer one `gh pr list --json ... --jq` over per-PR calls,
check `gh api rate_limit` (free) before a burst, and tell each agent to wait for the
reset
instead of retrying a 403.
GraphQL has its own bucket and is a fallback for reads.

Pace dispatch by merge throughput: CI and the merge queue cap landings, and agents told
to
"get it merged" re-queue the same change in a loop.
Queue a PR once, then do other work.

## Keep a goals file and revisit it

Keep one markdown file of the high-level goals in the orchestrating directory's
`ai-output/`
(`<YYYY-MM-DD>-overnight-goals.md`): goal, status, next action, owner, then Waiting on
Kyle,
Done, and a dated Log.
Read it every few turns and before reporting.
Update status and
Done as agents report.
A goal with no movement across two revisits gets a new owner, a
smaller next step, or a question to the user.
A progress report that cannot point at the
file's status changes means the board was not worked.

## Every turn ends with a full board

Before ending a turn, list the lanes and the standing asks.
Each free lane gets an agent, and
each standing ask gets an owner or a dated reason it waits.
A turn that ends with a free lane
and unstarted work is a miss.

1. `ListAgents` and `git status` per allowed lane.
    Free means clean tree and no live agent.
1. Pending queue: open PRs, unstarted standing asks (health checks, irm PRs to open for
    the user, captures, triage replays), and planned follow-up PRs.
1. Dispatch one agent per free lane for the highest-value independent item.
1. Only then report, in a few lines.

## Parallelize by dependency, not by narrative order

- Anything with no input from the audit, review, or earlier PR starts now in its own lane.
    A
    pure module (parser, compiler, data layer) does not wait for the UI audit.
- A stacked PR can be built while its parent is in review.
    Merge forward when the parent lands.
- Read-only audits (Chrome, logs, prod health) run beside builds, never before them.

## Never wait by stopping

- Waiting for CI or a queue is a background poll (`Monitor` with an until-loop, or the
    agent's
    own watch), not the end of the turn.
    Do other work meanwhile.
- When a notification says an agent is "waiting on its own background work", that result
    is
    interim.
    Dispatch the next item rather than idling.
- Check merge state with one summarizing `gh pr list --json ... --jq` call across all PRs,
    not
    one call per PR.

## Landing recipes (stop rediscovering them)

- Plain PR: `gh pr merge N --auto` (the queue picks the method).
- Stacked PR (own base is a PR branch, or another PR is based on it): auto-merge is
    refused.
    `gh api -X PUT repos/O/R/pulls/N/merge-async -f merge_action=merge_queue`.
- Admin bypass of a stacked or blocked PR: same endpoint with
    `-f merge_action=direct_merge -F bypass_rules=true`.
    Valid actions are only `default`, `direct_merge`, `merge_queue`.
- The `merge-async` bypass can sit "enqueued" forever on a PR whose stack is out of date
    (the merge box says "Rebase stack" and "Unable to merge").
    After one retry, stop and use
    Chrome: open the PR, tick "Merge without waiting for requirements (bypass rules)", click
    "Bypass rules and merge (squash)", then confirm.
    Check the commit message carries no
    attribution first.
    An unstacked PR takes `gh pr merge N --admin --squash`.
- A red check whose log shows a 5xx from a vendor service: `gh run rerun RUN --failed`,
    once.
- A stale-branch test failure: merge main forward (no rebase), rerun the narrow test.

## Keep a lane working while a review runs

The first WD review of a PR is a deep pass and takes up to about 30 minutes.
Later rounds on
a small push take about 7.
Do not hold a lane idle through either.

- After the push and the AI Summary, the same agent commits nothing further on that
    branch,
    leaves the tree clean, and switches to the next branch in its lane (`git switch` a
    clean tree only).
    Use that time for the next PR in the plan, a stacked child, or a
    retroactive sweep.
- One agent owns the lane at a time, so branch swaps are serial and safe.
    Never start a
    second agent in the same checkout, and never swap with a dirty tree.
- Check back on a schedule that matches the pass: about 30 minutes after the first push,
    and
    about 7 after a fix push.
    Use a `Monitor` until-loop on the review landing
    (`gh api repos/O/R/pulls/N/reviews`), not a fixed sleep.
- When the review lands, switch back, run `change-review-apply` (an approval can still
    carry findings), push the fix, and expect the faster round.
    Resolve and merge on the
    green second round rather than starting a third.
- Record the branch, the lane, and the expected return time in the agent's final message
    so
    the orchestrator knows the lane is working, not idle.

## Brief agents for a finish, not a handoff

- Every brief carries two hard lines.
    Never merge or queue an irm PR, or a PR in a repo Kyle did not name, without his
    explicit OK in this session.
    Never dispatch, rerun, or cancel a prod deploy by hand: fix the cause and let the
    next push deploy
- One agent per lane, working a queue of PRs: branch to green CI to AI Summary, then swap
    branches while the review runs (see above).
    Say "do not merge", and merge from here.
- Give the agent the audit findings and file paths inline so it starts without
    rediscovery.
- Sonnet at medium effort by default. Opus only for audits or design that need depth.
- Tell each agent: no full local CI, targeted tests only, let `hk` and GitHub CI do the
    rest.
- Ask each agent to end by reporting only what changes the next action.

## Offload to Watch Doggo codegen and triage, then critique what comes back

Idle lanes are not the only capacity. Watch Doggo builds and triages on its own, so hand
it
work that is well specified and low risk, and spend local agents on what it cannot do.

- Codegen: delegate a Linear issue that names the repo and states the defect and the
    invariant, or use "Send a spec" (`send_spec`).
    Delegating is the go-ahead and starts a
    build.
    Good fits: small follow-ups from a review's unchecked boxes, doc drift, test gaps,
    a fix with a clear alarm or log line behind it.
    Poor fits: security, IAM, or design
    calls (those stay local or go to the user).
- Triage: send a firing alarm or a vague error to WD triage (HQ on-call page) before
    investigating by hand.
    Compare its answer with your own read of the logs.
- Before filing a "gap" or an offload, read the owning package's `AGENTS.md` and the
    ticket for a rule that makes it intentional, and prove the premise (a log line, a run
    page).
    An unproven premise is a question for the user, not a ticket for WD.
- Mined outcomes mix findings from before and after fixes shipped.
    Before building from a
    mined report, slice its examples by the merge date of the rule it blames and check the
    code at `main` for the check it asks for.
    A third of one report's build items already
    existed.
- Every offload gets a critique when the output lands: was the cause proven with evidence
    (a log line or trace), is the PR the simplest fix, did it answer its own review, how
    long
    and how much did it cost, and what did it get wrong or skip.
    Treat its PR like any
    unfamiliar PR (next section).
- Record each offload in `ai-output/<YYYY-MM-DD>-wd-offload-actions.md`: the ticket or
    spec
    link, the PR or triage page link, the critique, and action items as `- [ ]` lines that
    each link the exact comment, diff line, run page, or ticket they come from.
    Action items
    become the next offload or local task, so the file feeds the board.

## Design principles for every change and every review

DRY, KISS, and YAGNI hold broadly, for code written here and for PRs reviewed here.

- DRY: one fact lives in one place. Grep for the value and the name before adding a
    constant, rule, list, or prompt, and import the copy that exists.
    Code that looks alike
    but changes for different reasons can stay separate.
- KISS: the simplest shape that works. One decision gets one path.
    Count the states, layers,
    and writers to one value a reader must track, and cut what a measurement does not need.
- YAGNI: build for a caller that exists today.
    No flag, option, fallback, or abstraction
    without a named condition that retires it.
- In a brief, state the problem and the invariant and leave the shape to the agent.
    In a
    review, name a violation with the simpler alternative and its tradeoff.
- Net lines are a signal: a change that deletes duplicates or dead paths is worth more
    than
    one that adds a layer.

## Review unfamiliar PRs adversarially, and judge WD's review the same way

An approval, a green CI, or a plausible AI Summary settles nothing.
For a PR you did not
write or follow, push back on three layers before landing it:

1. Premise: is the problem real, and does the evidence in the PR prove it?
    Check the log
    line, ticket, or alarm it cites.
1. Design: is there a simpler shape (KISS), an existing reference implementation (DRY),
    or a smaller scope (YAGNI)?
    Name the alternative and its tradeoff.
1. Implementation: read the diff for the cases the tests skip (pagination, 5xx, empty,
    permissions, concurrency, stale heads) and for tests that assert nothing.

Hold WD's review to the same standard. After each review, record in
`ai-output/<YYYY-MM-DD>-wd-review-quality.md` (the orchestrating directory's
`ai-output/`,
one entry per PR) with direct links to the review, the comment or finding, the diff
line, and
any screenshot or recording:

- findings that were incorrect, and why
- defects WD missed that a person or agent later found
- how the review presents images and text: does the screenshot show the claim, is the
    annotation readable, is the summary scannable, is the evidence linked or only described
- a concrete change to the reviewer prompt, checks, or presentation

## Reporting

Report outcomes in a few lines: merged, in flight, blocked and why, next.
Don't recount the
plan or restate unchanged state.
If the user asks about progress and the answer is thin, the
board was not full: fix that first, then answer.
