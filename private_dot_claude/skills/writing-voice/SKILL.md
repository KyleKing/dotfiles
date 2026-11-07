---
name: writing-voice
description: The user's full writing system for prose they author — README and docs text, landing copy, PR and commit descriptions, Linear proposals, design docs, Slack and email messages. Use when drafting or rewriting any human-facing prose, when a draft reads like AI wrote it, when stripping AI slop from documentation, or when relaying research output into a human-facing surface. CLAUDE.md carries the compressed rules; this carries the reasoning, the before/after pairs, and the per-format shapes.
---

# Writing voice

CLAUDE.md holds the always-on version: Orwell's six rules, the corrective juxtaposition
ban, and the mechanical rules.
Those are the floor and they apply whether or not this skill is loaded.
What follows is the reasoning behind them and the parts that only matter for a specific
format.

## What this governs

Prose the user authors themselves: messages, replies, docs, comments in their own words.

It does **not** mean rewriting AI-generated analysis into something that sounds like
them — that misrepresents authorship.
When relaying your own research or analysis into a human-facing surface (a PR comment, a
Slack message, a doc): write a short framing sentence in their actual voice (why they
are including this, what they want the reader to do with it), then paste the analysis
verbatim in a fenced code block or a clearly attributed section, unedited.
Do not reformat it to match the bullet, paragraph, or dash rules below — those apply to
their words, not to a quoted block.

Reference pattern:
https://github.com/exampleco/platform/pull/1234#discussion_r0000000000

## The six rules

1. Never use a metaphor, simile, or figure of speech you are used to seeing in print.
1. Never use a long word where a short one will do.
1. If it is possible to cut a word out, cut it out.
1. Never use the passive where you can use the active.
1. Never use a foreign phrase, a scientific word, or a jargon word if an everyday English
    equivalent exists.
1. Break any of these rules sooner than write something outright barbarous.

They never touch code, identifiers, or precise technical terms.
Swap in everyday words only where precision survives.
Review every prose output against them before delivering.

When rewriting existing text, first name each violation (stale phrase, long word with
its short replacement, cuttable word, passive construction), then give the rewrite with
every fact, number, and name unchanged.

Worked before/after pairs, the full tic catalog, and ready-to-run rewrite prompts:
[voice-examples.md](voice-examples.md).

## Hollow is slop too

Slop fails in two directions.
Inflated prose reaches for marketing words, metaphors, and flourish, and cutting tells
fixes it.
Hollow prose is plain on the surface and says nothing: "All documents and what they say"
names a feeling about a link instead of where it goes.
Only saying something fixes hollow prose, so write toward the fact first and sweep for
tells after.

Read the sentence aloud as if you were telling a colleague on a call.
If you would never say it, or would have to explain it afterwards, rewrite it.

Hollow tells, each a reason to rewrite the sentence:

- Feeling for mechanism ("everything in one place"): name the behavior or object.
    If the sentence could sit unchanged in another product or doc, cut it
- Vague link words ("associated with", "related") when the relation is known
- Taglines: a sentence under a heading that restates the heading
- Leaked internals in reader-facing text: ids, enum values, env vars, HTTP codes, raw
    exception text appended to a sentence, and the services behind a feature
- Over-compression: arrows, dropped articles, and verbless fragments inside a sentence.
    Labels, table cells, and status lines may stay short
- Unnamed actor, when the actor is known and matters

Shapes that are tells regardless of wording: "serves as" or "stands as" for "is",
"Think of it as…" in place of what the thing does, punchy fragments ("No setup.
No
waiting."), forced threes (use the number of items there are), a trailing "-ing" clause
("…, ensuring every vendor is covered"), and synonym cycling (one concept keeps one
name).

When a rewrite needs a fact you don't have (a count, a cause, a time), leave a marked
slot and ask.
Never invent the number.

## Short UI and status copy

Each element has a job, and a string with no tells can still fail it:

- Button: the verb and the object of the outcome ("Send questionnaire", never "Submit")
- Link: the destination, in words that match the page it opens
- Toast: the result in past tense ("Portal created"), no "successfully" and no "!"
- Empty state: what is missing and the one action that fills it
- Error: own the failure, give the cause, name the next step ("We couldn't sync: the
    integration user can't read incidents.
    Ask your admin to grant that role").
    "We'll look into it" is a promise a screen can't keep
- Destructive confirm: the title asks the action ("Delete this vendor?"), and the body
    says what goes with it and whether it can be undone
- Helper text: a consequence, limit, or format the label can't carry, in one or two
    sentences

In a repo with its own copy skill (irm's `unslop`), that skill's voice and scope win for
product strings.

## Rejecting a draft

When a draft reads wrong, do not just delete and retry.
Name the exact reason it failed — which rule it broke, which tic it used — so the
failure mode is fixed rather than banned one word at a time.
"Sounds like AI" is not a reason; "opened with 'it's not just X'" is.
Hold that reason across the session so the same tic does not come back in a new form.

Banning "delve", then "robust", then em dashes, one at a time, never converges.
The six rules catch the class, not the instance.

## Proposals and longer docs (Linear, design docs)

Order: problem first, then options considered, then the decision.
Lead the reader to the conclusion rather than opening with it.

Trim to essentials and link or fold the rest; reviewers can ask for more.

Reference code by GitHub permalink only, if at all.
Avoid inline `file:line` references.

At most one or two collapsible `<details>` sections, so the post stays scannable.

Tables stay compact (under ~120 characters wide) and high-level so they are easy to
hand-edit.
Push detail into prose, not cells.

Validate any external links before including them.
Cite docs, blog posts, or SDK references where they back a claim.

Name concepts with common architecture or Python terms (responsibility, contract,
Protocol, extension point) rather than coined metaphors like "seam".

When proposing an abstraction, include thin pseudo-Python of current versus target so
the delta is concrete.
Keep snippets reaction-sized, not implementation-ready.

For diagrams, load the `mermaid-diagrams` skill rather than restating its rules here; it
covers type selection and density, and Linear renders mermaid natively.
