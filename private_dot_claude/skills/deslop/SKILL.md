---
name: deslop
description: Strip AI slop from a README, docs, comments, or a diff before release. Invoke explicitly.
argument-hint: "[path, or 'diff with main']"
disable-model-invocation: true
---

# Deslop

Target: `$ARGUMENTS`, defaulting to the README plus anything changed against `main`.

Load the `writing-voice` skill and apply it. Do not restate the rules here — the six
rules, the tic catalog, and the corrective juxtaposition ban all live there and in
CLAUDE.md.

## What counts as slop

Prose that fails the six rules is only half of it. The rest is structure:

- Sections that exist because a generator makes them, not because a reader needs
  them — a Commands table restating `--help`, a Features list restating the intro, a
  Contributing section for a repo with one contributor, a Roadmap of things nobody
  plans to build
- Documentation that duplicates the code it sits above
- Comments narrating the change instead of stating a standing invariant ("now
  handles", "moved from", "was previously")
- Docstrings on private helpers whose signature already says it
- Tests that assert nothing, or that would still pass with the feature deleted
- Emoji headers and checkmark bullets
- Excess parameterization of the obvious, and DRY applied until it is unreadable

## Procedure

1. Read the target and name each violation before rewriting anything — which rule,
   which tic, which structural excess. "Sounds like AI" is not a finding.
2. Prefer deletion to rewriting. The strongest fix for a slop section is that it is
   gone.
3. Rewrite what survives, keeping every fact, number, and name unchanged.
4. Check code alongside docs when the target is a diff: dead parameters, redundant
   abstraction, verbosity, duplication.
5. Report what you cut and what you kept, in plain sentences.

Ask before deleting a whole section the user may have written themselves. The point
is removing generated filler, not editing their voice.
