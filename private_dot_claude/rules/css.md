---
paths:
  - '**/*.css'
---

# CSS

BEM was chosen deliberately over OOCSS, SMACSS, SUIT, and Tailwind
(`yak-shears/adr/0001-css-methodology-selection.md`).
Tailwind was rejected because
it "requires a build process, makes HTML less semantic".
Do not reintroduce it, and
do not suggest stylelint — the toolchain is Biome plus dprint's malva plugin.

## The rules from the ADR

- All new CSS follows BEM naming
- Each component gets its own CSS file
- Inline styles are prohibited except for dynamic values
- CSS files are imported through `main.css`

One block per component, `__` for direct children only (keep the element hierarchy
flat), `--` for modifiers, kebab-case for multi-word names.
Match the prefix already
in the project: `c-` in app-template (`.c-layout__main`), unprefixed in yak-shears
(`.header__bar`).

## Tokens and theming

Define custom properties in `:root` and override the whole set inside
`@media (prefers-color-scheme: dark)`.
Read tokens, never hardcode a value that a
token already names — this includes layout tokens like `--header-height`,
`--action-bar-height`, `--tap-target`, `--keyboard-inset`, and the
`--safe-bottom/left/right` safe-area set.

Cascade order is tokens, then base element defaults, then components.
Anything
unlisted appends alphabetically, so a new `styles/components/*.css` is picked up
without editing the build script.

Always ship a `@media (prefers-reduced-motion: reduce)` override and
`:focus-visible` outlines.

## Mobile

The breakpoint is 768px, duplicated as `MOBILE_BREAKPOINT` in the JS files that need
it — keep them in sync.

Use `dvh`, not `vh`. iOS Safari's `100vh` assumes a hidden URL bar and runs content
off-screen.

Fixed bars offset themselves from the `:root` tokens rather than hardcoded pixels.
Tap targets are at least `var(--tap-target)` (44px).

Use `overflow-x: clip`, not `hidden` — `hidden` stops a sticky header from sticking.

## Budget

Total assets stay under 14KB. There is no build step to tree-shake, so unused CSS is
a slow leak: the e2e suite measures rule coverage over CDP and fails below 90%.
A
rule no page exercises should not ship.
