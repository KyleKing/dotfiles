---
name: second-look
description: Stage pull request review comments through the second-look CLI, where they are anchored to the diff and held for the user to proofread before anything is posted. Use when drafting review comments, replying to a review thread, preparing a review for the user to post, or working through the queue of pull requests waiting on their review.
---

# second-look

Do not run `second-look <pr>` or `second-look` with no argument.
Both open the review
screen, which belongs to the person at the keyboard, and an agent that runs one waits
forever on a terminal nothing is attached to.
Everything below is a command that reads
stdin and writes stdout.

Run `second-look --help` before the first batch of a session.
It is the contract: every
field, which of them post, what stays local, and what is refused.
It ships in the same
binary as the code that enforces it, so it cannot be out of date.
Do not work from a
remembered shape of the schema.

## The shape of the work

```sh
second-look get <pr>                       # check out the head, cache the diff
second-look show <pr>                      # what is already staged
second-look show <pr> --diff               # the diff, with every comment marked on it
second-look todo <pr>                      # what the author handed back for work
second-look context <pr> <id>              # one comment with its hunk, note, and thread
second-look comment add <pr> < batch.json  # stage a batch
second-look show <pr> --payload            # exactly what would leave the laptop
```

Then the user reads the prepared review and posts it.
Do not post on their behalf unless
they said so in this session.

`get` refuses to move a dirty working tree, so commit or stash when it says so.
Already
being on the pull request head never blocks, however dirty the tree is.

## Working a queue rather than one pull request

`second-look inbox --json` is every pull request waiting on the user, in the order to
work it: what they have already started, then the cheapest of what an earlier read
rated, then what has waited longest, with drafts under all of it.
Take that order as
given. Each row also carries `reviewed`, `cost`, `rated`, `added`, and `removed`, which
is what this laptop knows without asking GitHub, so a row with no `rated` is one nobody
has rated rather than one that is cheap.

Stand anywhere. A repository this directory is not a checkout of keeps its reviews under
the user config directory, one directory per repository, so a tree holding six clones of
the same repository still has one set of reviews and it does not matter which of them
you
run from.
Name the pull request as `owner/repo#42` and every row of the queue is reachable
from one directory, including the repositories with no clone at all.

Stage the whole batch before reviewing any of it, then read the order back:

```sh
second-look get <owner/repo#n>             # once per row, no checkout needed
second-look reviews --json                 # every staged review, stacks bottom first
```

`reviews` is where the stack order comes from, because `get` records the branches each
pull request joins and a chain is only visible once both ends are staged.
Read the bottom
of a stack before what sits on top of it: the upper diff excludes the lower one, so
reading it first is reading against changes you have not seen.
Stage a finding against
the pull request that introduces the code, which is not always the one whose diff you
were reading, and note the dependency in the upper review rather than staging the same
comment twice.

## What a checkout is for, and when to take one

Most of a review needs none. The diff, the open threads, and the comment id a reply
carries all come off the API, and `get` outside a clone moves no working copy at all.

Two things need one: checking a finding that cites code the diff does not carry, and
running the tests or the app for a claim about behavior.
A clone can only be on one
branch, so those reviews go one at a time in whichever clone is free, and the rest are
read from the API.
Say in the review's `note` which of the two a review got, because a
finding nobody could check against the code is a weaker finding and the user is the one
deciding whether to post it.

## Finding nothing is an answer

A prepared review with no comments reads the same whether it was read carefully or never
opened.
So write the review's `note` either way: what you read, what you ran, what it
printed, and that nothing came of it.
An empty review carrying a run log is a review.
An
empty review carrying nothing is a row somebody has to do again.

## Anchors are checked, not trusted

Staging quotes the diff line each comment points at, and a comment on a line the diff
does not carry is refused with nothing written.
This is what catches a finding that
cites line 993 of a 137-line file, whoever wrote it.
Posting compares those quotes
against the live diff again and refuses if any moved.

That covers anchors inside the diff. Anything a finding cites outside the diff is still
yours to check against the checked-out code before you write a comment about it.

## Every comment gets a note

`note` is local and never posted. It is where the evidence goes: the command that proved
the finding and what it printed, the file that contradicts the claim, the reason for the
doubt.
`body` carries only what the author reads, so reasoning that would clutter a
review comment goes in the note rather than being cut.

The user attaches evidence the same way from the review screen: `!` hands the terminal
to their shell and appends the transcript to the note under the cursor.
So a note you
write is the start of that record, not the whole of it, and it should say what you ran
rather than reading as a finished argument.

The review's own `note` is the run log: what was run and what it returned, suites that
could not run and why, whether a bot already reviewed the pull request.
It shows how much
of the review is proven rather than read.

## Everything you stage is a draft

Write `"status": "draft"` on every comment.
`comment add` holds one anyway: a comment
staged as `ready` is written as a draft and the run says how many it held.
Nothing you
write posts until the author has read it and marked it ready in the review screen, and
`post` refuses while any draft remains.

That is the point of staging through a file rather than posting.
What you write is a
proposal about someone else's code, and the author rules on each one.

`skip` with a `skip_reason` is left as you wrote it, because it records a finding you
considered and declined, which is worth more than deleting it: it reads as considered
rather than missed.

`severity` is blocker, major, minor, nit, or question.
It orders what the user reads
first.

## Work handed back to you

A comment whose status is `todo` is one the author has handed back: they read it and
want
something done.
`second-look todo <pr>` prints every one of them with the hunk, the note,
and the exchange so far.

Answer with a turn rather than by rewriting the comment silently.
Stage the comment again
carrying `"turn": [{"author": "<you>", "body": "<what you did and what changed>"}]`.
Turns
append to what is already on disk, so send only what is new.
The comment is held as a
draft, which puts it back in front of the author.

## Suggestions

A body whose text is fenced with \`\`\`suggestion posts as a GitHub suggestion the
author can
commit in one click.
Write the replacement exactly, leading whitespace included: it
replaces the lines the comment covers.

A suggestion has to hang from the RIGHT side and cover only lines the file that results
has, so a range crossing a removed line is refused when the comment is staged rather
than
when it is posted.

## Replies

`second-look get <pr>` caches the pull request's unresolved review threads, and
`second-look show <pr> --threads` prints them with the comment id each one answers.
Set
`in_reply_to` to that id and second-look sends the reply to its own endpoint.

Before replying to a bot thread, check whether a later commit already resolved it; close
a stale thread with a one-line pointer to the fixing commit instead of raising it again.

## Saying one thing now

`second-look post <pr> --only <id>` posts a single staged comment on its own, outside
any
review, and takes it out of the file.
It is for the finding that should not wait for the
rest of the review: a build broken for everyone, a secret in a diff.
The anchor guard runs
first and the rest of the review stays staged.
Ask before using it, the same as posting.

## Editing on a later pass

Reuse a comment's `id` and the edit replaces it; a new id appends a duplicate.
Once the
user has hand-edited a comment, treat it as settled.
A changed anchor or a factual
correction is fine.
Rewriting their sentence is not.
