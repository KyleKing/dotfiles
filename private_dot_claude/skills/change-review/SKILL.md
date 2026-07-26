---
name: change-review
description: Write pull request review comments, replies to review threads, and the PR-level roll-up summary in the user's voice. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when staging review feedback in a pr-<number>-review-comments.md file for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post. The prose rules in
CLAUDE.md still apply; this covers what is specific to review threads.

## Step 0: validate every anchor against local code

Check out the branch, or fetch the PR to `FETCH_HEAD`, and confirm each
`file:line` against the checked-out code before writing a single comment. Subagent
and bot findings routinely cite lines that do not exist (line 993 in a 137-line
file). If the code cannot be checked out or fetched, stop and say so rather than
writing comments from `gh pr diff` text alone.

## How to write a comment

Hedge by default, in every comment, mine or staged for the user. Open with "I
think", "maybe", "consider", or a question, and name more than one option rather
than issuing a flat imperative. Write it this way on the first pass — do not draft
"Drop the default" and expect the user to soften it. Reserve a plain unhedged
directive for something both trivial and unarguable (a typo, a wrong constant);
when unsure whether a fix qualifies, hedge.

Write for a peer. Give the observation and the ask; cut the mechanism, the
why-it-matters, and the consequence a reviewer would already infer. Spell out the
rationale only when the user says the recipient is junior.

Name the symbol (function, variable, constant), never `file:line`. The name locates
it and line numbers drift. `file:line` belongs in the inline anchor and in the
roll-up, not in the human-facing text.

Do not add a `(line ###)` cross-reference to another comment in the same file just
to help the reader find it. Add one only when the file carries enough comments that
it is genuinely ambiguous without it.

## By comment type

Self-notes on your own code state the non-obvious why (constraint, invariant,
workaround). Do not restate what the diff already shows. This is a different
audience from a future reader of the code — evergreen comment rules govern the
code itself, this governs a note on a diff.

Replies to a review acknowledge the bug briefly, state what was fixed, and add a
follow-up action if one is needed ("I will confirm X after the next deploy to
Stage"). Do not re-explain why the bug was bad or what would have happened, and do
not over-explain a fix that is visible in the diff. One sentence naming the change
is enough.

Before replying to a bot thread, check whether a later commit already resolved it
(threads marked "✅ Addressed", or fixes visible in the diff). Close stale threads
with a one-line pointer to the fixing commit instead of re-raising them.

## The roll-up (PR-level summary)

The roll-up must not restate the inline comments in prose. It is a copyable,
AI-agent-friendly checklist with two parts: a short preamble condensing the user's
working defaults (ask via the clarification tool when unsure, validate against
current code before changing and skip already-handled items, keep edits minimal and
scoped, run checks once at the end), then ready-to-implement action items, each with
its `file:line` and enough detail to act on without reopening the thread. Frame it
as a consolidated post-review checklist, not a re-narration.

Format: a `<details><summary>` wrapping a nested fenced ` ```markdown ` code block,
matching CodeRabbit. The nested fence is what produces GitHub's hover copy button —
it is tied to the `<pre><code>` a fence renders, not to `<details>` alone. A plain
`<details>`, or a bare fence with no `<details>`, does not get one. Content inside
the fence is plain text, so checkboxes, bold, and backticks do not render live; that
is the accepted cost of one-click copy.

Reference `file:line` directly in the roll-up. Those are known before the review
posts, so inline comments and the summary go up in one `gh api` / `gh pr review`
step — skip the two-step pattern of posting first and patching links back in.

## Staging a review for sign-off

When asked to prepare review feedback for the user to approve, write a local
staging file rather than posting. Full spec: [staging-file.md](staging-file.md).

## Merged PRs

Verify inline comments still post before proposing them. Create a PENDING review
with one throwaway inline comment via the API
(`POST /repos/{o}/{r}/pulls/{n}/reviews` with `commit_id` and a `comments[]` entry,
no `event` so it stays a draft invisible to others), confirm it anchors, then
`DELETE` the pending review. Report the result. Frame the summary to acknowledge the
merge and offer the nits as considerations for a follow-up PR rather than change
requests.
