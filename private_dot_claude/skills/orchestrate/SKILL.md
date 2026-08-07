---

## name: orchestrate description: Work a multi-phase plan to completion with subagents, checkpoint commits, and questions back to the user. Invoke explicitly with a plan document. argument-hint: "[@plan-file or phase description]" disable-model-invocation: true

# Orchestrate

Target: `$ARGUMENTS` — a plan file (`ROADMAP.md`, `docs/**/plans/*.md`), a phase name,
or nothing, in which case find the plan before doing anything else.

This is the standing contract for a long run.
It replaces the composite instruction the user would otherwise retype: coordinate
subagents, work through each phase in order, commit at checkpoints, and ask rather than
guess.

## Before starting: confirm scope

Read the plan, then use AskUserQuestion **once** to settle anything that would change
the work.
Do this before the first edit, not after phase one.

Ask about: which phases are in scope for this run, any that are already done or
obsolete, a genuine fork in approach the plan leaves open, and whether committing on
their behalf is wanted here.
Do not ask what you can determine by reading the repo, and do not ask permission to
begin.

If the plan is clear and the phases are unambiguous, say what you are about to do in two
lines and start.
A blocking question with nothing delivered is the failure mode to avoid.

## Per phase

1. Restate the phase in one line so scope is visible before work starts.
1. Fan out with subagents where the work is genuinely independent — separate modules,
    separate test files, research that would otherwise flood the conversation.
    Send parallel agents in a single message.
    Keep work in the main context when the phases are sequentially dependent; a subagent
    that has to be told everything you already know is slower than doing it.
1. Write the code, following the path-scoped rules that apply to the files touched.
1. Verify. Tests exist and pass, lint and type checks are clean.
    Check for a project-level run or test skill first, then fall back to the project's own
    commands (`mise run ...`, `hk check`, `uv run pytest`), never invented ones.
1. Exploratory testing where the thing can actually be run — launch the CLI, the TUI, the
    server, the site.
    A passing unit test is not evidence the feature works.
1. Commit at the checkpoint. Invoking this skill grants the commit exception in CLAUDE.md,
    so committing is the default; skip only if the scope question said not to.
    Conventional Commits, one readable subject line, no body unless the why is genuinely
    non-obvious.
    Never reference the AI, the model, or the session anywhere in the message.
1. Update the plan document: mark the phase done, record anything discovered that changes
    later phases.

## When to stop and ask

Ask through AskUserQuestion, mid-run, when a choice is genuinely the user's: a real fork
in design with different consequences, a phase whose premise turned out wrong, or scope
that has grown well past what the plan described.

Do everything that does not depend on the answer first, then ask.
Do not batch every uncertainty into one interrogation at the end, and do not stall the
whole run on a question you could resolve by reading code.

## Finishing

Clean up: no leftover scratch files in the repo, no commented-out code, no half-finished
branches of the plan left ambiguous.

Report in plain sentences — what changed, what failed, what comes next.
Lead with the lines that change the user's next action.
If a phase was skipped or blocked, say so explicitly and why; scaling the work down is
the user's call, not yours.
