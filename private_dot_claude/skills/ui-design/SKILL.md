---
name: ui-design
description: How to structure a web page so the reader's eye knows where to go. Use when designing or reviewing any UI (a mockup, a template, a dashboard, an internal tool page), when a page "has no focal point", reads as AI slop, or is a wall of equal-weight chips, boxes, and lines, and before building any page that asks a person for a decision. Carries the vocabulary (visual hierarchy, Gestalt grouping, progressive disclosure, action zone), the rules from Refactoring UI, Laws of UX, and NN/g, the page shapes for operate-mode tools, and the pre-ship checklist. sources.md has the citations.
---

# UI design: where the eye goes

A page works when a reader who has never seen it knows, in two seconds, what it is for,
what needs them, and what to press.
Everything else on the page is context and recedes.
This skill is the vocabulary to name what is wrong, the rules that fix it, and the
checklist to run before a page ships.
[sources.md](sources.md) has the citations.

## The diagnosis: three questions and the squint test

Run these on a screenshot before touching code, and write the answers down.

1. Where does the eye land first, second, third?
    Blur the screenshot (or squint) until
    the text is unreadable.
    What remains is the hierarchy the page actually has.
    If three
    or more things stay equally dark, the page has no focal point
1. What is the one thing this page wants the reader to do?
    If the answer is "it depends
    on the row", the page is a list and the row needs the focal point instead
1. What on the page is action and what is context?
    Action is a question, an input, a
    choice, a button.
    Context is everything that helps decide.
    If they are interleaved,
    the reader scrolls to find the input, which is the failure "I can't tell you need my
    answer"

The result of the diagnosis is one sentence: "the focal point is X, the action zone is
Y, everything else is context".
Build to that sentence.

## Vocabulary

Use these words in reviews, because "it looks busy" names nothing and "four focal
points of equal weight" names the fix.

- Visual hierarchy: the order the eye consumes elements, set by contrast, size,
    weight, color, position, and isolation.
    Three sizes at most, two large elements at
    most
- Focal point: the one element with the most contrast.
    One per screen, at the top of
    the reading order.
    The primary button and the one accented word belong to it
- Scan patterns: F-pattern (across the top, down the left) on text pages, layer-cake
    (headings only) on structured pages, spotted (hunting for a number or a link) on
    tables.
    Design for layer-cake and spotted on a tool page: headings and numbers have to
    carry the meaning alone
- Gestalt grouping: proximity (near means related), similarity (same shape means same
    kind), common region (inside one border or background means one group), uniform
    connectedness (a line or rail joins things).
    Whitespace groups before a border does.
    A border is the strongest grouping cue and the first one to overuse
- Chunking and Miller's law: working memory holds a handful of things.
    A row with seven
    chips is seven things. Three is the ceiling before the chips become noise
- Von Restorff (isolation) effect: the one element that differs is the one remembered.
    Accent color works only while it is rare
- Serial position: first and last are remembered.
    The first row and the last button
    matter most
- Progressive disclosure: the always-visible surface answers the common case and one
    expand gives the rest.
    Two levels at most. Each pointer says what the reader will
    find, so they can skip it
- Staged disclosure: a linear sequence, one step at a time (a reader that advances
    through items).
    Fine when steps are independent, wrong when the reader needs to go
    back and forth
- Action zone and context zone: the part of the page that takes input, and the part
    that informs it.
    They do not interleave
- Signifier and affordance: what shows an element can be pressed.
    A button looks like
    a button. A row that opens says so (chevron, hover, cursor)
- Information scent: a link or label that predicts what is behind it.
    "Evidence" is
    weak scent. "9 runs on this host this week, 2 timed out" is strong
- Density: how much fits in a viewport without the reader losing their place.
    Linear's
    rows are the reference for compact rows that still carry the fact that matters
- Doherty threshold: under 400 ms between press and response, or the reader loses the
    thread
- Jakob's law: readers expect the conventions of every other product.
    Settings under the
    account name, search under Cmd-K, Esc closes, Enter submits
- Hick's law: choice time grows with the number of options.
    Two buttons, not five
- Fitts's law: the target the reader needs most is big and close to where their
    pointer already is
- Tesler's law: some complexity cannot be removed, only moved.
    Put it on the side that
    can bear it (code, the dispatcher) rather than the reader
- Peak-end rule: the last step of a flow sets the memory of it.
    The "done, next" moment
    is designed, not defaulted

## The rules

From Refactoring UI, NN/g, and Laws of UX, compressed to what decides a page.

**Hierarchy**

- Not all elements are equal. Decide which element wins before styling any
- Hierarchy from weight and color before size.
    Two weights (regular, semibold) and
    three text colors (primary, muted, faint) carry most of it.
    Three font sizes plus
    mono
- De-emphasize to emphasize. To make the title stand out, make the metadata quieter
    rather than the title louder
- Labels are a last resort. "Owner: Gus" becomes "Gus" with an avatar or a position
    that says what it is.
    Uppercase micro-labels on every block are the slop tell
- One accent color, spent only on the thing that needs action.
    Finished items recede
    in opacity or weight.
    Secondary chips are grey
- Separate visual hierarchy from document hierarchy.
    An h2 may be small and quiet

**Grouping and lines**

- Start with too much whitespace, then take it away
- Group with spacing first, background second, border last.
    Before a border, ask "can
    spacing alone show this group?"
- Fewer borders. A section divider every 40 px turns a page into ruled paper.
    Replace
    with spacing, a background tint, or a single rail
- Cards are not the default. Sections of one story share one surface.
    Boxes are for
    things that are separately actionable
- Align to a grid of 4 or 8 px. Ambiguous spacing (a heading equidistant from the block
    above and the block below) breaks grouping

**Text and numbers**

- Line length 60 to 75 characters for prose
- Tabular numerals in tables and rows
- A date is relative in the row ("2h ago") with the absolute value on hover and copied
    on click.
    A row never shows three dot-joined timestamps
- A number without a reference is decoration: "320 ms" needs "p95 1.4 s" or a target
    or a trend beside it
- Front-load. The first two words of a row or a heading carry the meaning, because the
    layer-cake scan reads only those
- Do not rely on color alone for state. Pair it with a word or a shape

**Action and input**

- The action zone sits at the top of the pane the reader opened, in one surface:
    the question, the input, the primary button, the secondary button.
    Context follows
    beneath and scrolls
- One primary button per screen. Secondary is outlined or ghost.
    Destructive is never
    primary
- Explicit controls for moving between items (Previous, Next, Close) plus the keys.
    A key hint alone is not a control
- Every tooltip is a courtesy, never a requirement: nothing task-critical lives only in
    a tooltip.
    Chips, abbreviations, and compacted numbers get one on hover and on focus,
    consistently across every instance
- Empty states say what would fill them and how
- Under 400 ms, or show that something is happening

**Evidence and data**

- Show the data, not a sentence about the data.
    "2 of 9 timed out" becomes a nine-row
    table (when, host, outcome, link), or a strip of nine marks with the two in color
- A typed block per kind of evidence, each with one renderer: a count with a reference,
    a series with an axis, a table with a link per row, an event list with sources, a
    before/after.
    A model may choose which tool to call and with which parameters, and
    the tool's typed result picks the renderer.
    A model never authors the layout
- Every number and every id deep-links to its source, at the narrowest anchor the source
    offers
- A rendering with a sentence like "a diagram is one expand away" is a placeholder.
    Placeholders are labeled as such or removed

## Page shapes for a tool

Pick the shape from what the reader does on the page.

- A queue (Home, inbox): the focal point is the first item and the count.
    Rows are
    one line with the lead word first ("needs you", "with Doggo", "queued") and the title
    second.
    Opening a row is a staged reader with the action zone on top
- A list with state (Tasks): grouped by what the reader does next, in that order, with
    the group that needs them at the top.
    The group heading is quiet and the needed row
    carries the accent
- A story (an observation, an incident, a subject): title, one-paragraph dek, state,
    then milestones in time order with repeats collapsed, ids behind one expand
- A document (atlas): one column, a section rail, numbers at the top with references,
    then how it works, then what customers said.
    No cards
- A dashboard (Meta): a grid of number-with-reference tiles separated by spacing, each a
    link to the series behind it.
    No tile borders
- A command palette: search over everything, with a second level for a mode switch
    (view as, jump to) rather than a separate control in the chrome

## Pre-ship checklist

Run on desktop and at 390 px. Fix every miss before the review.

- [ ] Squint test: one focal point, at most two secondary
- [ ] The action zone is at the top of the opened pane and holds the input and both
    buttons
- [ ] Three font sizes plus mono, two weights, three text colors
- [ ] Accent color appears only on what needs action, and on at most one in ten elements
- [ ] Every border answered "spacing could not do this"
- [ ] At most three chips per row, each with a tooltip on hover and focus
- [ ] Every date is relative with the absolute value on hover
- [ ] Every number has a reference (target, baseline, trend, or denominator) and a link
- [ ] Every id, host, run, and customer deep-links
- [ ] Previous, Next, and Close are visible controls, and the keys are listed beside them
- [ ] Empty state written for every list
- [ ] No placeholder sentence standing in for data
- [ ] Nothing horizontal scrolls at 390 px except a table that says so
