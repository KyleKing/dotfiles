---
name: tui-critique
description: On-demand UX critique for terminal UIs (Bubble Tea, Ratatui, Ink, Textual). Combines hyperskills:tui-design's layout/keybinding/color principles with impeccable's critique rigor (cognitive load, personas, heuristic scoring, P0-P3 severity), adapted for terminals — no CSS, no browser, no WCAG contrast math. Use when reviewing or critiquing a TUI's design, auditing keybinding discoverability, or checking terminal portability (NO_COLOR, monochrome degradation, multiplexer/SSH behavior).
---

# TUI Critique

A design director's review for a terminal app, evidenced by real screenshots, not
a read-through of the source.

## Procedure

1. Invoke `hyperskills:tui-design` first. Its seven principles and anti-pattern
   table are the vocabulary this critique judges against; don't restate them here,
   reference them.
2. Resolve the target: which binary/entry point, and which views or states matter
   (main screen, a specific modal, an empty state, an error state). Ask if unclear.
3. Capture visual evidence with VHS (below). Judge from the screenshots. A critique
   written from source code alone is a guess, not a review.
4. Score using the sections below.
5. Report using the structure below.
6. Close with 2-4 targeted questions tied to what was actually found, same spirit
   as impeccable's Ask-the-User step. Skip questions if there's only one or two
   clear issues.

## Visual capture with VHS

TUIs have no DOM, so there's no browser skill to reach for. [VHS](https://github.com/charmbracelet/vhs)
records real terminal frames instead, `Screenshot` gives a single still.

1. Build the binary fresh; don't critique a stale one.
2. Check for an existing `.tape` file in the repo (e.g. `.github/assets/demo.tape`)
   and reuse its theme/font/size settings so the capture matches how the project
   already presents itself, rather than picking new defaults.
3. Write a scratch `.tape` script in the scratchpad directory that drives the app
   through the states under review, with `Screenshot <path>.png` right after each
   state settles (post-render, not mid-animation).
4. Run `vhs <script>.tape`.
5. Read() every PNG before writing a single finding.
6. Also capture at least one non-default terminal condition relevant to the target:
   `NO_COLOR=1`, a narrow width (80x24), or `TERM=dumb` if the app claims to
   degrade gracefully. Claims of graceful degradation are unverified until seen.
7. Delete scratch `.tape`/`.png` files when done unless the user asked to keep
   them; don't commit capture artifacts to the repo.

## Health Score

Score 0-4 each, same bands as impeccable (36-40 excellent ... 0-11 critical,
scaled to /36 here since one heuristic is dropped). Nielsen's heuristics 1-9 carry
over almost unchanged; #10 (Help and Documentation) assumes searchable web docs
and is replaced with Terminal Portability, the TUI equivalent of cross-browser/
theming/a11y support.

| # | Heuristic | What to check |
|---|-----------|----------------|
| 1 | Visibility of System Status | Loading spinners, progress bars, status bar reflects current state |
| 2 | Match System/Real World | Domain language (git/jj terms), not raw flags or internal type names |
| 3 | User Control and Freedom | Esc always backs out one level; nothing traps input; long ops are cancellable |
| 4 | Consistency and Standards | Same key does the same thing in every view; vim conventions held throughout |
| 5 | Error Prevention | Destructive VCS ops (delete branch, force-push) confirm first |
| 6 | Recognition Rather Than Recall | Footer hints and `?` overlay exist; nothing works only if memorized |
| 7 | Flexibility and Efficiency | Keyboard shortcuts, batch/operator patterns, command mode for power users |
| 8 | Aesthetic and Minimalist Design | Chrome (borders, padding, decoration) stays subordinate to content |
| 9 | Error Recovery | Errors render in plain language in-app, not raw stderr/panic dumped to the pane |
| 10 | Terminal Portability | `NO_COLOR` respected, usable at 16-color/monochrome, survives tmux/zellij and SSH, no flicker from full redraws |

Be honest. Most real TUIs land 20-28/36, not 32+.

## Cognitive Load Checklist

Format-agnostic, unchanged from impeccable:

- Single focus: can the primary task finish without competing elements pulling attention?
- Chunking: is information grouped in ≤4-item clusters?
- Grouping: are related items visually grouped (borders, spacing, panels)?
- Visual hierarchy: is the single most important thing on screen obvious at a glance?
- One thing at a time: does the user resolve one decision before the next appears?
- Minimal choices: ≤4 visible options at any single decision point?
- Working memory: does the user need to remember something from a prior screen to act now?
- Progressive disclosure: is complexity (full keybinding list, advanced filters) hidden until asked for?

0-1 failures: low load. 2-3: moderate, address soon. 4+: critical.

## Personas

Reuse impeccable's five archetypes, re-grounded in a terminal:

- **Alex (power user)** — expects vim-consistent keys, command mode, batch operators. Red flags: any action that only has a mouse or menu path, unskippable animation, one-item-at-a-time work where batch is natural.
- **Jordan (first-timer)** — never used a TUI like this. Red flags: single-letter status codes with no legend, symbol-only columns, no discoverable `?` help, jargon in error text.
- **Sam (portability-dependent)** — runs with `NO_COLOR=1`, `TERM=dumb` or a 16-color terminal, or over a screen reader attached to the terminal emulator. Red flags: meaning conveyed by color alone, box-drawing/emoji that breaks the layout when unsupported, anything unusable below true-color.
- **Riley (stress tester)** — resizes the terminal mid-render, kills and reattaches the multiplexer session, feeds absurd inputs (0 repos, 500 repos, a repo name longer than the column). Red flags: layout that breaks on resize instead of reflowing, state lost on reattach, silent truncation with no indicator.
- **Casey (constrained connection)** — SSH or mosh from a phone terminal app, 80-column width, high latency. Red flags: important actions requiring a wide terminal to reach, heavy repaint that stutters over a slow link, no graceful narrow-width layout.

Pick 2-3 relevant to the target; walk the primary action through each; name the
exact screen and interaction that fails, not a generic description.

## Specialist Reviewers

The five personas above test whether the app works. These three test whether the
craft is good, each channeling one of impeccable's command groups
([impeccable.style/docs](https://impeccable.style/docs/)), translated out of CSS
into terminal-native concerns. Bring in whichever apply to the target; skip the
others.

- **Tone (Refine: animate, bolder, colorize, delight, layout, overdrive, quieter,
  typeset)** — judges visual craft, not function. Does motion (spinner cadence,
  transition on view change) convey state or just decorate? Is visual weight
  calibrated (one primary focus, 2-3 secondary, everything else quiet) or is the
  screen shouting/flat? Is color used strategically within the semantic-slot model
  or randomly? Are there small moments of personality (a well-chosen spinner, a
  satisfying success flash) that make the tool memorable rather than purely
  utilitarian? Is column/border/box-drawing rhythm consistent, the terminal
  equivalent of typography? Red flags: uniform visual weight throughout, color
  applied decoratively instead of semantically, animation that's just there
  because it's possible.

- **Reeve (Simplify: adapt, clarify, distill)** — judges what's kept vs. cut. Does
  the layout adapt to a narrow terminal by re-prioritizing (collapsing secondary
  columns, stacking panels) rather than silently truncating or amputating
  features? Is UX copy (error text, empty states, footer hints, modal labels)
  plain language a first-timer parses without translation? Is there decoration or
  chrome that earns no keep, border-for-border's-sake, a status column nobody
  reads, a header that repeats what the breadcrumb already said? Red flags: a
  narrow terminal that just clips instead of reflowing, jargon in copy meant for
  every user, visual elements that could be deleted with zero loss of function.

- **Priya (Harden: harden, onboard, optimize, polish)** — judges production
  readiness. Do edge cases render correctly: zero results, one result, a
  repo/branch name longer than its column, a terminal resized mid-render? Does
  the first-run experience (empty scan, no repos found, first launch with no
  config) show a path to value instead of a blank or cryptic screen? Is perceived
  performance solid, does feedback appear within ~100ms, do progressive-load
  placeholders look intentional rather than broken? Is there a final polish pass
  visible, consistent spacing, no stray misalignment, no leftover debug text? Red
  flags: an empty state that's just blank, a resize that corrupts the frame, any
  screenshot where something looks unfinished rather than intentionally minimal.

## Anti-Patterns

Score against `hyperskills:tui-design`'s ranked anti-pattern table directly
(color-across-terminals, flicker/full-redraw, undiscoverable keybindings,
Windows/WSL breakage, inconsistent Unicode, multiplexer incompatibility, missing
`NO_COLOR`, UI blocking past 100ms, unclear modal state, over-decorated chrome).
For a Lipgloss/Bubble Tea stack specifically, also check: colors hard-coded as hex
literals scattered through view code instead of referencing the shared styles
package, and whether long-running commands run as `tea.Cmd`s (async) rather than
blocking `Update`.

## Design Specificity Verdict

Lead the report with this, before scores. Does the layout, information density,
and interaction model feel authored for this domain, or could an unrelated
list-of-rows TUI use it unchanged? Judge before reading detector-style anti-pattern
output so the judgment isn't anchored by it.

## Severity

Same P0-P3 as impeccable: P0 blocks task completion, P1 causes real difficulty or
a portability failure, P2 is an annoyance with a workaround, P3 is polish. Tip: if
a user would file an issue about it, it's at least P1.

## Report Structure

1. **Method line**: which binary/commit, which states were captured, which
   non-default terminal condition was tested.
2. **Design Specificity Verdict**.
3. **Health Score table** (above), with a one-line key finding per heuristic.
4. **Overall Impression**: one paragraph, biggest opportunity named.
5. **What's Working**: 2-3 specifics, not generic praise.
6. **Priority Issues**: 3-5, tagged P0-P3, each with what/why-it-matters/fix, fix
   pointing at a concrete file (`internal/app/view_repolist.go:120`-style), not a
   vague suggestion. Before asserting a cause (not just a symptom), grep or read
   the source to confirm it. "This looks unaligned" is a screenshot observation;
   "unaligned because `statusColWidth` is a fixed 12 and never truncates" is a
   finding. A claim about *why* that isn't checked against source is a guess
   wearing a citation.
7. **Persona Red Flags**: 2-3 personas plus any specialist reviewers used, named failures.
8. **Minor Observations**.
9. **Questions to Consider**, tied to actual findings.

No command-fleet mapping (impeccable's `polish`/`harden`/etc. don't exist for Go
TUIs); point straight at the file and line to fix instead.
