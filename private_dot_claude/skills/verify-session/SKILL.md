---
name: verify-session
description: Audit whether a Claude Code session did what the user asked. Exports every user message and question-tool answer from the transcript, then dispatches a read-only subagent that independently checks each request against PRs, AWS, git, and files and critiques the decisions made. Use when asked to verify, audit, or check the work of a session, or whether everything the user asked for got done.
---

# verify-session

## 1. Export the requests

```bash
uv run ~/.claude/skills/verify-session/export_user_messages.py [session-id-or-path] -o <scratchpad>/requests.md
```

With no argument it takes the newest transcript for the current directory, which is
the running session.
Pass a session id (prefix is fine) or a `.jsonl` path to audit another one.
The export holds typed messages, messages sent mid-turn, and each question-tool
question with its options and the chosen answer.
Task notifications, system reminders, and subagent traffic are dropped.

Read the export first.
A question-tool answer is a decision or a new instruction (free-text answers often
add scope), so treat it as a request.

## 2. Dispatch one verifier

Spawn one `general-purpose` subagent on Sonnet (Opus only for a hard, ambiguous
audit).
Give it the export path, the transcript path, and this brief:

- Work through every numbered item in the export and extract each concrete ask
    (a deliverable, a fix, a question to answer, a constraint).
- Decide each ask independently from outside evidence: `gh` for PR state, diffs,
    reviews, and CI, `jj`/`git` read-only for commits, the files on disk, `tail-cw`
    (read its skill first) for AWS logs, metrics, and alarms, Linear or Slack when
    the ask names them.
- Use the parent transcript only to find where to look (PR numbers, paths, commands
    run) and what the agent claimed.
    A claim in the transcript is not evidence.
- Mark each ask `done`, `partial`, `not done`, or `unverifiable`, with the evidence
    (a link, a command and its output, a file and line).
    `unverifiable` names what access was missing.
- Take a critical eye to decisions: where the agent chose between approaches, took a
    recommended question-tool option without testing it, widened or narrowed scope,
    or reported success on a step that has no proof.
    Say which decisions you would reverse and why.
- Stay read-only: no commits, pushes, PR comments, ticket edits, or Docker.
    No worktrees and no new checkouts.

Ask for a short report: a table of `ask | status | evidence`, then a list of
questionable decisions, then the asks that remain open.

## 3. Report

Relay the table, the decision critique, and the open items.
Do not fix anything unless the user asks.
