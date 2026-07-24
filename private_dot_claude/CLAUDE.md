## General

- Verify claims rather than asserting them: web search, my input via the question tool, or data collected with Tools; ask for guidance or input when a choice is genuinely mine to make
- When debugging, identify multiple possible causes and reason/experiment to determine which explain the root cause
- On any choice touching security (secrets, auth, data exposure, privilege), favor the secure default and push back on convenience that widens exposure or grants more access than needed, even when I did not ask; name the tradeoff so I can decide

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT push
- ONE exception is when implementing a SEQUENCE of changes where committing at checkpoints is advisable, otherwise defer to me staging/committing
- When you do commit on my behalf, write the message in my voice: lowercase Conventional Commits (`feat(scope): summary`, `fix: summary`), a single readable subject line, and typically NO description body. Add a body only when the "why" is genuinely non-obvious from the subject
- NEVER reference the AI, the model, Claude, or Claude Code anywhere in a commit: no `Co-Authored-By` line, no model name, no session trailer, no "generated with" note. The commit must read as if I wrote it
- If files become staged, modified, or deleted outside of your own edits mid-session (e.g. working tree changes appear that you didn't make), do not restore, unstage, or otherwise fight them. This is likely me or another AI agent working in parallel. Just note it and flag for my review rather than acting on it

## Code Changes

- Limit modifications to what's necessary; don't refactor adjacent code or add docs/types/tests to unmodified functions

## Design Principles

- Favor functional-style: small, composable, single-responsibility functions
- Favor composition over inheritance
- Insert new items alphabetically into list-like structures; don't re-sort existing unordered lists

## Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: `pathlib.Path`, `defaultdict`, `Literal[...]`, `dataclass(frozen=True)`, `StrEnum`
- Prefer Python stdlib (e.g. argparse, not Typer)
- Pattern matching: `match`/`case` for destructuring or 3+ branches; `if`/`elif` fine for 1-2 conditions or complex predicates
- Walrus operator: `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- Never lazy import; all imports at top of file
- `__all__` only in `__init__.py`; refactor circular imports instead
- Multiline strings: use `textwrap.dedent()`, not implicit parenthesized string concatenation

## Comments and Documentation

- No inline comments; code should be self-explanatory
- No docstrings on private/internal self-explanatory functions
- Public API: one-line docstring when signature is clear; include args/returns/raises only when non-obvious; no type repetition; no numpy-style sections; no numbered comments
- Document non-obvious behavior (e.g. "Do not reuse after calling"), not types
- Comments and docstrings must be evergreen: state the standing invariant or constraint a future reader needs with no memory of the change. Never narrate the change or reference the diff ("now", "moved", "was", "runs after the commit above", "released before"). Change narration belongs in the PR description and commit message, not in the code. This holds even when the task is PR-focused; the "state the why" guidance under PR inline comments is about review-thread notes on a diff, a different audience from a future reader of the code
- Don't add or update docstrings for functions you didn't change

## Error Handling

- Let exceptions propagate unless you can handle them meaningfully
- Specific exception types; use `err` not `e` (e.g. `except Exception as err:`)
- Use custom exceptions for domain-specific errors
- Validate at system boundaries; trust internal code; parse-don't-validate

## Mermaid Diagrams

- Keep diagrams under ~15 nodes; group related items rather than enumerating individually
- Use the correct C4 type: System Landscape, C1 Context, C2 Container, C3 Component, Deployment, Dynamic
- `flowchart` for decision trees; `sequenceDiagram` for request/failure flows
- Put detail in reference tables below the diagram, not in node labels

## Files

- Never write markdown, notes, plans, or research output to the temp/scratchpad directory; write them in the current working directory or the project root instead
- The scratchpad directory is only for true intermediates that have no value after the task (e.g. a JSON blob being piped between steps)

## Tools

- Do not run Docker commands without instruction
- Python package manager: uv if `uv.lock`, poetry if `poetry.lock`, tox if `./tox`

### CLIs

- PostHog error tracking: the binary is `posthog-cli` but installed via mise. The agent-first surface is `posthog-cli api`: `search <regex>` to find tools, `info --json <tool>` for a schema, `call --json <tool> '<json>'` to run one. For "what errors are happening / being missed" use `query-error-tracking-issues-list` (defaults to active, last 7d, sorted by occurrences, test accounts filtered); pass `{"dateRange":{"date_from":"-30d"},"orderBy":"users"}` for impact. `assignee: null` across the board means nobody is triaging. Project is likely 420833 (`us.posthog.com`)
- Sentry: `sentry-cli` uses a personal read token (`~/.sentryclirc`). The `--org` flag goes AFTER the subcommand (e.g. `sentry-cli projects --org <org> list`), not before. There is no issues-list subcommand, so query issues via the REST API with the same token: `curl -H "Authorization: Bearer <token>" "https://sentry.io/api/0/projects/<org>/<project>/issues/?statsPeriod=24h&query=is:unresolved&sort=freq&limit=15"`. Useful `query` filters: `is:unresolved`, an endpoint path, `N+1`. Parse responses with `json.loads(..., strict=False)` (bodies contain raw control chars in SQL). Org/project slugs are project-specific — check that project's `CLAUDE.local.md`
- Hunk (interactive diff review): Drive a live session with `hunk session *` subcommands (`list`, `review --json`, `navigate`, `comment add/apply`). If no session exists, ask me to launch one. Skill at `~/node_modules/hunkdiff/skills/hunk-review/SKILL.md`

## Local OCR

- For bulk-triaging screenshots/images (e.g. sorting Desktop/Downloads clutter), use `npx mac-ocr <file>` for text extraction. It wraps Apple's Vision framework (the same on-device engine behind Preview's copy-paste), runs fully local/free, no API key, prebuilt binary via npm (no Xcode/Swift toolchain needed). No brew tap exists for it despite the name; `npx --yes mac-ocr` is the working invocation
- Only fall back to model-based (Read tool / vision) OCR for images mac-ocr can't parse (e.g. handwriting, heavy stylization) or when layout/semantic understanding beyond raw text is needed
- The Bash tool's sandbox has an intermittent bug with literal spaced file paths (`"foo bar.png"` fails to open even though the path is correct) — always cd into the directory and use a shell glob (`for f in Screenshot*9.35*; do ...`) or a variable instead of typing the literal spaced path, even with `dangerouslyDisableSandbox: true`

## Browser Screenshots

- At the start of any visual review session, ask for a target directory if one hasn't been specified
- `save_to_disk: true` on `computer`/`zoom` only embeds the image in conversation — it does NOT write a file. To persist a screenshot, follow up with `javascript_tool` to get the image as base64 (`document.querySelector('canvas')` or `chrome.tabs.captureVisibleTab`) and write it with the Write tool
- Use `gif_creator` instead of individual screenshots when verifying a multi-step interaction (e.g. opening a dropdown, hovering a tooltip, completing a form flow) — one GIF per feature is clearer than several stills and actually writes a file to disk with a returned path
- `gif_creator` only works on the agent's managed tab group — it fails with "not in managed tab group" in regular browser sessions; fall back to `mss` stills in that case
- `screencapture -x` in Bash lacks screen recording permission in the shell process — do not attempt it
- `html2canvas` fails on modern CSS `color()` function (used by many design systems) — do not attempt it

### Reliable mss capture workflow (when gif_creator is unavailable)

Use `mss` (Python) for pixel-perfect screenshots when the agent cannot use `gif_creator`:

1. **Click** UI elements via `computer` tool (works regardless of OS window focus)
2. **Activate the correct Chrome window** via URL-matching osascript — `tell application "Google Chrome" to activate` picks the wrong window when multiple exist; use this loop instead:
   ```applescript
   tell application "Google Chrome"
       repeat with w in windows
           set tIdx to 1
           repeat with t in tabs of w
               if URL of t contains "localhost:3000" then
                   set active tab index of w to tIdx
                   set index of w to 1
                   activate
               end if
               set tIdx to tIdx + 1
           end repeat
       end repeat
   end tell
   ```
3. **Capture** with `sleep 0.4 && python3 /tmp/capture.py <filename>.png` — the sleep lets Chrome finish painting after activation
4. **Verify** with `Read` on the output path

`/tmp/capture.py` template:
```python
import sys, mss, mss.tools
IMAGES_DIR = '/path/to/project/images'
REGION = {'left': 0, 'top': 33, 'width': 1512, 'height': 949}
def capture(filename):
    with mss.MSS() as sct:
        img = sct.grab(REGION)
        out = f'{IMAGES_DIR}/{filename}'
        mss.tools.to_png(img.rgb, img.size, output=out)
        print(f'saved: {out}')
if __name__ == '__main__':
    capture(sys.argv[1])
```

Adjust `REGION` to the display: `top: 33` skips the macOS menu bar; `width`/`height` match the Chrome window size.

- **Dark mode toggle**: `document.documentElement.classList.add('dark')` / `remove('dark')` via `javascript_tool`
- **macOS permission dialogs** (e.g. WezTerm screen recording prompt) will overlay Chrome and corrupt the capture — watch for them; `osascript keystroke return` requires Accessibility permission and may not dismiss them; the user may need to click Allow manually

## Tone and Voice

- "Voice" below governs text I author myself (messages, replies, docs, comments I write in my own words). It does NOT mean rewrite or paraphrase AI-generated analysis into something that sounds like me — that misrepresents authorship. When relaying your own research/analysis output (a summary, a comparison, findings from a search) into a human-facing surface like a PR comment, Slack message, or doc: write a short framing sentence in my actual voice (why I'm including this, what I want the reader to do with it), then paste your analysis verbatim in a fenced code block or clearly quoted/attributed section, unedited. Don't reformat it to match the bullet/paragraph/no-dash rules below — those apply to my own words, not to a quoted block. See how I pasted your sirv analysis in https://github.com/coverbasedev/irm/pull/13294#discussion_r3619540311 as the reference pattern.

### The writing system (Orwell's six rules)

These six rules govern all prose I author — docs, PR and commit text, messages, and the human-voice framing around your analysis. They never touch code, identifiers, or precise technical terms; swap in everyday words only where precision survives. Review every prose output against them before delivering. When rewriting existing text, first name each violation (stale phrase, long word with its short replacement, cuttable word, passive construction), then give the rewrite with every fact, number, and name unchanged.

1. Never use a metaphor, simile, or figure of speech you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if an everyday English equivalent exists.
6. Break any of these rules sooner than write something outright barbarous.

The tells these rules exist to kill: achievement and marketing language ("comprehensive", "robust", "seamless", "leverage", "ensure", "successfully", "delve"), throat-clearing openers, hedge-stacking, and passive voice that hides who did what. "We added error handling to every API endpoint" beats "Comprehensive error handling has been implemented across all endpoints to ensure robust performance." Before/after pairs and rewrite recipes for READMEs, landing copy, PR text, and session reports live in [voice-examples.md](voice-examples.md).

### Corrective juxtaposition — hunt this hardest

Never frame a point as "not X, but Y" / "it's not just X, it's Y" / "this isn't about X, it's about Y". It is the most recognizable current AI tell. State Y directly. If the contrast with X actually carries information, give it its own plain sentence instead of the rhetorical setup.

### Mechanical rules

- Use the Oxford comma in lists of three or more items ("branch, PR, and deploy state", not "branch, PR and deploy state")
- Keep emojis to a minimum
- Direct and action-oriented; no filler, no excessive enthusiasm, no vague language
- Technical precision: specific about implementation details and decisions
- Conversational but progressional: full sentences that move the reader forward, light first-person reasoning is fine, still no filler
- Organized: bullet points, sections, hierarchy
- Favor paragraphs and bullets over bare lists; don't turn everything into a list
- Don't start bullets with a bolded lead-in phrase followed by a colon (the "**Bold phrase:** sentence" pattern); write natural sentences instead
- No trailing period at the end of a bulleted list item (even when the item is a full sentence); keep internal punctuation as needed
- No em/en dashes: use parentheses for asides and clarifications, "because"/"which"/"where" for causal or relative clauses, a period or comma for list-end elaborations
- No semicolons joining independent clauses: split into two sentences, or move the second clause into parentheses if it is a short aside
- No idiom or cutesy phrases ("earns its keep", "pulls its weight", "hangs off", "belt and suspenders"); state the concrete benefit or relationship plainly
- PR descriptions: summary first, bullets, explain why not just what

### Rejecting a draft

When a draft reads wrong, don't just delete and retry. Name the exact reason it failed — which rule it broke, which tic it used (corrective juxtaposition, achievement language, passive voice) — so the failure mode is fixed, not banned one word at a time. "Sounds like AI" is not a reason; "opened with 'it's not just X'" is. Hold that reason across the session so the same tic doesn't come back in a new form.

### Progress and session reports

Report in plain sentences: what changed, what failed, what comes next. No emoji checkmarks, no "Successfully", no "Perfect", no wall of bullets. Lead with the few lines that change my next action and add detail only when it does.

### PR inline comments and review replies

- Self-notes on your own code: state the non-obvious "why" (constraint, invariant, workaround); don't restate what's already visible in the diff
- Review replies: acknowledge the bug briefly, state what was fixed, add a follow-up action if needed ("I will confirm X after the next deploy to Stage"). Don't re-explain why the bug was bad or what would have happened, and don't over-explain a fix that's visible in the diff — one sentence naming the change is enough
- Validate every file:line against code checked out locally (branch checked out, or fetched to `FETCH_HEAD` per the code-review skill's Step 0) before writing a comment — subagent and bot (CodeRabbit, Codex) findings routinely cite hallucinated line numbers (e.g. line 993 in a 137-line file). If the code can't be checked out or fetched, stop and say so rather than writing comments from `gh pr diff` text alone
- Hedge by default in every review comment, mine or staged for me: open with "I think", "maybe", "consider", or a question, and name more than one option rather than issuing a flat imperative ("Drop the default", "Pass X", "Set Y first"). This is the strong default, not a tie-breaker — write it this way on the first pass, do not draft flat directives and expect me to soften them. Reserve a plain unhedged directive for the rare case that is both trivial and unarguable (a typo, a wrong constant); when unsure whether a fix qualifies, hedge. A declarative fix I have to rewrite into a question is the failure mode this rule exists to prevent
- Before replying to a bot thread, check whether a later commit already resolved it (threads marked "✅ Addressed", or fixes visible in the diff); close stale threads with a one-line pointer to the fixing commit instead of re-raising them
- The human-facing comment text names the symbol (function, variable, constant), never `file:line` — the name locates it and line numbers drift. `file:line` belongs only in the inline anchor the AI uses to place the comment, and in the roll-up (below) where a concrete location helps an agent implement
- Write for a peer by default: give the observation and the ask, cut the mechanism, the why-it-matters, and the consequence a reviewer would already infer. Spell that rationale out only when I say the recipient is junior
- Don't add a `(line ###)` cross-reference to another comment in the same file just to help the reader locate it — only when the file has enough comments that it's genuinely ambiguous without one

#### The roll-up (PR-level summary)

- Must not restate the inline comments in prose. It's a copyable, AI-agent-friendly checklist with two parts: a short preamble condensing my working defaults (ask via your clarification tool when unsure, validate against current code before changing and skip already-handled items, keep edits minimal and scoped, run checks once at the end), then ready-to-implement action items, each with its `file:line` and enough detail to act on without reopening the thread. Frame as a consolidated post-review checklist, not a re-narration
- Format: `<details><summary>` wrapping a nested fenced ` ```markdown ` code block, matching CodeRabbit. The nested fence is what actually produces GitHub's hover copy button (tied to the `<pre><code>` a fence renders, not to `<details>` alone) — a plain `<details>` block, or a bare fence with no `<details>`, doesn't get it. Trade-off: content inside the fence is plain text, so checkboxes/bold/backticks don't render live — accepted cost for one-click copy
- Reference `file:line` directly in the roll-up (known before the review posts) so inline comments and the summary go up in one `gh api`/`gh pr review` step — skip the two-step pattern of posting first and patching links back in afterward

#### Staging the review before posting

- When asked to prepare review feedback for my sign-off, write a local `pr-<number>-review-comments.md` staging file for me to proofread and edit directly before posting, not a finished artifact
- Shape: group items under "New findings" and "Bot-thread replies", each grouped by file in diff order. One unquoted meta line per item, directly above its blockquote: `` `file:line` — severity — action `` where action is `new comment`, `reply to <bot> thread`, or `general review comment`. The blockquote holds only the exact text to post — no rationale or extra prose (the comment text already carries whatever "why" belongs on the peer, per the habits above). Close the file with the roll-up per the rule above
- No numbered IDs, no status field — I delete items I don't want. `[TODO: ...]` is reserved for my own edits requesting a revision before the next pass; use `[AI: ...]` when you need to flag an open decision or ask me something, so the two never collide
- A thread I decide not to reply to (already stale, or a nit not worth a comment) gets a meta line only, no blockquote, action `skip (<short reason>)` — e.g. `` `file:line` — nit — skip (style-only, not applying) ``. Keeps it visible as considered-and-declined rather than erased
- Once I've hand-edited a comment's text, treat it as settled on the next pass — don't re-polish it against the Voice rules above (those govern what you draft, not what I've already written; my phrasing may deliberately break them, e.g. a capitalized "OR" or an "etc.", as a personal tick, not an error to fix). Small, conservative edits are still fine when something's clearly needed (a changed anchor, a factual correction) — just don't rewrite the sentence wholesale
- When replying to a bot thread specifically (never a human's), I sometimes open the blockquote with `^` (e.g. `> ^I think this is valid...`) marking that the reply is about the author in the third person rather than addressed to them. Used selectively, not on every bot reply — preserve it where present, don't add or remove it on your own judgment
- Blockquote means post-facing, non-blockquote means for my eyes only. Everything inside a blockquote is verbatim text that will be posted and a reader will see; everything outside one (meta lines, orientation header, context snippets) exists to help me review and never ships. Keep the split strict so I can skim the file and know exactly what a reader gets
- For a bot-thread reply, put a bare permalink to the comment being replied to on (or just above) its meta line so I can open the original if I need it — don't paste the bot's comment or its diff inline, which bloats the file. New comments need no such context block; the meta line's `file:line` is enough
- Include a "Proposed PR comment" section rendered as one fully-blockquoted block: the post-facing summary/general comment in my voice, so I can read exactly what a reader sees. This is the human-voice framing; the copyable agent-checklist roll-up (above) is a separate `<details>` block appended to it when posted (keep the roll-up out of the blockquote so its fenced copy-button survives)
- When the PR is already merged, verify inline comments still post before proposing them: create a PENDING review with one throwaway inline comment via the API (`POST /repos/{o}/{r}/pulls/{n}/reviews` with `commit_id` + a `comments[]` entry, no `event` so it stays a draft invisible to others), confirm it anchors, then `DELETE` the pending review. Report the result. Frame the summary comment to acknowledge the merge and offer the nits as considerations for a follow-up PR rather than change requests

### Proposals and longer docs (Linear, design docs)

- Order: problem first, then options considered, then the decision; lead the reader to the conclusion rather than opening with it
- Trim to essentials and link or fold the rest; reviewers can ask for more
- Reference code by GitHub permalink only, if at all; avoid inline `file:line` references
- At most one or two collapsible `<details>` sections to keep the post scannable
- Tables stay compact (under ~120 chars wide) and high-level so they're easy to hand-edit; push detail into prose, not cells
- Validate any external links before including them; cite docs/blogs/SDK references where they back a claim
- Name concepts with common architecture or Python terms (responsibility, contract, Protocol, extension point) rather than coined metaphors like "seam"
- When proposing an abstraction, include thin pseudo-Python of current vs target so the delta is concrete; keep snippets reaction-sized, not implementation-ready
- Design-proposal diagrams should carry real detail: prefer a run-lifecycle sequenceDiagram plus an interface classDiagram over a single high-level flowchart (Linear renders mermaid natively)
