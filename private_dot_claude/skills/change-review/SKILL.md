---
name: change-review
description: Write pull request review comments and replies to review threads in the user's voice. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when staging review feedback in a pr-<number>-review-comments.md file for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post.
The prose rules in CLAUDE.md still apply; this covers what is specific to review
threads.

Review comments are short and get drafted fast, which is exactly where the writing-voice
tic catalog (`writing-voice` skill, `voice-examples.md`) gets skipped because nothing
here restates it.
Check drafts against it explicitly, not just CLAUDE.md's compressed rules: the
borrowed-vivid-verb list ("land"/"lands"/"landed" included) catches spatial metaphors
for plain facts ("outside the diff", not "didn't land on a diff line"), and the
unnamed-scope-qualifier and bare-open-question entries catch two shapes that show up
constantly in short comments ("too" with nothing named, a question with no proposed
answer).

## Step 0: validate every anchor against local code

Check out the branch, or fetch the PR to `FETCH_HEAD`, and confirm each `file:line`
against the checked-out code before writing a single comment.
Subagent and bot findings routinely cite lines that do not exist (line 993 in a 137-line
file).
If the code cannot be checked out or fetched, stop and say so rather than writing
comments from `gh pr diff` text alone.

## How to write a comment

Hedge by default, in every comment, mine or staged for the user.
Open with "I think", "maybe", "consider", or a question, and name more than one option
rather than issuing a flat imperative.
Write it this way on the first pass — do not draft "Drop the default" and expect the
user to soften it.
Reserve a plain unhedged directive for something both trivial and unarguable (a typo, a
wrong constant); when unsure whether a fix qualifies, hedge.

Write for a peer. Give the observation and the ask; cut the mechanism, the
why-it-matters, and the consequence a reviewer would already infer.
Spell out the rationale only when the user says the recipient is junior.

Link, do not retell.
When a finding rests on a source (a ticket, a thread, a prior PR), link the narrowest
anchor the tool gives you and title it with what the reader will find there, then state
the conclusion in one sentence.
A paragraph reconstructing who said what is the shape to cut: the link carries it, and
the author will open it anyway to check you.

Audit the whole item, not the claim that prompted you.
Once a cell, hunk, or row is open, check every assertion in it.
Correcting a grade while a false status claim sits in the next sentence is half a
review, and the half you left is the one the author now believes you cleared.

Ask whether the item belongs before correcting its fields.
A row that should not exist, a test that should not be written, an option nobody will
set: naming that is worth more than fixing the contents, and it is the question a
field-level comment quietly skips.

Say what should happen, not what breaks downstream.
"So the right classification is user error" beats tracing the knock-on effect through
the summary table; the author can trace it and would rather have the fix.

Argue from why a rule exists, not by quoting the rule back.
An author who wrote the doc does not need its wording recited; they need the reason it
draws the line where it does.

Your own confusion is a reportable finding.
"I'm not sure what this phrase means without reading where it's defined" is evidence
about the writing, and it is more useful than an objective-sounding claim that the text
is unclear.

Name the symbol (function, variable, constant), never `file:line`.
The name locates it and line numbers drift.
`file:line` belongs in the inline anchor, not in the human-facing text.

Do not add a `(line ###)` cross-reference to another comment in the same file just to
help the reader find it.
Add one only when the file carries enough comments that it is genuinely ambiguous
without it.

## By comment type

Self-notes on your own code state the non-obvious why (constraint, invariant,
workaround).
Do not restate what the diff already shows.
This is a different audience from a future reader of the code — evergreen comment rules
govern the code itself, this governs a note on a diff.

Replies to a review acknowledge the bug briefly, state what was fixed, and add a
follow-up action if one is needed ("I will confirm X after the next deploy to Stage").
Do not re-explain why the bug was bad or what would have happened, and do not
over-explain a fix that is visible in the diff.
One sentence naming the change is enough.

Before replying to a bot thread, check whether a later commit already resolved it
(threads marked "✅ Addressed", or fixes visible in the diff).
Close stale threads with a one-line pointer to the fixing commit instead of re-raising
them.

## Staging a review for sign-off

When asked to prepare review feedback for the user to approve, write a local staging
file rather than posting.
Full spec: [staging-file.md](staging-file.md).

## Merged PRs

Verify inline comments still post before proposing them.
Create a PENDING review with one throwaway inline comment via the API
(`POST /repos/{o}/{r}/pulls/{n}/reviews` with `commit_id` and a `comments[]` entry, no
`event` so it stays a draft invisible to others), confirm it anchors, then `DELETE` the
pending review.
Report the result. Frame the summary to acknowledge the merge and offer the nits as
considerations for a follow-up PR rather than change requests.
