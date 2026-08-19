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

## Step 0b: read the context the PR body left out

Three sources carry findings the diff and the PR body cannot, and skipping any of them
produces a review that reads thorough and misses the best comment in it.

**The child ticket, not the one the body cites.** A body that links the epic often hides
a subissue holding the actual spec and acceptance criteria, and a diff that diverges
from
that spec is a design finding rather than a nit.
Walk down from whatever ticket the body names and read the children that match the diff,
and check each acceptance criterion against the code.

**The customer thread, when a support ticket started this.** Linear compresses a Pylon
or
Slack report into one line, and the compression is where scope goes missing: the thread
may say the problem spans several vendors while the ticket names one, may carry a
competing diagnosis from an earlier session that the PR now contradicts, and may still
be
waiting on a reply.
Say whether the thread needs updating, and link the message rather
than retelling it.

**Whether a bot reviewed the PR at all.** Absence of bot findings has at least three
innocent causes that all look identical to a clean review: a stacked PR on a non-default
base (CodeRabbit skips those), CodeRabbit out of credits, and Pulumi Neo refusing
because
the author's account is not linked.
Check, and put the answer in the PR comment: the
author is the person most likely to read silence as approval.

## Step 0c: attack your own findings before staging them

Every finding gets a second pass against the code, and cost, performance, and
missing-default claims get it first, because those are the ones that feel obvious and
are
usually already handled somewhere the diff does not show.
Two shapes recur: a repeated-work claim where the helper already caches (check the
helper
before claiming the cost), and a missing-argument claim where the library default is
already the value you were going to ask for (read the signature in the installed
package,
not from memory).
A finding that collapses here would have cost the author a round trip and cost you the
next finding's credibility.

The same scrutiny applies to premises you hand a subagent.
Anything stated as fact in the
brief gets built on rather than checked, so a wrong premise comes back wearing the
subagent's confidence.
Verify the load-bearing number yourself: not that the bound exists,
but that it is actually held around the code in question.

Run the tests rather than reasoning about them, and say in the staging header which
command actually ran.
A `make test-*` target that shells into a Docker service fails on an expired AWS SSO
token and proves nothing; the same suite often runs directly against the service's `uv`
venv.
Check the Makefile for what the target really does before reporting a suite as
unrunnable.

A finding that survives verification still needs the right frame, and three get dropped
by
default:

**A faithfully preserved bad behavior is still worth a comment when the ticket asked for
better.** A port or migration that carries an existing flaw across is not a regression,
which is where the thought usually stops.
Ask instead whether this change is the moment
the flaw was supposed to be fixed, and argue it from the acceptance criterion rather
than
from the diff.
Say plainly that it predates the PR so the author does not read it as an
accusation.

**A constraint the code satisfies only by inheriting a default is worth writing down.**
When a library default happens to be the value the ticket demanded, the criterion is met
and nothing records why it must stay that way, so the next contributor changes it for
consistency with its neighbours.
Ask for the value to be stated with the reason beside it,
and say up front that the behavior is already correct so the ask reads as documentation
rather than a bug report.

**When a question cannot be settled from the code, put the experiment in the comment.**
A
bare "does this work?"
hands the whole problem back. Name the check that would answer it
("toggle it off in Stage and watch for a tick") so the author can close the thread with
a
result.

## Step 0d: run the app when a claim is about behavior

A finding about runtime behavior, not just code shape ("does this actually 404", "does
the flag gate the UI") is worth running rather than reasoning about.
Use the `run` skill if the project has one: it launches the backend and frontend from
whatever the project already documents, and falls back to per-project-type patterns
otherwise.
Report what actually happened, not what should happen.

## Anchoring on GitHub

An inline comment only anchors to a line inside the diff.
A finding about an unchanged line has to hang off the nearest changed line, with the
prose
naming the symbol so the reader can find the real location.
This is the common case for consistency findings, where the new code is fine and its
untouched sibling is the problem.

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

## The review-level comment

The GitHub review body (or, when staging, the closing "Proposed PR comment") is not a
second draft of the findings already inline.
Default it to one short, varied line: `LGTM`, `LGTM!`, `Looks good`, `Looks good to me`,
`Looks good!`, `Yes!` and similar. Vary the phrasing; do not reuse the same one every
time.

Write more than that only for a finding that cannot get a `file:line`: it sits outside
the diff, or its scope will not fit one location.
Even then, prefer hanging it off the nearest changed file as its own inline comment
first, since most of these do trace back to something in the diff; fall back to the
review body only when no anchor makes sense.

## The `[AI Bot]:` prefix

Default to the hedged first-person voice above.
For a finding that is long, dense, or highly technical (a multi-paragraph trace through
several files, a re-derived calculation, a table), prefix it `[AI Bot]: ...` instead of
forcing it into first person.
It reads as a bot's analysis, verbatim, which is honest about what it is and skips
editing a technical block into a voice it does not need.
Still open with the finding and end with a question when one is warranted; the prefix
does not license switching to a directive.
This is the exception. Prefer the user's own voice and open questions by default, even
for technical findings; reach for the prefix only when the content itself reads as raw
analysis rather than a peer's remark.

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
