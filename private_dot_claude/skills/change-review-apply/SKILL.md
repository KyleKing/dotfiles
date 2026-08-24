---
name: change-review-apply
description: Pull the latest CodeRabbit review's "Prompt for all review comments with AI agents" block off a PR and action it — adversarially verifying each finding, fixing the whole class of problem rather than the cited lines, committing incrementally, and replying, resolving, and thumbs-upping the review. Use when asked to apply, address, or action CodeRabbit comments.
---

# Apply a CodeRabbit review

CodeRabbit posts one review per push, and its body carries a collapsed
`🤖 Prompt for all review comments with AI agents` block listing every finding in one
place.
`~/.config/my_config/ai-cr-review.py` (call it by absolute path) reads that block, joins
each finding to the thread it came from, and posts the verdicts back.
Your job is steps 2 through 6: decide what is real, escalate what's out of scope, fix
what's in scope, commit, and write the replies.

## Step 1 — Fetch the work list

```sh
~/.config/my_config/ai-cr-review.py fetch > cr-review.json     # add --pr N for another PR
```

The script picks the newest CodeRabbit review whose body has a prompt block, so a push
that produced no findings is skipped without you walking reviews by hand.
Pass `--review-id` to action an older one (a push landed before anyone actioned the
previous review), or a human or non-CodeRabbit bot review: one with no prompt block
turns every open thread tied to it into a finding directly, using the thread's own
comment as the prompt.

Before acting on that review, check whether an older one is still open:

```sh
~/.config/my_config/ai-cr-review.py status     # add --pr N for another PR
```

This lists every review, bot or human, that has no thumbs-up and still carries an
unresolved thread or a CHANGES_REQUESTED verdict.
A non-empty result means a review got
buried under a later push; action the oldest un-acked one first (`--review-id`), then
come back to the newest.
An entry with `open_threads: 0` has no thread to reply into
(general feedback in the review body, not an inline comment) — its text comes back
quoted in `body`; read it and note it in the report, there is nothing to resolve.

Read these keys before starting:

- `findings` — the work list, each with `thread_id`, `comment_id`, `path`, `start`/`end`,
    and a `prompt` (CodeRabbit's synthesized text, or the raw comment body when the
    review has no prompt block)
- `body` — the review's own text, always present.
    General feedback with no thread lands only here; note it in the report, there is
    nothing to resolve
- `outside_diff` — findings CodeRabbit raised outside the diff.
    Real work with no thread to reply to or resolve; goes through Step 3's escalation
    unless the file is already in the PR's diff, in which case Step 4 fixes it directly
    (see Step 3)
- `unmatched_findings` and `unclaimed_threads` — a block item with no thread, or a thread
    no item claimed.
    Read the thread on GitHub before deciding: if it's just the anchor drifting after an
    unrelated edit (see Step 3), it needs nothing; a real finding in a file the PR already
    touches goes through Step 4 like any other verified finding; otherwise it goes through
    Step 3's escalation like any other real, out-of-scope finding
- `unparsed_prompt_lines` — CodeRabbit changed the block format.
    Stop and report it
- `other_open_threads` — open threads from earlier reviews.
    Out of scope for this pass, but a real one still goes through Step 3

**The PR branch is usually not the checked-out `HEAD`.** `branch.worktree` is where it
lives, or `null` when no worktree has it.
`cd` there before editing; never fetch the
branch into the current tree and edit alongside unrelated work.
If that worktree has uncommitted changes you did not make, stop and report it (see the
working-tree rule in `CLAUDE.md`).

## Step 2 — Verify each finding adversarially

CodeRabbit reasons about a diff snapshot and is confidently wrong often enough that
applying its prompt verbatim regresses code.
For every finding, read the current file and pick the verdict:

- `fixed` — reproduce the failure in your head or in a test first.
    State the concrete input or interleaving that breaks.
    If you cannot, it is not yet real
- `stale` — a later commit already fixed it.
    Cite the commit or line
- `wrong` — the premise misreads the code (a guard it did not see, a caller that cannot
    pass that value, a library contract it assumed).
    Give the specific reason
- `policy` — the fix conflicts with the repo's `AGENTS.md`/`CLAUDE.md` or a project skill.
    CodeRabbit is fond of suggestions this rules out: explanatory inline comments,
    docstrings on private helpers, layering violations, hand-rolled versions of a shared
    component.
    Do the policy-compliant equivalent and mark it `fixed`, or skip it as `policy`

Push back hardest on findings that ask you to widen scope for its own sake: version
pinning, extra abstraction, "add a contract test" for behavior a real test already
covers.
Those are often busywork. Where a finding names a security or data-loss risk, treat it
as
real until you have disproved it.

## Step 3 — Escalate what's out of scope, don't just note it

`outside_diff`, `unmatched_findings`, `unclaimed_threads`, `other_open_threads`, and any
Step 2 finding that names a real defect in a file this PR doesn't touch all share the
same failure mode: dropped into a report, they don't get revisited.
Once Step 2's verdicts are in, collect every one of those that is still real and ask the
user once, with the whole list, whether each becomes a Linear ticket or lands on a
branch (a follow-up commit here, a branch stacked on this one, a branch off main).
That choice is the user's engineering-scope call, not this skill's.
Check for an existing ticket or thread on the same defect first and link that instead of
proposing a duplicate.

Don't escalate line drift. A finding lands in `unmatched_findings` or
`unclaimed_threads` most often because its anchor moved after an unrelated edit in the
same push, not because it's new: expect this to happen frequently, and treat a thread
marked outdated (`is_outdated: true`) as resolved by the edit that moved it rather than
something to escalate or reply to.

Don't escalate a small, real fix in a file this PR already touches just because it has
no thread.
`outside_diff` and the unmatched buckets mean "no thread to reply to," not
"out of this PR's scope" — a nitpick CodeRabbit filed against a file this branch is
already changing goes through Step 4 like any other verified finding: fix it, commit it,
and let Step 6's thumbs-up close it out with no reply posted (there is no thread).
Only
route it to Step 3's escalation ask when the file itself sits outside the PR's diff, or
the fix is large enough to want its own review.

## Step 4 — Fix the class, not the line

CodeRabbit cites the instances it happened to look at.
Fix every instance of the same defect inside the PR's diff, then say what you widened
and
why:

- the bare `except:` it flagged at one call site, and the three siblings in the same
    module
- the missing `await`/cancellation guard on one path, and the other paths through the same
    executor
- one unbound exception variable, and every other swallowed exception in the file
- a test fake that does not mirror the real guard, and the other fakes in that test module
    that drift the same way

Stay inside the PR's scope for this edit.
A defect in a file this PR does not touch went
through Step 3, not a same-PR fix.

## Step 5 — Commit and validate

Commit incrementally, one logical fix per commit, Conventional Commits with a
capitalized
summary.
Do not push — the user reviews and pushes.
The exception is a `pr-fleet` run, which authorizes pushing the branches in its approved
plan.

Run the narrowest test for what you touched as you go, then the repo's full
format/typecheck/test ladder once over the combined diff (in the platform repo, the
`pre-pr-qa` skill picks the right gates).
Report failures verbatim; never call a finding fixed on the strength of the edit alone.

## Step 6 — Post the verdicts

Write one action per finding into `pr-<number>-cr-actions.toml` in the worktree, show it
to the user, and apply it once they approve:

```toml
review_id = 4910562275

[[actions]]
thread_id = "PRRT_..."
verdict = "fixed"

[[actions]]
thread_id = "PRRT_..."
verdict = "wrong"
reply = "The guard above already rejects None, so this path cannot raise."
```

```sh
~/.config/my_config/ai-cr-review.py apply --file pr-13942-cr-actions.toml
```

Every finding ends replied-to as needed, resolved, and the review body thumbs-upped once
the whole set lands.
The script refuses the batch outright, before posting anything, when a `thread_id` does
not belong to that review, a finding has no verdict, or a skipped finding carries no
reply.
A reply is optional for `fixed` and required for the three skip verdicts, so a rejected
finding always leaves a public reason.
Default to skipping the `fixed` reply: the diff already shows the fix, so restating that
is noise CodeRabbit doesn't need.
Add one only when the fix isn't visible in the file CodeRabbit flagged, e.g. it landed
in
a shared helper instead.
Replies are written in the user's voice under the `change-review` skill's rules: hedged,
one sentence naming the change, no re-explaining the bug.

Only run `apply` after the fixes are committed.
The 👍 on the review body is the signal
that the whole review was actioned, so it lands last and never lands at all if any
thread
failed.

When every real finding was a threadless one fixed under Step 3's carve-out (nothing in
`findings` needs a verdict), the actions file carries no `[[actions]]` at all — just
`review_id`.
`apply` still validates (an empty `findings` list has nothing to check
actions against) and posts the thumbs-up with `0 actioned`.

## Report

Lead with the review id and a one-line-per-finding verdict table, then the broader fixes
you added beyond the block, then what Step 3 escalated and where it landed (ticket link
or branch), then the gate results.
Keep it to the lines that change the user's next action.
