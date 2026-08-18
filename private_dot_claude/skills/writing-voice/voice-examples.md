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
- Borrowed-vivid verbs: "land"/"lands"/"landed", "paint"/"paints", "reach for", "dive
    into", "unpack", "tee up", "spin up".
    These read as conversational-AI register rather than Kyle's, and each has a plain
    replacement: a value *is returned* or *comes back*, a step *renders* or *shows* an icon,
    you *use* a tool, you *read* a file, you *explain* a design, you *set up* a stack.
    Exception: "wire up" / "wired up" is Kyle's own usage (AGENTS.md, workflow comments) and
    stays.

The verb bans govern drafts written for Kyle, not his existing prose.
Do not rewrite a doc he already wrote to remove them.

- Unnamed-scope qualifiers: "too", "also", "as well" tacked onto a claim without saying
    what else is in scope.
    Bad: "Might be worth adding it there too."
    Good: "Might be worth adding it to the compose-file list, since that's the other place
    someone would look for it."
    Name the other item or audience instead of gesturing at it.
- Evidence recitation: quoting timestamps, counts, and source text into a comment as
    though building a case the reader will contest.
    The reader can open the row. Name the thing and the doubt, keep the one number that
    prompted it, and cut the rest.
- Inferred-consequence clauses: closing on what the reader will feel or do about the
    finding ("anyone working the ledger will stop here", "this is the kind of row someone
    will re-check").
    The reader got there before you wrote it.
    End on the ask.
- Open questions with no proposed answer: ending on a bare "should we do X?"
    or "is this the right call?" leaves the reader to invent the alternative and reads as
    reflexive hedging rather than a real ask.
    State the lean, then ask for confirmation: not "should we reconcile these two docs?"
    but "I'd point the other doc at this one — does that hold, or is there a reason to keep
    them separate?"

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

### Review comments

The shortest format, and the one that drifts back to an assistant register fastest.
Open with the problem in plain words, not with a finding.
Propose the fix as "maybe we could" or a question carrying a lean.
Vary the shape across a batch so a review does not read as a template.

Length is not the rule, and cutting to a sentence budget is the wrong instinct.
Cut what the author can see for themselves; keep what they cannot.
A comment that carries a ticket's current status, a duplicate someone else filed, or a
merge date the author has not checked earns every line it takes.
A comment retelling the thread the author wrote does not.

Two register habits worth copying.
Conversational check tags ("right?", "either", "I think") invite correction inside the
sentence instead of hedging in front of it.
A doubt that survives goes in a trailing parenthetical ("(unless there is more to
address here?)")
rather than qualifying the claim before it lands.

> Rewrite this review comment. Open with the problem, not the finding.
> Replace any retelling of a source with a link to the exact place in it.
> Cut any clause about what the reader will conclude or do.
> Offer the fix as a maybe, and say what should happen instead of what breaks downstream.

Before, from a review of a status table:

> This row sits exactly on the qualifier. The alarm went off at 10:11 and cleared at
> 10:26, which is the 15 minutes the policy grades on, and the scope column says every
> user saw failures.
> Graded low with no owner named. If the alarm window is the evidence,
> it reads like the higher grade right at the boundary; if the window overstates the real
> loss, maybe say so in the cell, because anyone working the summary will stop here.

After:

> I'm not sure this should be the higher grade either, because it cleared almost exactly
> within the window, right?
> The linked fix also merged three weeks earlier, so the line about a fix not landing
> looks wrong (unless there is more to address here?).

What the first one broke: a spatial metaphor for a plain fact ("sits exactly on the
qualifier", "reads like"), a semicolon joining independent clauses, three sentences
retelling evidence the reader can open, and a closing clause about what the reader will
do.
What it missed: the second, checkable error sitting in the same cell.

## Why the word-by-word ban fails

Banning "delve", then "robust", then em dashes, one at a time, never converges — the
model finds a new tic each session.
The six rules are a system that catches the class, not the instance.
When a draft still reads wrong, name the rule or tic it broke (see "Rejecting a draft"
in CLAUDE.md) and fix that, rather than adding another word to a blocklist.
