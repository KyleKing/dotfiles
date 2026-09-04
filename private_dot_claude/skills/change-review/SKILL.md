---
name: change-review
description: Write pull request review comments and replies to review threads in the user's voice, staged through the second-look CLI. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when preparing a review for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post.

The mechanics belong to the `second-look` skill, which is generated from the binary and
carries the commands, the batch shape, which fields post, and what is refused.
Read it
before the first batch of a session and do not work from a remembered schema.
This file
is the half the binary cannot know: whose voice a comment is in, what to read before
writing one, and which findings get dropped by default.

Refresh it whenever second-look is upgraded, since the generated copy goes stale
silently:

```sh
second-look skill > ~/.claude/skills/second-look/SKILL.md
```

The prose rules in CLAUDE.md still apply.
Review comments are short and get drafted
fast, which is where the `writing-voice` tic catalog gets skipped because nothing here
restates it.
Check drafts against `voice-examples.md` explicitly: the borrowed-vivid-verb
list ("land"/"lands"/"landed") catches spatial metaphors for plain facts ("outside the
diff", not "didn't land on a diff line"), and the unnamed-scope-qualifier and
bare-open-question entries catch two shapes that show up constantly in short comments
("too" with nothing named, a question with no proposed answer).

## Which skill

Writing comments on a pull request is this skill.
Actioning a review somebody left on
one is `change-review-apply`.
Catching up on reviews nobody actioned before the pull
request merged is `change-review-apply-retroactive`, which sweeps a window of merged
pull
requests and lands the surviving findings as one new pull request.

## A batch rather than one pull request

`second-look inbox --json` is the queue and the second-look skill says how to read the
order it comes in.
Filter it before spending an agent on anything: a draft is not waiting
on you, and a bot's draft least of all.

```sh
second-look inbox --json | jq -r '.[] | select(.bucket=="needs my review")
  | .items[] | select(.draft==false) | "\(.repository)#\(.number)"'
```

Parallelize across two or three full checkouts of the repository, one review at a time
in
each, never a worktree.
The reviews all land in one place whichever clone you run from,
so the clone is only there to hold a branch.
Take the ones that are clean and on the
default branch and leave the rest alone, since a dirty tree is somebody's parked work.
More rows than clones is fine: the extra ones are read from the API, and the review's
own
`note` says which got a checkout and which did not.

## Prepare the whole stack, not the top of it

Run `ai-pr-stack.py <pr>` (by absolute path, `~/.config/my_config/ai-pr-stack.py`)
unless
the batch is already staged and `second-look reviews --json` has answered the same
question.
It prints the chain the requested pull request sits on, bottom first, or says
plainly that it isn't stacked, and it is the way to find the chain above a single pull
request you have not staged.

Run `second-look get` against **every level it printed, bottom to top**.
A stacked pull
request's diff already excludes the levels below it, so getting only the top silently
skips whatever the lower ones introduce.

Read them in that same order.
A shape introduced low in the stack (a new accessor, a
changed signature, a widened type) is often only fully legible once you have seen the
upper pull request that calls it.

Attribute every finding to the pull request that introduces the code, not the one whose
diff you happened to be reading, and stage it there.
Do not restage the same finding at
every level it is still visible from; note the dependency in the upper review's note
instead.

## Validate every anchor against local code

Staging checks anchors inside the diff.
Anything a finding cites outside it is yours to
confirm against the checked-out code before you write a comment about it, because bot
and
subagent findings routinely cite lines that do not exist.
If you cannot check out or
fetch, stop and say so instead of writing from `gh pr diff` text alone.

`line` is in the file's post-image when `side` is `RIGHT` and its pre-image when `LEFT`.

## Read what the PR body left out

Do this for every level of the stack, not just the one asked for — a lower pull request
usually carries its own ticket and thread links, separate from the top one's.

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
A stacked PR's non-default base is one such cause and not itself a problem, but
confirm the bot actually reviewed against that base rather than skipping the PR
entirely for it.
Check, and say which in the PR comment — the author reads silence as
approval.

## Attack your own findings before staging them

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

## Run the app for behavior claims

A finding about behavior, not code shape, is worth running rather than reasoning about.
Use the `run` skill if the project has one; report what happened, not what should.

## How to write a comment

Hedge by default, in every comment. Open with "I think", "maybe", "consider", or a
question, and name more than one option rather than issuing a flat imperative.
Write it
this way on the first pass; do not draft "Drop the default" and expect the user to
soften
it.
Reserve a plain unhedged directive for something both trivial and unarguable (a typo,
a wrong constant); when unsure whether a fix qualifies, hedge.

Write for a peer. Give the observation and the ask; cut the mechanism, the
why-it-matters, and the consequence a reviewer would already infer.
Spell out the
rationale only when the user says the recipient is junior.

Link, do not retell. When a finding rests on a source (a ticket, a thread, a prior PR),
link the narrowest anchor the tool gives you and title it with what the reader will find
there, then state the conclusion in one sentence.
A paragraph reconstructing who said
what is the shape to cut: the link carries it, and the author will open it anyway to
check you.

Audit the whole item, not the claim that prompted you.
Once a cell, hunk, or row is open,
check every assertion in it.
Correcting a grade while a false status claim sits in the
next sentence is half a review, and the half you left is the one the author now believes
you cleared.

Ask whether the item belongs before correcting its fields.
A row that should not exist, a
test that should not be written, an option nobody will set: naming that is worth more
than fixing the contents, and it is the question a field-level comment quietly skips.

Say what should happen, not what breaks downstream.
"So the right classification is user
error" beats tracing the knock-on effect through the summary table; the author can trace
it and would rather have the fix.

Argue from why a rule exists, not by quoting the rule back.
An author who wrote the doc
does not need its wording recited; they need the reason it draws the line where it does.

Your own confusion is a reportable finding.
"I'm not sure what this phrase means without
reading where it's defined" is evidence about the writing, and it is more useful than an
objective-sounding claim that the text is unclear.

Name the symbol (function, variable, constant), never `file:line`.
The name locates it
and line numbers drift.
`file:line` belongs in the anchor fields, not in the body.

Do not add a `(line ###)` cross-reference to another comment in the same file just to
help the reader find it.
Add one only when the file carries enough comments that it is
genuinely ambiguous without it.

## By comment type

Self-notes on your own code state the non-obvious why (constraint, invariant,
workaround).
Do not restate what the diff already shows.
This is a different audience
from a future reader of the code: evergreen comment rules govern the code itself, this
governs a note on a diff.

Replies to a review acknowledge the bug briefly, state what was fixed, and add a
follow-up action if one is needed ("I will confirm X after the next deploy to Stage").
Do
not re-explain why the bug was bad or what would have happened, and do not over-explain
a
fix that is visible in the diff.
One sentence naming the change is enough.

Before replying to a bot thread, check whether a later commit already resolved it
(threads marked "✅ Addressed", or fixes visible in the diff).
Close stale threads with a
one-line pointer to the fixing commit instead of re-raising them.

The user sometimes opens a bot-thread reply with `^` ("^I think this is valid..."),
marking third-person reference to the author rather than addressing them.
Bot threads
only, never human ones, and only selectively.
Preserve it where it appears; do not add or
remove it yourself.

## Re-editing on a later pass

Once the user hand-edits a comment, treat it as settled.
Do not re-polish it against the
voice rules, which govern what you draft rather than what they have already written.
Small, clearly-needed edits (a changed anchor, a factual correction) are fine; do not
rewrite the sentence.

## Merged PRs

Verify inline comments still post before proposing them.
Create a PENDING review with one
throwaway inline comment via the API (`POST /repos/{o}/{r}/pulls/{n}/reviews` with
`commit_id` and a `comments[]` entry, no `event` so it stays a draft invisible to
others), confirm it anchors, then `DELETE` the pending review.
Report the result. Frame
the summary to acknowledge the merge and offer the nits as considerations for a
follow-up
PR rather than change requests.
