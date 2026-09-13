---
name: browser-screenshots
description: Capture and persist browser screenshots or GIFs for visual review of a web UI. Use when verifying a UI change visually, reviewing a page's design or layout, recording a multi-step interaction (dropdown, hover, form flow), toggling dark mode for a comparison shot, or when a screenshot needs to be written to disk rather than only shown inline.
---

# Browser screenshots

Ask for a target directory at the start of any visual review session if one has not been
specified.

## Picking a capture method

Try in this order. Each fallback exists because the one above it fails in a specific,
known way.

1. `gif_creator` for any multi-step interaction.
    One GIF per feature is clearer than several stills, and it actually writes a file to
    disk and returns the path.
    It only works on the agent's managed tab group — in a regular browser session it fails
    with "not in managed tab group".
1. `computer` with `save_to_disk: true` for a still, including one that must land on
    disk.
    It writes a `.jpg` under a temp directory and returns the path in the tool result.
    When the target is a `<canvas>`, `javascript_tool` can read it out
    (`canvas.toDataURL()`) for the Write tool instead.
1. `mss` stills driven from Bash, only when the browser tools are unavailable — a
    classifier denial, or a page outside the managed tab group.
    Full procedure in [mss-capture.md](mss-capture.md).
    It photographs the whole screen, so a macOS screen-recording prompt can overlay the
    shot and only the user can clear it.

## Dark mode

Check how the app themes before toggling.
The class toggle below covers Tailwind-style `.dark` setups; apps keyed off
`prefers-color-scheme` or a `data-theme` attribute need `window.matchMedia` emulation or
the attribute set instead.

```js
document.documentElement.classList.add('dark') // or .remove('dark')
```

## Methods that do not work

Do not spend turns rediscovering these.

- `screencapture -x` in Bash — the shell process lacks screen recording permission
- `html2canvas` — fails on the modern CSS `color()` function, which many design systems
    use
- `tell application "Google Chrome" to activate` on its own — picks the wrong window when
    several are open; use the URL-matching loop in [mss-capture.md](mss-capture.md)
