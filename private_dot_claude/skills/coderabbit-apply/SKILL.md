---
name: coderabbit-apply
description: Pull the latest CodeRabbit review's "Prompt for all review comments with AI agents" block off a PR and action it — adversarially verifying each finding, fixing the whole class of problem rather than the cited lines, committing incrementally, and replying, resolving, and thumbs-upping the review. Use when asked to apply, address, or action CodeRabbit comments.
---

# Apply a CodeRabbit review

CodeRabbit posts one review per push, and its body carries a collapsed
`🤖 Prompt for all review comments with AI agents` block listing every finding in one
place.
`~/.config/my_config/ai-cr-review.py` (call it by absolute path) reads that block, joins
each finding to the thread it came from, and posts the verdicts back.
Your job is steps 2 through 4: decide what is real, fix it, and write the replies.

## Step 1 — Fetch the work list

```sh
~/.config/my_config/ai-cr-review.py fetch > cr-review.json     # add --pr N for another PR
```

The script picks the newest CodeRabbit review whose body has a prompt block, so a push
that produced no findings is skipped without you walking reviews by hand.
Pass `--review-id` to action an older one, which is the case when a push landed before
anyone actioned the previous review.

Read these keys before starting:

- `findings` — the work list, each with `thread_id`, `comment_id`, `path`, `start`/`end`,
    and CodeRabbit's `prompt`
- `outside_diff` — findings CodeRabbit raised outside the diff.
    Real work, but there is no
    thread to reply to or resolve, so they belong in the report instead
- `unmatched_findings` and `unclaimed_threads` — a block item with no thread, or a thread
    no item claimed.
    Both mean the join is incomplete: read the thread on GitHub and say so
    in the report rather than acting on a guess
- `unparsed_prompt_lines` — CodeRabbit changed the block format.
    Stop and report it
- `other_open_threads` — open threads from earlier reviews, out of scope unless the user
    says otherwise

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

## Step 3 — Fix the class, not the line

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

Stay inside the PR's scope. A defect in a file this PR does not touch is a follow-up
note,
not an edit.

## Step 4 — Commit and validate

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

## Step 5 — Post the verdicts

Write one action per finding into `pr-<number>-cr-actions.json` in the worktree, show it
to the user, and apply it once they approve:

```json
{
  "review_id": 4910562275,
  "actions": [
    {
      "thread_id": "PRRT_...",
      "verdict": "fixed"
    },
    {
      "thread_id": "PRRT_...",
      "verdict": "wrong",
      "reply": "The guard above already rejects None, so this path cannot raise."
    }
  ]
}
```

```sh
~/.config/my_config/ai-cr-review.py apply --file pr-13942-cr-actions.json
```

Every finding ends replied-to as needed, resolved, and the review body thumbs-upped once
the whole set lands.
The script refuses the batch outright, before posting anything, when a `thread_id` does
not belong to that review, a finding has no verdict, or a skipped finding carries no
reply.
A reply is optional for `fixed` (the diff shows the fix) and required for the three skip
verdicts, so a rejected finding always leaves a public reason.
Replies are written in the user's voice under the `change-review` skill's rules: hedged,
one sentence naming the change, no re-explaining the bug.

Only run `apply` after the fixes are committed.
The 👍 on the review body is the signal
that the whole review was actioned, so it lands last and never lands at all if any
thread
failed.

## Report

Lead with the review id and a one-line-per-finding verdict table, then the broader fixes
you added beyond the block, then `outside_diff` items and anything the join could not
match, then the gate results.
Keep it to the lines that change the user's next action.
