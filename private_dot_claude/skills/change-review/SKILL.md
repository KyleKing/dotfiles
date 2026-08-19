---
name: change-review
description: Write pull request review comments and replies to review threads in the user's voice. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when staging review feedback in a pr-<number>-review-comments.md file for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post.
CLAUDE.md and `writing-voice`
set the prose floor; this covers what's specific to review threads.

Review comments get drafted fast, which is exactly where the writing-voice tic catalog
(`voice-examples.md`) gets skipped because nothing here restates it.
Check drafts
against it explicitly: the borrowed-vivid-verb list ("land"/"lands"/"landed") catches
spatial metaphors for plain facts ("outside the diff", not "didn't land on a diff
line"), and the unnamed-scope-qualifier and bare-open-question entries catch two shapes
common in short comments (a lone "too", a question with no proposed answer).

## Quick reference

1. Validate every anchor against checked-out code (Step 0a).
1. Read the child ticket, the customer thread, and whether a bot reviewed at all (Step 0b).
1. Attack your own findings, cost/perf/missing-default claims first (Step 0c).
1. Run the app if a claim is about behavior, not code shape (Step 0d).
1. Hedge every comment; name the symbol, not `file:line`; link, don't retell.
1. Default the review body to a short LGTM variant; write more only for a finding that
    can't get an inline anchor.
1. Use the `[AI Bot]:` prefix only for long, dense, technical findings — otherwise the
    user's own voice.

## Step 0a: validate every anchor against local code

Check out the branch (or fetch the PR to `FETCH_HEAD`) and confirm each `file:line`
against the checked-out code before writing a single comment.
Bot and subagent findings
routinely cite lines that don't exist.
If you can't check out or fetch, stop and say so
instead of writing from `gh pr diff` text alone.

## Step 0b: read what the PR body left out

Three sources carry findings the diff and PR body can't; skipping any produces a review
that reads thorough while missing its best comment.

The child ticket, not the one the body cites: walk down from the linked epic to the
subissue holding the actual spec, and check each acceptance criterion against the code.

The customer thread, when a support ticket started this: Linear compresses a Pylon or
Slack report into one line, and that's where scope goes missing (a wider blast radius, a
competing earlier diagnosis, a thread still waiting on a reply).
Link the message, say
whether it needs updating.

Whether a bot reviewed at all: absence of findings has innocent causes that look
identical to a clean review (non-default base, CodeRabbit out of credits, an unlinked
account).
Check, and say which in the PR comment — the author reads silence as approval.

## Step 0c: attack your own findings before staging them

Every finding gets a second pass; cost, performance, and missing-default claims first,
because those are usually already handled somewhere the diff doesn't show.
Check the
helper before claiming repeated work; read the installed library's signature before
claiming a missing default.

Verify any load-bearing premise you hand a subagent yourself — a wrong premise comes
back wearing the subagent's confidence.

Run the tests, don't reason about them, and say which command actually ran.
A
`make test-*` target that shells into Docker can fail on an expired SSO token and prove
nothing; check the Makefile for what a target really does before calling a suite
unrunnable.

Three finding shapes get dropped by default and shouldn't be:

- A preserved bad behavior is still worth a comment when the ticket asked to fix it, not
    just port it; say plainly that it predates the PR.
- A constraint met only by inheriting a library default is worth writing down before the
    next contributor "fixes" it for consistency.
- A question the code can't settle needs the experiment that would answer it, not a bare
    "does this work?"

## Step 0d: run the app for behavior claims

A finding about behavior, not code shape, is worth running rather than reasoning about.
Use the `run` skill if the project has one; report what happened, not what should.

## Anchoring on GitHub

An inline comment only anchors inside the diff.
A finding on an unchanged line hangs off
the nearest changed line instead, naming the symbol so the reader finds the real
location — the common case for consistency findings, where the untouched sibling is the
problem.

## Writing the comment

Hedge by default: open with "I think", "maybe", "consider", or a question, and name more
than one option rather than a flat imperative.
Skip the hedge only for a trivial,
unarguable fix (a typo, a wrong constant).

Write for a peer: give the observation and the ask, cut the mechanism and the
consequence a reviewer would infer.

Link, don't retell: link the narrowest anchor, title it with what's there, then state
the conclusion in one sentence.

Audit the whole item once it's open, not just the claim that prompted you.

Ask whether the item belongs before you fix its fields.

State the fix, not the downstream breakage: name the right answer and let the author
trace the effect.

Argue from why a rule exists, not by quoting it back.

Your own confusion is a finding: "I don't follow X without reading where it's defined"
beats an objective-sounding "this is unclear."

Name the symbol, never `file:line` — names survive drift, line numbers don't.
`file:line`
belongs only in the inline anchor.

Skip a `(line ###)` cross-reference to another comment in the same file unless it
carries enough comments that the location is genuinely ambiguous without one.

## The review-level comment

The GitHub review body (and, when staging, the closing "Proposed PR comment") is not a
second draft of the findings already inline.
Default to one short, varied line — `LGTM`,
`LGTM!`, `Looks good`, `Looks good to me`, `Looks good!`, `Yes!` — never the same one
twice in a row.

Write more only for a finding that can't get a `file:line` (outside the diff, or too
broad for one spot).
Even then, try an inline anchor on the nearest changed file first;
fall back to the review body only when no anchor makes sense, and keep it to that one
finding.

## The `[AI Bot]:` prefix

Default to the hedged voice above. Prefix `[AI Bot]: ...` only for a finding that's
long, dense, or highly technical (a multi-file trace, a re-derived calculation, a
table) — it reads honestly as a bot's analysis instead of forcing a technical block into
first person.
Still open with the finding and close with a question when warranted; the
prefix doesn't license a directive.
This is the exception: default to the user's own
voice and open questions even for technical findings.

## By comment type

Self-notes on your own code state the non-obvious why (constraint, invariant,
workaround) — evergreen comment rules govern the code, this governs a note on the diff.

Replies to a review acknowledge the bug briefly, state what was fixed, and add a
follow-up only if one's needed.
One sentence naming the change is enough.

Before replying to a bot thread, check whether a later commit already resolved it
(marked "✅ Addressed", or visible in the diff); close stale threads with a one-line
pointer to the fixing commit instead of re-raising them.

## Staging a review for sign-off

Write a local staging file instead of posting when asked to prepare feedback for
sign-off.
Full spec: [staging-file.md](staging-file.md).

## Merged PRs

Verify inline comments still post before proposing them: create a PENDING review with
one throwaway inline comment via the API (`POST /repos/{o}/{r}/pulls/{n}/reviews` with
`commit_id` and a `comments[]` entry, no `event`), confirm it anchors, then `DELETE` the
pending review.
Frame the review-level comment to acknowledge the merge and offer nits
as considerations for a follow-up rather than change requests.
