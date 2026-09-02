---
name: change-review-apply
description: Action a PR review — CodeRabbit's, another bot's, or a teammate's — by adversarially verifying each finding, fixing the whole class of problem rather than the cited lines, committing incrementally, and replying, resolving, and thumbs-upping the review. Use when asked to apply, address, or action review comments, whoever left them.
---

# Apply a PR review

`~/.config/my_config/ai-cr-review.py` (call it by absolute path) reads a review's
findings, joins each to the thread it came from, and posts the verdicts back.
A CodeRabbit review's findings come from the collapsed
`🤖 Prompt for all review comments with AI agents` block in its body; any other review,
bot or human, has no such block, so every open thread tied to it becomes a finding with
the thread's own comment as the prompt.
Your job is steps 2 through 6: decide what is real, escalate what's out of scope, fix
what's in scope, commit, and write the replies.

**A bot's review is yours to close out; a person's is not.** Post and resolve a bot's
threads without asking.
On a human's review, resolve and thumbs-up freely, but a *reply*
goes out only after they say yes — Step 6 has the mechanics.

## Step 1 — Fetch the work list

```sh
~/.config/my_config/ai-cr-review.py fetch > cr-review.json     # add --pr N for another PR
```

The script picks the newest CodeRabbit review whose body has a prompt block, so a push
that produced no findings is skipped without you walking reviews by hand.
Pass `--review-id` to action any other review: an older CodeRabbit one a later push
buried, or a human's, which `fetch` never picks on its own.

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

- `review.author` and `review.is_bot` — which posting rule Step 6 applies
- `findings` — the work list, each with `thread_id`, `comment_id`, `path`, `start`/`end`,
    and the reviewer's `prompt`
- `outside_diff` — findings CodeRabbit raised outside the diff.
    Real work with no thread to reply to or resolve; goes through Step 3's escalation
- `unmatched_findings` and `unclaimed_threads` — a block item with no thread, or a thread
    no item claimed.
    Read the thread on GitHub before deciding: if it's just the anchor drifting after an
    unrelated edit (see Step 3), it needs nothing; otherwise it goes through Step 3's
    escalation like any other real, out-of-scope finding
- `unparsed_prompt_lines` — CodeRabbit changed the block format.
    Stop and report it
- `other_open_threads` — open threads from earlier reviews.
    Out of scope for this pass, but a real one still goes through Step 3

**The PR branch is usually not the checked-out `HEAD`.** Check the current tree is clean
(`git status`, per the working-tree rule in `CLAUDE.md`), then check out the branch
directly in the current checkout rather than fetching it in and editing alongside
unrelated work.
Never use a git worktree.
If `branch.worktree` shows the branch already
checked out elsewhere, stop and report it instead of `cd`-ing into that worktree.

## Step 2 — Verify each finding adversarially

A bot reasons about a diff snapshot and is confidently wrong often enough that
applying its prompt verbatim regresses code.
A human is worth more trust, and still
wrong sometimes.
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

Push back hardest on findings that widen scope for its own sake: version pinning, extra
abstraction, "add a contract test" for behavior a real test already covers.
Where a finding names a security or data-loss risk, treat it as real until you have
disproved it.

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

Two things are not escalations. Line drift: an anchor that moved after an unrelated edit
in the same push lands in `unmatched_findings` or `unclaimed_threads` routinely, and a
thread marked `is_outdated: true` was resolved by the edit that moved it.
And a small, real fix in a file this PR already touches — those buckets mean "no thread
to reply to," not "out of scope", so it goes through Step 4 and Step 6's thumbs-up
closes it out with no reply posted.
Escalate only when the file sits outside the PR's diff, or the fix wants its own review.

## Step 4 — Fix the class, not the line

A reviewer cites the instances they happened to look at.
Fix every instance of the same defect inside the PR's diff, then say what you widened
and
why: the bare `except:` flagged at one call site and its three siblings in the module,
the missing cancellation guard on one path and the others through the same executor, one
unbound exception variable and every other swallowed exception in the file, a test fake
that does not mirror the real guard and the others in that module drifting the same way.
Stay inside the PR's scope — a defect in a file this PR does not touch went through Step
3, not a same-PR fix.

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

Write one action per finding into `pr-<number>-<reviewer>-actions.toml` in the worktree,
then apply it once the fixes are committed:

```toml
review_id = 4910562275
# Human reviews only, and only once they have said yes — see below.
replies_approved = true

[[actions]]
thread_id = "PRRT_..."
verdict = "fixed"

[[actions]]
thread_id = "PRRT_..."
verdict = "wrong"
reply = "The guard above already rejects None, so this path cannot raise."
```

```sh
~/.config/my_config/ai-cr-review.py apply --file pr-13942-coderabbit-actions.toml
```

**A bot's review:** run `apply` straight away, no confirmation.
Nobody's attention is
spent on a reply to a bot.

**A person's review:** draft every reply, then put the full text in front of the user
with `AskUserQuestion` so it is unmistakable that something is about to be posted under
their name.
Set `replies_approved = true` only after they say yes; the script refuses the batch
without it whenever an action carries reply text.
An actions file with no reply text needs no approval, so resolving and thumbs-upping a
human review is never gated.
A human thread is a conversation, so answer it: a bare resolve on a question the
reviewer asked reads as ignoring them.

The script refuses the whole batch before posting anything when a `thread_id` does not
belong to that review, a finding has no verdict, or a skipped finding carries no reply.
A reply is optional for `fixed` and required for the three skip verdicts, so a rejected
finding always leaves a public reason.
On a *bot's* `fixed`, default to no reply — the diff already shows it; add one only when
the fix landed somewhere else, like a shared helper.
Replies are written in the user's voice under the `change-review` skill's rules: hedged,
one sentence naming the change, no re-explaining the bug.

The 👍 on the review body is the signal that the whole review was actioned, so it lands
last and never lands at all if any thread failed.

When every real finding was a threadless one (nothing in `findings` needs a verdict),
the
actions file carries just `review_id`, and `apply` posts the thumbs-up with
`0 actioned`.

## Report

Lead with the review id and a one-line-per-finding verdict table, then the broader fixes
you added beyond the block, then what Step 3 escalated and where it landed (ticket link
or branch), then the gate results.
Keep it to the lines that change the user's next action.
