---
name: change-review
description: Write pull request review comments and replies to review threads in the user's voice, staged through the second-look CLI. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when preparing a review for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post.
The `second-look` skill owns the mechanics (commands, batch shape, what posts, what is
refused) and is generated from the binary, so read it before the first batch instead of
working from memory, and refresh it after an upgrade:

```sh
second-look skill > ~/.claude/skills/second-look/SKILL.md
```

This file is the half the binary cannot know: what to read, what to run, what to say,
and
in whose voice.
The CLAUDE.md prose rules apply.
Check drafts against `writing-voice`'s `voice-examples.md`, because short comments are
where its tics slip through (spatial verbs like "land" for plain facts, "too" with
nothing
named, a question with no proposed answer).

Related skills: `change-review-apply` actions a review someone left, and
`change-review-apply-retroactive` sweeps merged PRs for reviews nobody actioned.

## Queue and stacks

```sh
second-look inbox --json | jq -r '.[] | select(.bucket=="to review")
  | .items[]? | select(.draft==false) | "\(.repository)#\(.number)"'
```

Skip drafts. Parallelize across two or three full checkouts at most, one review each,
never a worktree, and leave a dirty tree alone because it is somebody's parked work.

`~/.config/my_config/ai-pr-stack.py <pr>` prints the stack bottom first.
`second-look get` every level and read them bottom up, since an upper diff excludes the
lower ones.
Stage each finding on the PR that introduces the code, once, and note the dependency in
the upper review.

## Before writing anything

Gather what the diff cannot show, for every level of the stack:

- The child ticket holding the real spec (walk down from the epic) and each acceptance
    criterion against the code
- The customer thread behind a support ticket, where scope and competing diagnoses get
    lost in Linear's one-line summary
- Whether a bot reviewed at all, since a non-default base, exhausted credits, or an
    unlinked account looks identical to a clean review.
    Say which in the review
- For an alarm, scheduled job, or monitor: what triggers it, which ref and target it runs
    against, and how far that lags.
    Trace each fallback to its end state
- Any gate or flag with a removal condition that already holds

Confirm every anchor outside the diff against the checked-out code, because bot and
subagent findings cite lines that do not exist.
`line` is post-image on `RIGHT`, pre-image on `LEFT`.

## Your own pass comes first

Read every source file in the diff yourself before opening a bot thread, and stage what
you find as top-level comments.
A review made only of replies to bots gives the user nothing to post beyond "LGTM".
Bots catch line-level mechanism bugs well, so look hardest at what they miss: one rule
decided in two places, an argument whose meaning shifts or that is silently ignored,
churn the change did not need, a skipped iteration that still consumes shared state,
comments and docs that break the repo's rules, and tests that restate a neighbor.
Ask whether an item belongs at all before correcting its fields.

In a batch, a subagent per PR told to ignore the bot threads works well.
Verify any premise you hand it, and give its findings the same attack pass as a bot's.
When your pass finds nothing, list what you checked in the review `note`.

## Every finding is a claim to break

Treat bot, subagent, and your own findings alike: try to refute each one first (the
caller that never passes the bad value, the guard upstream, the lock already held, the
helper that already caches).
Judge mechanism, severity, and fix separately, at the current head.
Record the verdict in the comment's `note`: `refuted`, `real but overstated`,
`real, fix wrong`, `confirmed by reading`, or `confirmed by running`.
Only `confirmed by running` supports a blocker or major on a behavior claim, and an
all-confirmed tally means re-arguing the weakest one.

Worth keeping even though they get dropped by default: a preserved bad behavior the
ticket asked to fix (say it predates the PR), a constraint met only by a library
default, and a question the code cannot settle (propose the experiment).

## Run behavior claims

A claim about behavior gets executed, using the cheapest thing that prints the answer:
one
targeted test (in irm `make test-<svc> EXP=…` or one Vitest file, never the whole
suite),
a scratch script, or the running app (`pr-previews`, `ui-verify`, or `run`).
Put the command and its output in the `note`, and when running was impossible, say why.
A red CI check is evidence only after you read its log
(`gh-lazydispatch export diagnose <run-id>`).

Tricks that worked in irm: subclass the PR's test class in a scratch file to reuse its
fixtures; reproduce a race by patching an awaited call between two phases to do the
competing write; run a flaky file several times with `--retry=0`, then the test alone.
Keep evidence outside the checkout, because `second-look get` refuses untracked files.
On macOS, a dead `make test-*` run can leave Postgres servers holding SysV shared
memory:
stop only `postgres -D` processes with parent PID 1 whose pytest is gone, never a
`.pgdata` dev database.

## Writing the comment

- Hedge the ask ("I think", "consider", a question with options), not the verdict.
    "I
    don't think this holds, because `sync_items` already takes the lock" still disagrees.
    A flat directive is only for the trivial and unarguable
- No praise or sign-off. The body says what you checked and found, and approving is the
    user's call
- Write for a peer: the observation and the ask, without the downstream consequence they
    would infer.
    Say what should happen
- Link the narrowest source and state its conclusion in one sentence instead of
    retelling it.
    Argue from why a rule exists, not its wording
- Audit every assertion in the hunk you opened, not only the one that prompted you
- Your own confusion is a finding worth reporting
- Name symbols, not `file:line`, and skip `(line ###)` cross-references unless genuinely
    ambiguous

## Replies and self-notes

A reply to a review on the user's PR acknowledges briefly, names the fix in one
sentence,
and adds a follow-up only if one exists.
A reply on someone else's bot thread must add something the thread lacks (a refutation,
a
corrected severity, a better fix, a run's output).
Mere agreement is a `skip`.
Point a thread a later commit or a higher PR already fixed at that fix instead of
restating it.
Preserve a leading `^` the user wrote on a bot reply, and never add or remove one.

A self-note on the user's own code states the non-obvious why, not what the diff shows.

## After posting, and later passes

Submitting turns posted comments into `skip` and can delete `pr-<n>.toml`.
Check `gh api repos/{o}/{r}/pulls/{n}/reviews` before treating that as loss, and ask
before re-staging a posted review, since the author would see it twice.
Keep the batch file for the session either way.

Once the user hand-edits a comment it is settled: fix anchors or facts, never rephrase.

On a merged PR, prove inline comments still anchor with a throwaway PENDING review
(`POST .../pulls/{n}/reviews` with `commit_id` and one comment, no `event`), delete it,
and frame the findings as follow-up considerations.
