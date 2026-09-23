---
name: change-review-apply
description: Action a PR review — CodeRabbit's, another bot's, or a teammate's — by adversarially verifying each finding, fixing the whole class of problem rather than the cited lines, committing incrementally, and replying, resolving, and rocketing the review. Use when asked to apply, address, or action review comments, whoever left them.
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
On a human's review, resolve and rocket freely, but a *reply*
goes out only after they say yes — Step 6 has the mechanics.

## Step 1 — Fetch every pending review, then action each one

```sh
~/.config/my_config/ai-cr-review.py fetch > cr-review.json     # add --pr N for another PR
```

`fetch` with no `--review-id` returns **every** un-acked bot review on the PR
(CodeRabbit,
watch-doggo, a linter, a security scanner), not just the newest — a PR that collected
three CodeRabbit passes across three pushes gets all three in one call, under a
top-level
`reviews` array.
Work through the array in submission order (oldest first): a later review sometimes
references a finding an earlier one already raised, and fixing in order avoids
re-deriving
the same fix twice.
Steps 2 through 6 below apply per entry in `reviews`, exactly as if each had come from
its
own `fetch --review-id`.
A review that lands on the PR after this `fetch` ran (a push mid-session drawing a new
CodeRabbit pass) isn't in that array — re-run `fetch` once you're done with this batch
to
catch it, don't assume one call finds everything forever.
Pass `--review-id` to action one specific review outright, which is how you reach a
human's review — `fetch`'s default array only ever holds bot reviews.

Check whether anything is buried, including a human review:

```sh
~/.config/my_config/ai-cr-review.py status     # add --pr N for another PR
```

This lists every review, bot or human, that has no rocket reaction and still carries an
unresolved thread or a CHANGES_REQUESTED verdict — the same set `fetch`'s array covers
for
bots, plus any human review, which needs `--review-id` to actually fetch.
An entry with `open_threads: 0` has no thread to reply into
(general feedback in the review body, not an inline comment) — its text comes back
quoted in `body`.
There is nothing to resolve, and it still gets answered: read it, and where it asked
something or claimed something, post one `[AI Bot]: ` comment on the PR naming the
review and answering it point by point.
A numbered list in a review body (Watch Doggo's open questions are the common case)
is answered by number.

Read these keys per review before starting work on it:

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
- `other_open_threads` — open threads tied to a *different* review than this entry's.
    Out of scope for this entry specifically (it's that other review's own `findings`
    once you reach it in the array), but a real one still goes through Step 3

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

- `fixed` — reproduce the failure in your head first.
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
to reply to," not "out of scope", so it goes through Step 4 and Step 6's rocket
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

Run the narrowest test for what you touched as you go, then the repo's full
format/typecheck/test ladder once over the combined diff (in the platform repo, the
`pre-pr-qa` skill picks the right gates).
Report failures verbatim; never call a finding fixed on the strength of the edit alone.

## Step 6 — Post the verdicts

Write one action per finding into `pr-<number>-<reviewer>-<review_id>-actions.toml` in
the
worktree (the `review_id` suffix matters: a PR with three CodeRabbit passes needs three
separate files, one per entry in `fetch`'s `reviews` array, not one shared file), then
apply each once its fixes are committed:

```toml
review_id = 4910562275
# Human reviews only, and only once they have said yes — see below.
replies_approved = true

[[actions]]
thread_id = "PRRT_..."
verdict = "fixed"
reply = "[AI Bot]: Moved the org check into `require_scope` so every caller gets it."

[[actions]]
thread_id = "PRRT_..."
verdict = "wrong"
reply = "[AI Bot]: The guard above already rejects None, so this path cannot raise."
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
without it whenever an action carries reply text, which every action now does, so a
human's review is always gated.
A human thread is a conversation, so answer it: a bare resolve on a question the
reviewer asked reads as ignoring them.
The `[AI Bot]: ` prefix stays on here too.
It is what tells them they are reading a
draft the user approved rather than one the user wrote, which is the distinction
`CLAUDE.md` asks every shared-surface post to make in its first line.

The script refuses the whole batch before posting anything when a `thread_id` does not
belong to that review, a finding has no verdict, or an action carries no reply.

**Every finding gets a reply, and every reply opens with `[AI Bot]: `.** That holds for
a `fixed` verdict as much as for a skip, on a bot's thread and a human's alike, so a
thread never closes with nothing in it saying what happened.
Two reasons, and both bite:

- A thread nobody answered reads as a finding nobody looked at.
    A reviewer that re-reads its own threads punishes the silence harder than a person
    does: Watch Doggo hands each prior finding's replies to the next round
    (`REVIEW_FEEDBACK.md`), and a finding that drew silence gets raised again unchanged
- The reply posts under the user's own account, so GitHub attributes it to a
    write-access human and nothing else in the thread says otherwise.
    Watch Doggo's `rebuttal.py` counts exactly that as an argument that can clear a
    blocking finding with no code change behind it.
    The prefix is the whole marker

Keep it to one sentence after the prefix, in the user's voice under the `change-review`
skill's rules: name the change, do not re-explain the bug.
Say where the fix went whenever the thread's own diff does not show it (a shared
helper, a sibling call site, another file).

The 🚀 on each review's body is the signal that *that* review was actioned, so it lands
last for that review and never lands at all if one of its threads failed.
Post it per review as you finish that entry — don't hold all the rockets back until the
whole `reviews` array is done, since a later review's `apply` failing shouldn't leave an
earlier, already-fixed review still looking un-actioned.

Once every review in this pass has its rocket, push the branch once: `git push` in a
plain git checkout, or `jj git push --bookmark <name>` when `.jj/` is present, per the
git-vs-jj rule in `CLAUDE.md`.
This applies whether a given review was a bot's or a human's.

When every real finding was a threadless one (nothing in `findings` needs a verdict),
the
actions file carries just `review_id`, and `apply` posts the rocket with
`0 actioned`.

## Report

One section per review actioned, each leading with its review id and a
one-line-per-finding
verdict table, then the broader fixes you added beyond its block.
After all of them, one shared list of what Step 3 escalated and where it landed (ticket
link or branch), then the gate results.
Keep it to the lines that change the user's next action.
