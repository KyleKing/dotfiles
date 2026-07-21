## General

- Verify claims with web search, my input, and/or data that can be collected with Tools
- In general, web search and ask me for guidance/input with the question tool as needed
- When debugging, identify multiple possible causes and reason/experiment to determine which explain the root cause

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT push
- ONE exception is when implementing a SEQUENCE of changes where committing at checkpoints is advisable, otherwise defer to me staging/committing. NEVER include the AI model used in the description
- If files become staged, modified, or deleted outside of your own edits mid-session (e.g. working tree changes appear that you didn't make), do not restore, unstage, or otherwise fight them. This is likely me or another AI agent working in parallel. Just note it and flag for my review rather than acting on it

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

## Code Changes

- Limit modifications to what's necessary; don't refactor adjacent code or add docs/types/tests to unmodified functions

## Files

- Never write markdown, notes, plans, or research output to the temp/scratchpad directory; write them in the current working directory or the project root instead
- The scratchpad directory is only for true intermediates that have no value after the task (e.g. a JSON blob being piped between steps)

## Mermaid Diagrams

- Keep diagrams under ~15 nodes; group related items rather than enumerating individually
- Use the correct C4 type: System Landscape, C1 Context, C2 Container, C3 Component, Deployment, Dynamic
- `flowchart` for decision trees; `sequenceDiagram` for request/failure flows
- Put detail in reference tables below the diagram, not in node labels

## Comments and Documentation

- No inline comments; code should be self-explanatory
- No docstrings on private/internal self-explanatory functions
- Public API: one-line docstring when signature is clear; include args/returns/raises only when non-obvious; no type repetition; no numpy-style sections; no numbered comments
- Document non-obvious behavior (e.g. "Do not reuse after calling"), not types
- Don't add or update docstrings for functions you didn't change

## Error Handling

- Let exceptions propagate unless you can handle them meaningfully
- Specific exception types; use `err` not `e` (e.g. `except Exception as err:`)
- Use custom exceptions for domain-specific errors
- Validate at system boundaries; trust internal code; parse-don't-validate

## Tools

- Do not run Docker commands without instruction
- Python package manager: uv if `uv.lock`, poetry if `poetry.lock`, tox if `./tox`

### CLIs

- PostHog error tracking: the binary is `posthog-cli` but installed via mise. The agent-first surface is `posthog-cli api`: `search <regex>` to find tools, `info --json <tool>` for a schema, `call --json <tool> '<json>'` to run one. For "what errors are happening / being missed" use `query-error-tracking-issues-list` (defaults to active, last 7d, sorted by occurrences, test accounts filtered); pass `{"dateRange":{"date_from":"-30d"},"orderBy":"users"}` for impact. `assignee: null` across the board means nobody is triaging. Project is likely 420833 (`us.posthog.com`)
- Sentry: <TODO update now that the personal, not org, Sentry-CLI token has been given READ access>
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

- Keep emojis and dashes to a minimum
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

### PR inline comments and review replies

- Self-notes on your own code: state the non-obvious "why" (constraint, invariant, workaround). Trim closing sentences that explain consequences the reader can infer
- Review replies: acknowledge the bug briefly, state what was fixed, add a follow-up action if needed. Don't re-explain why the bug was bad or what would have happened
- Follow-up actions: "I will confirm X after the next deploy to Stage" format
- Don't over-explain: if the fix is visible in the diff, one sentence naming the change is enough
- Validate every file:line against the checked-out code before writing a comment; subagent and bot (CodeRabbit, Codex) findings routinely cite hallucinated line numbers (e.g. line 993 in a 137-line file), so re-read the real file and pin the true line
- The code must be checked out locally (branch checked out, or fetched to `FETCH_HEAD` per the code-review skill's Step 0) before generating any file:line comment. If it can't be checked out or fetched, stop and say so rather than writing comments from `gh pr diff` text alone
- Default to the same hedged framing I use when reviewing: "maybe", "consider", or naming more than one option, rather than a flat directive. Drop the hedging and state the fix plainly only when it's simple and obviously correct
- Before replying to a bot thread, check whether a later commit on the branch already resolved it (threads marked "✅ Addressed", or fixes visible in the diff); close stale threads with a one-line pointer to the fixing commit instead of re-raising them
- The human-facing comment text names the symbol (function, variable, constant), never `file:line`, because the name locates it and line numbers drift. `file:line` belongs to two other places only: the inline anchor the AI uses to place the comment, and the rolled-up copyable summary block (below) where a concrete location helps an agent implement
- Write for a peer by default, giving the observation and the ask while cutting the mechanism, the why-it-matters, and the consequence a reviewer would already infer. Spell that rationale out only when I say the recipient is junior
- The PR-level summary must not restate the inline comments in prose. Make it a copyable, AI-agent-friendly roll-up wrapped in a CodeRabbit-style `<details><summary>` block (not a backtick code block — that flattens the markdown, so checkboxes and bold stop rendering and it can't collapse) with two parts: a short preamble condensing my working defaults (ask via your clarification tool when unsure, validate against current code before changing and skip already-handled items, keep edits minimal and scoped, run checks once at the end), then ready-to-implement action items drawn from the comments, each with its `file:line` and enough detail to act on without reopening the thread. Frame the items as a consolidated post-review checklist, not a re-narration
- The roll-up references `file:line` directly, which is known before the review posts, so inline comments and the summary go up in one `gh api`/`gh pr review` step. Skip the older two-step pattern of posting first and patching comment URLs back into the summary afterward
- When asked to prepare review feedback for my sign-off, write a local `pr-<number>-review-comments.md` staging file for me to proofread and edit directly before posting, not a finished artifact. No numbered IDs and no status field: I delete items I don't want, and where I want a revision before the next pass I leave an unquoted `[TODO: ...]` note next to that item. Reserve `[TODO: ...]` for my own edits; when you need to flag an open decision or ask me something before finalizing an item, use `[AI: ...]` instead so the two never collide
- Shape of that staging file: group items under "New findings" and "Bot-thread replies", each grouped by file in diff order. For every item, one unquoted meta line directly above the blockquote, in the form `` `file:line` — severity — action `` where action is `new comment`, `reply to <bot> thread`, or `general review comment`. The blockquote itself holds only the exact text to post, with no rationale or extra prose folded in (the comment text already carries whatever "why" belongs on the peer, per the habits above). Close the file with the roll-up summary block per the rule above
- When I decide a thread doesn't need a reply (already stale, or a nit not worth a comment), represent it as a meta line only with no blockquote below it, action `skip (<short reason>)` — e.g. `` `file:line` — nit — skip (style-only, not applying) ``. This keeps the item visible as considered-and-declined rather than erasing it
- Once I've hand-edited a comment's text in the staging file, treat it as settled on the next pass: don't re-polish it against the general Voice rules above, since those govern what you draft, not what I've already written. My phrasing may deliberately break them (a capitalized "OR", an "etc.") as a personal tick, not an error to fix. Small, conservative edits are still fine when something's clearly needed (a changed anchor, a factual correction) — just don't rewrite the sentence wholesale
- When replying to a bot thread specifically (never a human's), I sometimes open the blockquote with `^` (e.g. `>^I think this is valid...`) as a marker that the reply is about the author in the third person rather than addressed to them. I use it selectively, not on every bot reply — preserve it where I've used it and don't add or remove it on my own judgment
- Don't add a `(line ###)` aside pointing to another comment in the same file just to help the reader locate it. Only do this when the file has enough comments that the cross-reference is genuinely ambiguous without one

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
