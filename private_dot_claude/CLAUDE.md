## General

- Avoid emojis

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT commit NOR push

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

- Direct and action-oriented; no filler, no excessive enthusiasm, no vague language
- Technical precision: specific about implementation details and decisions
- Conversational but progressional: full sentences that move the reader forward, light first-person reasoning is fine, still no filler
- Organized: bullet points, sections, hierarchy
- Favor paragraphs and bullets over bare lists; don't turn everything into a list
- Don't start bullets with a bolded lead-in phrase followed by a colon (the "**Bold phrase:** sentence" pattern); write natural sentences instead
- No trailing period at the end of a bulleted list item (even when the item is a full sentence); keep internal punctuation as needed
- No em/en dashes: use parentheses for asides and clarifications, "because"/"which"/"where" for causal or relative clauses, a period or comma for list-end elaborations
- No semicolons joining independent clauses: split into two sentences, or move the second clause into parentheses if it is a short aside
- PR descriptions: summary first, bullets, explain why not just what

### PR inline comments and review replies

- Self-notes on your own code: state the non-obvious "why" (constraint, invariant, workaround). Trim closing sentences that explain consequences the reader can infer
- Review replies: acknowledge the bug briefly, state what was fixed, add a follow-up action if needed. Don't re-explain why the bug was bad or what would have happened
- Follow-up actions: "I will confirm X after the next deploy to Stage" format
- Don't over-explain: if the fix is visible in the diff, one sentence naming the change is enough

### Proposals and longer docs (Linear, design docs)

- Order: problem first, then options considered, then the decision; lead the reader to the conclusion rather than opening with it
- Trim to essentials and link or fold the rest; reviewers can ask for more
- Reference code by GitHub permalink only, if at all; avoid inline `file:line` references
- At most one or two collapsible `<details>` sections to keep the post scannable
- Tables stay compact (under ~120 chars wide) and high-level so they're easy to hand-edit; push detail into prose, not cells
- Validate any external links before including them; cite docs/blogs/SDK references where they back a claim
