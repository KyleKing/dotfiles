---
name: audit-project
description: Audit a repository's state and condense scattered notes into a phased ROADMAP.md. Invoke explicitly.
argument-hint: "[optional focus, e.g. 'test quality' or 'duplication']"
disable-model-invocation: true
---

# Audit project

Take stock of a repo and turn whatever notes are lying around into a plan that
`/orchestrate` can execute. Optional focus: `$ARGUMENTS`.

This is read-and-write-one-file work. Do not start implementing.

## Gather

Fan out with subagents; these are independent and each one would otherwise flood the
conversation.

- **State**: README, docs, existing ROADMAP or TODO, open issues and PRs, recent
  commits, branches that never merged. What did past-you intend that never landed?
- **Scattered notes**: TODO and FIXME comments, `docs/` drafts, `notes/`, ADRs
  without a decision, stale plan files under `docs/**/plans/`, commented-out code.
- **Code quality**: duplication, verbosity, complexity, dead code, AI slop in docs
  and comments.
- **Test quality**: coverage gaps, tests that assert nothing, tests that would pass
  if the feature were deleted, missing parameterization.
- **Tooling**: whether lint, type checks, and pre-commit actually run and pass right
  now. Report what fails rather than fixing it.

## Judge

Weigh candidates on what the user actually optimizes for: KISS, UX and DX,
performance where it is measurable, and removing things over adding them. A phase
that deletes code is worth as much as one that adds a feature.

Separate what is genuinely broken from what is merely unfinished, and both from what
was abandoned on purpose. Say when something looks abandoned rather than assuming it
is a gap.

## Write ROADMAP.md

Write to the repo root. Problem first, then what was considered, then the phased
plan — lead the reader to the conclusion.

Phases are ordered by dependency, then by value. Each phase gets a one-line goal, the
concrete work items, and how to tell it is done. Keep it reaction-sized; a roadmap
nobody reads is worse than none.

Note explicitly what you decided to leave out and why.

## Then ask

Use AskUserQuestion on what the audit surfaced and the user has to decide: which
phases matter, anything that looks abandoned and might just be deleted, and any fork
you found where the repo could go two ways.

Do not commit. Do not begin implementing. Hand back the roadmap and the questions.
