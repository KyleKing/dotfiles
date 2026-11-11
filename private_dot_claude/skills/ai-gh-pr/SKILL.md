---
name: ai-gh-pr
description: Open a PR and write or refresh its AI Summary description through ~/.config/my_config/ai-gh-pr.py. Use whenever opening a PR, retitling one, refreshing its summary after a push, or attaching screenshots, in any repo without its own PR-writeup skill (irm uses irm-pr).
---

# AI Summary through ai-gh-pr

Every PR create, retitle, and summary goes through `~/.config/my_config/ai-gh-pr.py`
(`--help` per subcommand).
A repo with its own PR-writeup script or skill (irm's `irm-pr`) wins over this one.

`create <title>` opens the PR, `title <title>` retitles it, `get` prints the current
summary, and `describe <body>` replaces it, moving a legacy `AI Summary:` comment into
the description.
The summary lives in the description so reviewers skip the scroll, and this overrides
any skill that edits PR bodies another way.

Run `describe` right after `create`, unconditionally, unless the user says to skip it
for that PR.
Run it again whenever a push changes what the summary claims.
When the scope changes, retitle as well, since the title becomes the squash-merge
subject.

Link the ticket the PR works on as `[DEV-123](url)` in the summary.
A ticket in the title follows the repo's convention, because Linear links a PR from an
issue id in its branch, title, or description.
Where the PR tool places the id itself (irm's `create --ticket`), let it.

## Write for the reviewer who stops early

Lead with the point: the opening line says what the change does and why it matters.
Put what the reviewer needs to decide first, and the rest after it.

Write it as you would tell a teammate. Say "we" for this PR's work, use everyday words,
and never make an abstract noun the subject or coin a label the reader has not seen.

```markdown
Bad:  One predicate decides whether a document satisfies a requirement, and every reader calls it.
Good: We moved the scope check into one function that all six callers now use, and we cache its
      answer until the inputs change.
```

Size the summary to the change. A small PR is one line, a Context bullet or two, and
`How to test`.
Skip any section with nothing to say.

Include only what the reviewer cannot get from the diff or CI: why the change exists
(linked ticket, thread, or report, and what the user or tracker asked for), alternatives
that lost and why, the idea behind the design and what it gives up, what else it
reaches, and proof a claim rests on (the failing log line or stack trace, a before/after
latency or cost number, the script you ran and what it printed, security or performance
scenarios you tried, what a production dashboard says now).
Leave out a walk through the files, a restatement of the code, and the fact that tests
or lint passed.
A file-by-file explanation belongs in line-level review comments, if anywhere.

Before writing, read the ticket and its comments, the Slack or support thread, and
related PRs, so Context quotes the source instead of guessing.
With none, write "found while doing X".

## Shape

Every section is optional. Use these in this order and add no other heading:

```markdown
AI Summary: <what the PR does and why, in one or two sentences>

## Context
- <evidence, alternatives, or reach: one fact per bullet, linked>

## Approach
<given the Context, what we did, in one to three sentences>

## Screenshots
![before: <what it shows>](./before.png)
![after: <what it shows>](./after.png)

## Review guidance
- <a hunk to read closely, linked at the reviewed SHA, and what to check>
- [ ] <a call only a person can make>

## How to test
- <navigation path or METHOD /route> with <the state that matters>, expect <the result>
- Likely to break it: <the edges you did not exercise>

## Evidence
<what you ran by hand and what it printed>
```

Context is the facts the diff cannot show, never what the PR does.
Approach states the idea, not each change, and drops when the opening line already says
it.
Review guidance names at most three hunks, and a checkbox is only for a call CI or the
merge button does not gate.
How to test goes on every PR that changes behavior and never names a test or `make`
command.
Evidence is what you ran in this session, with long logs in `<details>`.

Screenshots: reference each file by local path with the label as alt text, then pass
`-- --attach ./after.png#after: <label>` to `describe`.
Run `get` afterward to confirm each URL landed.
Never link an image hosted elsewhere.
Upload the same files to the Linear issue the PR implements (named in the title or
branch):
one file at a time, `prepare_attachment_upload`, a curl PUT with the signed headers
verbatim
(the URL expires in 60s), then `create_attachment_from_upload`, and embed them in a
comment.

## Updating

`describe` replaces the whole summary, so run `get` first and edit what it returns.
Describe the PR as it stands: rewrite a claim a push invalidated, drop a stale
screenshot or a settled box, and never add a "Round 2" section.
Do not edit the script-added SHA and subject line.
