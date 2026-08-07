# Voice examples

Detailed backing for the Tone and Voice section of CLAUDE.md.
The six rules and the core bans live there; this file holds the before/after pairs, the
tic catalog, and the rewrite recipes so the always-loaded file stays lean.
Read this when rewriting existing prose, drafting landing copy, or when a draft keeps
failing the same way.

## The six rules, applied

Same sentence before and after the rules:

- Before: "Comprehensive error handling has been implemented across all API endpoints to
    ensure robust and reliable performance."
- After: "We added error handling to every API endpoint."

What changed: "comprehensive", "robust", "reliable", and "ensure" are gone (rule 2, rule
5), the passive turned active (rule 4), and 16 words dropped to 8 (rule 3).
Same facts.

More pairs:

- Before: "This utility facilitates the seamless synchronization of configuration state."
    → After: "This syncs config."
- Before: "In order to leverage the new caching layer, users must first initialize the
    client."
    → After: "To use the cache, initialize the client first."
- Before: "It should be noted that the migration was successfully completed."
    → After: "The migration is done." (or, if something failed, say what)
- Before: "We are excited to announce a host of powerful new capabilities."
    → After: name the capabilities.

## The tic catalog

Words and shapes to cut on sight. Presence of one is a signal to rewrite the sentence,
not to swap the single word.

- Achievement / marketing: comprehensive, robust, seamless, powerful, cutting-edge,
    best-in-class, effortless, elegant, delightful, leverage, utilize, facilitate, enable,
    ensure, unlock, streamline
- Session-report slop: "Successfully", "Perfect!", "Great!", emoji checkmarks (✅), "I've
    gone ahead and", walls of bullets where three sentences would do
- Throat-clearing openers: "It's worth noting that", "It should be mentioned that", "In
    today's fast-paced world", "At its core", "Simply put"
- Hedge-stacking: "may potentially", "could possibly", "somewhat generally"
- Filler intensifiers: "very", "really", "quite", "extremely", "incredibly"

### Corrective juxtaposition (the worst one)

The "not X, but Y" family. State Y directly.

- Bad: "This isn't just a linter, it's a whole workflow."
    → Good: "This is a workflow." (or, if the linter framing matters: "This started as a
    linter.
    It now runs the full commit workflow.")
- Bad: "It's not about speed, it's about correctness."
    → Good: "It optimizes for correctness over speed."
- Bad: "We didn't just fix the bug, we rethought the abstraction."
    → Good: "We reworked the abstraction; the bug is gone as a result."

The tell is the rhetorical setup: naming a thing only to negate it.
If the contrast carries real information, give X and Y their own plain sentences.

## Rewrite recipes

Prompts to run against existing text. Each keeps facts, numbers, and names unchanged.

### Existing README / docs / post

> Rewrite this text applying the six rules.
> First list every violation: each stale phrase, each long word with its short
> replacement, each cuttable word, each passive construction.
> Then give the rewrite. Keep every fact, number, and name unchanged.

### Commit messages and PR descriptions

> State what changed and why in plain words.
> No achievement language, no "comprehensive", no "robust".
> Apply the six rules. A reviewer should know what this does in one read.
> Summary first, then bullets, explain why not just what.

### Landing / hero copy

> Rewrite under the six rules. One concrete claim per line, short words, active voice.
> Run the swap test on every line: if a competitor could paste it onto their page
> unchanged, rewrite it or cut it.

### Progress / session reports

> Report in plain sentences: what changed, what failed, what comes next.
> No emoji checkmarks, no "Successfully", no "Perfect", no wall of bullets.
> Start with the few lines that change the next action; add detail only when it does.

## Why the word-by-word ban fails

Banning "delve", then "robust", then em dashes, one at a time, never converges — the
model finds a new tic each session.
The six rules are a system that catches the class, not the instance.
When a draft still reads wrong, name the rule or tic it broke (see "Rejecting a draft"
in CLAUDE.md) and fix that, rather than adding another word to a blocklist.
