---
name: change-review-apply-retroactive
description: Sweep the pull requests you merged over a window for reviews nobody actioned, then land the surviving findings as one new PR and answer each original thread with a link to where the fix went. Use when asked to catch up on missed review feedback, action reviews on merged PRs, or find review threads left open behind you.
---

# Retroactive review sweep

A review that arrives at merge time or after it blocks nothing, so nobody reads it.
This
skill finds those, decides which findings are still real against current `main`, and
lands them as one pull request that links back to every thread it answers.

`change-review-apply` is the single-PR version and still owns any pull request that is
open: fixes there belong on that branch, where the reviewer can see them against the
diff they reviewed.
Bring a PR here only once it is merged.

## Step 1 — Sweep the window

Run from inside a checkout of the repository (the script reads `gh`'s repo context and
`git`):

```sh
~/.config/my_config/ai-cr-review.py sweep --since 7d      # --author, --repo, --limit
```

It searches the pull requests the author merged since that date and applies `status`'s
rule to each: a review with no thumbs-up that still carries an unresolved thread or a
`CHANGES_REQUESTED` verdict.
A pull request with nothing pending is left out, and
`scanned` says how many were read, so an empty result is an answer rather than a
misfire.
One read per pull request, about a second each.

**Carry each `review_id` into `fetch`.**

```sh
~/.config/my_config/ai-cr-review.py fetch --pr 14793 --review-id 5107979864 > cr-14793.json
```

Without `--review-id`, `fetch` picks the newest CodeRabbit review carrying a prompt
block, which on a merged pull request is routinely not the one the sweep flagged.
Passing the wrong one silently actions a review that was already answered.

A review whose author is the user themselves is self-notes on their own code, not
findings.
Report those rows and leave them: nothing to verify, nobody to reply to.

## Step 2 — Verify against current `main`, not the merged snapshot

`change-review-apply`'s Step 2 verdicts all apply, and `stale` carries most of the
weight here that it never does on an open PR.
The merge happened days ago, so a later
pull request may already have fixed the finding, moved the symbol, or deleted the file.
Read the file as it stands on `main` before writing anything down, and cite the commit
that beat you to it.

The reviewer's line numbers are anchors into a diff that is now history.
Find the symbol
by name; a thread with `is_outdated: true` was already anchored to a line the PR's own
later pushes moved, so its numbers are twice removed from `main`.

Everything in `outside_diff`, `unmatched_findings`, and `other_open_threads` is in scope
here rather than an escalation.
The escalation in `change-review-apply` Step 3 exists
because those have no thread on *that* PR to answer; a retroactive pass is already
writing a separate pull request, so a real one just becomes another commit in it.
Escalate to a ticket only what wants its own review: a redesign, a migration, a change
whose blast radius is wider than the batch.

## Step 3 — One branch off `main`, one commit per source PR

Branch under the requesting human's handle off current `main`, never off a merged head.
Keep one commit per source pull request even when its findings touch unrelated files,
because that is the unit a reviewer of the new PR checks against a review they can open.

The commit body is the exception to the usual no-body rule: one line naming the review
the commit answers, so `git log` carries the provenance the branch name cannot.

```
fix(dashboard): Hold the pending lock until the contract update lands

Answers https://github.com/org/repo/pull/14793#pullrequestreview-5107979864
```

Fix the class, not the cited line (`change-review-apply` Step 4), and stay inside what
the source PR touched.
Then run the repo's gates once over the combined diff.

## Step 4 — Open the PR before answering anything

The replies carry its URL, so the pull request exists first.
Open it with the repository's own PR tooling (`.agents/irm-pr.py` in the platform repo,
`~/.config/my_config/ai-gh-pr.py` elsewhere) and write the summary comment there:
what the sweep covered, one row per source PR, and which findings were declined.

## Step 5 — Answer each thread where it was left

One actions file per source pull request, applied against that pull request:

```sh
~/.config/my_config/ai-cr-review.py apply --pr 14793 --file pr-14793-coderabbit-actions.toml
```

Replies, resolves, and the thumbs-up all work on a merged pull request, so the original
thread ends up recording where the fix went rather than staying open forever.

**Every reply links forward.** A `fixed` verdict on an open PR needs no reply because
the diff shows it; here the diff is somewhere else entirely, so the link is the whole
point.
One sentence, in the user's voice under `change-review`'s rules, naming the change
and pointing at the commit:

```toml
[[actions]]
thread_id = "PRRT_kwDOKbit4c6fHy7N"
verdict = "fixed"
reply = "Fixed in https://github.com/org/repo/pull/14930 (commit abc1234) — the upload task now awaits the contract update, so the lock outlives it."
```

A skip verdict still needs its reason, and `stale` is the one to write carefully: name
the pull request or commit that already fixed it, because the reader's next question is
why a real finding is being closed with no change.

Bot reviews post without asking.
A human's reply waits on `replies_approved = true` and
the human's yes, which for a batch means putting every drafted reply in front of them
once rather than per pull request.

## Report

Lead with the window, how many pull requests were scanned, and how many carried
un-actioned reviews.
Then one row per source PR: findings, verdicts, and where the fix
landed.
Then the new PR's URL, what was escalated to a ticket, and the gate results.
