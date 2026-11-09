---
name: design-review
description: Review the rendered screens of a change or an existing page for design, beyond the diff, and return a classified report. Use when asked for a design review, UX critique, or visual QA of any web UI in any repo, or before shipping a page that asks a person for a decision. Pairs with the ui-design skill, which holds the page-shape rules.
---

# Design review

Review what a user sees, the way a product designer does, and hand back a report.
The report is input for whoever acts on it (the author, their coding agent, a reviewer),
so this skill gathers, judges, and classifies.
It posts and fixes nothing.
A repo's own `design-review` skill or `DESIGN.md` wins where it disagrees.

## 1. Find the surfaces

1. Get the diff against the correct base. List every changed template, component, story,
    and string file.
    With no diff (a page review), start from the page and mark every
    finding `pre-existing`
1. Map each file to the route or story that renders it
1. Add one or two sibling pages with the same job and shape (another list, another detail,
    another settings pane).
    Consistency findings come from comparing them
1. Read the PR body and ticket for the job the change claims to do, and look for posted
    design direction (a Figma link, a direction doc).
    A diff that contradicts it is a finding
    even when the screen looks fine alone
1. Check what gates a surface (a feature flag, a role, an environment).
    Review both states
    unless the old path is designated legacy, and label each finding with the state it
    applies to

## 2. Get the rendered screens

Use the cheapest source that shows every state, and record which one each finding came
from:

1. Screenshots already on the PR (a starting point, rarely every state)
1. The PR or staging preview
1. The local dev server with seeded data
1. Storybook, for a component or a state that is hard to reach

Drive each surface through none, one, several, and a mix of records, the longest real
value, a missing value, a failure partway through, and the job around the surface (where
the user came from, what they do next, what happens to input when they leave).
Capture at
desktop width and at 390 px for anything a phone user opens.
Wait for loading to finish.
Read every screenshot before judging it, and give a screen you could not view no
finding.

When no source works, review from the code and say so in the report's header.
List the
questions that need pixels as not reviewed.
Never route around a login.

Before proposing to remove or restyle a line, border, divider, or icon, find what it
does
in the code that renders it.

## 3. Review

Walk in order:

1. The job: walk one realistic record through the change as the role it serves.
    A tidy
    screen that sends the user to the wrong place next is a finding, and so is polish the
    customer would not notice
1. The questions below
1. The `ui-design` skill: page shape, plain language, copy review
1. Every string on the screen, toasts, empty states, and errors included, read together
1. The code that renders each surface, for what a screenshot hides: a string built from
    fragments, a hardcoded string outside the message catalog, an internal id or enum shown
    raw, an icon-only control with no accessible name

### Questions

A finding blocks only when the screen misleads the user or loses their work (questions 2
to 8).
The rest are suggestions, one comment per surface, each naming the change.

1. Does the page answer the user's question before it explains the system?
1. Does every state name its owner when the surface holds several objects?
1. Does the layout for several keep what the layout for one shows?
1. Is there one status, and does it say whether the user must act?
1. Does an empty or failed result look empty or failed, and name the next step?
1. Does work in progress say what it waits on, since when, and until when?
1. Does the user's input survive leaving a modal, form, or page?
1. Does the copy promise only what runs today?
1. Is each disclosure worth its click? Collapse a group of detail, never one field
1. Do summary numbers read label first and filter the table they sit above?
1. Is each control where the user needs it, in its plainest form, with the next step
    carrying the primary weight?
1. Does a run the user waits on show progress and say what it did when it ends?
1. Does the page behave like its siblings (default selection, search position, primary
    action, how an object opens)?
1. Is navigation one level deep? No tab set inside a tab set, no stacked nav panels
1. Does each action have one control, and is exactly one action primary?
1. Is the evidence beside the claim it supports?
1. Does configuration stay out of the daily view, with live changes behind a publish step?
1. Can the user fill a structured field without learning its syntax?
1. Does each new string reuse an existing message-catalog entry?
    Homonyms stay separate

Polish: alignment and the spacing scale, content squeezed by its container, copy a
person
would say, readable contrast and line length, a failure that says what to do, an error
that
clears when its cause does, shared button variants, a multi-select that shows its picks
one
way, internal values on screen, and a summary and its detail answering the same
question.

## 4. Classify each finding

- **Where:** route or story, component file, gate and state, screenshot
- **What:** a problem and fix pair: the failure as the user meets it, then the change to
    make.
    A finding that only names a pattern ("feels cluttered") is not one
- **Severity:** `blocking` or `suggestion`, by the rule above
- **Relation to the diff:** `introduced`, `exposed` (existed, now reachable or more
    visible),
    or `pre-existing`
- **Disposition:** `this PR` (small, and the diff already touches the code), `stacked PR`
    (same area, would widen the review), `ticket` (larger, cross-page, or pre-existing),
    `design decision` (changes a shared pattern, needs direction before anyone builds), or
    `drop` (the path retires, or the finding is polish on a legacy path)

A finding on a shared component lists the other pages it would change.
Findings with one
cause become one finding that names every place.

## 5. Report

Open with: "These findings are not limited to the diff.
Whoever acts on this report decides
what is in scope."
Then: sources (what was reviewed, which states and viewports, any source
that failed), blocking findings most harmful first, suggestions grouped by disposition,
dropped findings with reasons, open questions, and the questions that read clean (so a
skipped area and a cleared one look different).

Write each `ticket` or `design decision` finding so it pastes as an issue: a title
naming
one problem and the surface, the user-visible failure, the screenshot, and the gate.
One
ticket names one design problem, never a whole-area redesign.
