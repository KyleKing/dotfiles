---
name: change-review
description: Write pull request review comments and replies to review threads in the user's voice, staged through the second-look CLI. Use when reviewing a PR or diff and producing comments, when replying to a bot thread (CodeRabbit, Codex), when triaging or applying review findings, or when preparing a review for the user to proofread before posting.
---

# Change review

How to write review comments the user will actually post, and how to stage them.

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
request merged is `change-review-retroactive`, which sweeps a window of merged pull
requests and lands the surviving findings as one new pull request.

## Step 0-queue: a batch rather than one pull request

When the ask is every pull request waiting on review rather than a named one, the queue
is `second-look inbox --json` and it comes in the order to work it: what is already
started, then the cheapest of what an earlier read rated, then what has waited longest,
with drafts under all of it.
Take that order.
Each row carries `reviewed`, `cost`, `rated`,
`added`, and `removed`, so a row with no `rated` is one nobody has rated rather than one
that is cheap.

Filter before spending an agent on anything.
A draft is not waiting on you, and a bot's
draft least of all:

```sh
second-look inbox --json | jq -r '.[] | select(.bucket=="needs my review")
  | .items[] | select(.draft==false) | "\(.repository)#\(.number)"'
```

Stand anywhere, including a directory that is not a checkout of anything.
A repository
with no clone there keeps its reviews under the user config directory, one directory per
repository, so a tree holding several clones of the same repository still has one set of
reviews and which clone you run from does not matter.

Stage the whole batch first, then read the order back:

```sh
second-look get <owner/repo#n>             # once per row, no checkout needed, ~3s each
second-look reviews --json                 # every staged review, stacks bottom first
```

`reviews` is where the stack order comes from once the batch is staged, because `get`
records the branches each pull request joins and a chain is only visible with both ends
on disk.
Use it in place of `ai-pr-stack.py` when the whole queue is already staged; the
script is still the way to find the chain above a single pull request you have not
staged.

Most of a review needs no checkout.
Two things do: checking a finding that cites code the
diff does not carry, and running the tests or the app for a claim about behavior.
A clone
can only be on one branch, so those go one at a time in whichever clone is free and the
rest are read from the API.
Say in the review's own `note` which of the two a review got.

Finding nothing is an answer.
A prepared review with no comments reads the same whether it
was read carefully or never opened, so write the run log into the review's `note` either
way.

## Step 0: prepare the review

Run `ai-pr-stack.py <pr>` first (called by absolute path,
`~/.config/my_config/ai-pr-stack.py`), unless the whole queue is already staged and
`second-look reviews --json` has answered the same question.
It prints the chain of PRs the requested one is
stacked on, bottom first, or says plainly that it isn't stacked.
The output names every
level to run `second-look get` against — read it off the tool rather than re-deriving it
from `gh pr view`/`gh pr list` by hand.

Run `second-look get <pr>` for **every PR number `ai-pr-stack.py` printed, bottom to
top**, not only the one asked for.
A stacked PR's diff already excludes the levels below
it, so getting only the top level silently skips whatever the lower PRs introduce.

It refuses to move a dirty working tree, so commit or stash first when it says so.
Already being on a PR's head never blocks that PR's `get`, however dirty the tree is.

Anchors inside the diff are checked for you from there.
Staging quotes the diff line
each comment points at, and a comment on a line the diff does not carry is refused with
nothing written, which is what catches a subagent or bot citing line 993 of a 137-line
file.
Posting compares those quotes against the live diff again and refuses if any moved.

`line` is in the file's post-image when `side` is `RIGHT` and its pre-image when `LEFT`.

## Step 0-stack: review bottom to top, stage findings at their own level

Read each level in the order `ai-pr-stack.py` printed it, bottom first.
A shape
introduced low in the stack (a new accessor, a changed signature, a widened type) is
often only fully legible once you've seen the upper PR that calls it.

Attribute every finding to the PR that actually introduces the code in question, not the
PR whose diff you happened to be reading when you noticed it — stage it with
`second-look comment add <that-pr>`.
Don't restage the same finding at every level it's
still visible from; note the dependency in the upper PR's review note instead of
duplicating the comment.

## Step 0a: validate every anchor against local code

`second-look get` covers anchors inside the diff; still confirm anything a finding
cites outside the diff against the checked-out code before writing a comment about it.
Bot and subagent findings routinely cite lines that don't exist.
If you can't check out
or fetch, stop and say so instead of writing from `gh pr diff` text alone.

## Step 0b: read what the PR body left out

Do this for every level of the stack, not just the one asked for — a lower PR usually
carries its own ticket and thread links, separate from the top PR's.

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

## Staging with second-look

`second-look` holds the prepared review in `.second-look/pr-<number>.toml` and posts it
in one call.
Run `second-look --help` for the full contract: it documents every field,
which of them post, and what is refused.
Read it before the first batch of a session
rather than guessing the shape from here.

The shape of the work:

```sh
second-look show <pr>                      # what is already staged
cat batch.json | second-look comment add <pr>
second-look show <pr> --payload            # exactly what would leave the laptop
```

Then the user proofreads the TOML and runs `second-look post <pr>` themselves.
Do not
post on their behalf unless they said so in this session.

**Every comment gets a `note`.** It is local and never posted, and it is where the
evidence goes: the command that proved the finding and what it printed, the file that
contradicts the claim, the reason for the doubt.
The `body` carries only what the author
reads, so the reasoning that would clutter a review comment belongs in the note instead
of being cut.

**Use `status` honestly.** `ready` means post it.
`draft` means the thought is not
finished, and `second-look post` refuses while any draft remains, so a draft is safe
rather than risky.
`skip` with a `skip_reason` records a finding considered and declined, which is
worth more than deleting it: it reads as considered rather than missed.

**Set `severity`** to one of blocker, major, minor, nit, or question.
It orders what the
user reads first.

**Put the run notes in the top-level `note`**: what was run and what it returned, suites
that could not run and why, and whether a bot already reviewed the PR.
It shows how much of the review is proven rather than read.

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
Set
`in_reply_to` to the review comment's id; `second-look` sends replies to their own
endpoint.

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
Reuse the comment's `id` so the edit replaces it rather than
appending a duplicate.

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
