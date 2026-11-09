---
name: hq-review-merge
description: Take a PR through HQ review (Coverbase's review and codegen bot, the coverbase-hq-bot app, formerly Watch Doggo) to a merge under a named policy profile, "involved" (never merge, ask Kyle) or "light" (merge on green after one HQ round). Use when asked to get a PR reviewed by HQ, to hand fixes to HQ, or to merge a PR in irm, hq, account-manager, or heyavocado; pr-pass and change-review-apply defer here for HQ interaction and merge policy.
argument-hint: <pr> [involved|light], e.g. '2821 light'
---

# HQ review and merge

Target: `$ARGUMENTS`, a PR (number or URL) and an optional profile.
With no profile, irm is `involved` and hq, account-manager, and heyavocado are `light`.
A profile Kyle names wins over the repo default.

## Get an HQ round

Every PR gets at least one HQ review of its current diff before it can merge.
Add the `hq-bot-review` label to request one.
A PR with no HQ review 30 minutes after its last push is an HQ bug: re-request once,
then record it under `hq_findings` instead of waiting.
When HQ is down and no review will come (no reply to the re-request, its service or
alarms show it broken), say so in the report and apply the profile without the round.

A push that only merges the base gets an HQ comment that its earlier review still
stands, and no new round.
That earlier review counts when `compare/<base>...<reviewed sha>` and
`compare/<base>...<head>` show identical files and patches.
Do not re-merge the base only because it moved: re-merge on a conflict, or when either
side adds a migration (two Alembic files off one parent do not conflict in git but
break Deploy).

An approval can still carry open threads.
Before landing a PR under three HQ rounds, run `ai-cr-review.py status --pr <n>` and
action any open thread with `change-review-apply`.
Record what HQ raised wrongly or missed as `hq_findings`
(`change-review-apply/references/challenging-bot-findings.md` has the bar).

## Fix in the cloud or locally

Hand a fix to HQ with the `hq-bot-fix` label when the findings are inside the PR's diff,
HQ's own finding says what to change, and the fix needs no local Docker, data, or
judgment call.
Fix locally when the fix spans a stack, needs a reproduction, or turns on product
intent, and when a local session already holds the branch.

A PR has one owner at a time.
Never push while an HQ fix round is in flight, because HQ's push is then rejected
(hq#2754): wait for its round reply before taking the PR back.
Before the first local push to a PR HQ opened, remove `hq-bot-maintained` so HQ's next
round does not race that push.

## Profiles

### involved

Never merge.
Once the PR is green, reviewed, and its threads are answered, open it in Chrome
(`open -a "Google Chrome" <url>`) and ask Kyle with AskUserQuestion; he merges or
queues it.
Batch these asks with any other open questions.

### light

Merge without asking once CI is green and HQ has reviewed the current diff once, with
`gh pr merge --squash --match-head-commit <full sha>`.
Workers never merge; the coordinating session does.

- When HQ's review blocks, read its findings: admin-merge (`--admin`) when they are
    wrong, minor, or better fixed forward, and report which findings were bypassed and
    why.
    Ask first only for a real security or data-loss finding, or a scope call
    that is Kyle's
- After round 3 with approval still missing, admin-merge and report why
- HQ never approves a PR it opened (author `app/coverbase-hq-bot`), so admin-merge those
    after a round with no blocking finding
- Open blocking findings at merge become fix-forward items on a follow-up PR
- Never propose a merge gate, a required override reason, or a ruleset change in
    response to a block.
    The person who merges owns the outcome, so improve HQ instead

## Repo exceptions

- irm and hq have a merge queue on main, and `--admin` skips it, so the PR is never
    tested on the latest main.
    Before an admin merge of a PR with a migration, compare
    its `down_revision` with origin/main's `alembic heads`.
    If main ends up with two
    heads, look for another session's head-merge PR before opening one
- A PR that ever had a child PR counts as stacked, and `gh pr merge` refuses it.
    Use
    `gh api -X PUT repos/coverbasedev/<repo>/pulls/<n>/merge-async -H "X-GitHub-Api-Version: 2026-03-10" -f merge_action=merge_queue -f sha=<full sha>`
    (no `merge_method`, which returns 422 with the queue), then poll
    `.../merge-async/<uuid>` for `merged`
- hq deploys itself: after a merge, check that the deploy and its alarms stay green.
    When a breakage gets no auto-fix PR, the work item is the auto-fix loop (trigger,
    dispatch, auto-merge, deploy), not the symptom

## Report

The PR link, the profile applied, the HQ rounds seen, the merge (or the question asked),
each bypassed finding with its reason, fix-forward items, and `hq_findings`.
