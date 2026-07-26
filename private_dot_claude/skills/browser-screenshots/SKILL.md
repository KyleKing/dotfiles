---
name: browser-screenshots
description: Capture and persist browser screenshots or GIFs for visual review of a web UI. Use when verifying a UI change visually, reviewing a page's design or layout, recording a multi-step interaction (dropdown, hover, form flow), toggling dark mode for a comparison shot, or when a screenshot needs to be written to disk rather than only shown inline.
---

# Browser screenshots

Ask for a target directory at the start of any visual review session if one has not
been specified.

## Picking a capture method

Try in this order. Each fallback exists because the one above it fails in a
specific, known way.

1. `gif_creator` for any multi-step interaction. One GIF per feature is clearer
   than several stills, and it actually writes a file to disk and returns the path.
   It only works on the agent's managed tab group — in a regular browser session it
   fails with "not in managed tab group".
2. `computer` / `zoom` with `save_to_disk: true` for a single still. Read the
   warning below before relying on it.
3. `mss` stills driven from Bash, when `gif_creator` is unavailable. Full procedure
   in [mss-capture.md](mss-capture.md).

`save_to_disk: true` does **not** write a file. It only embeds the image in the
conversation. To persist that screenshot, follow up with `javascript_tool` to read
the image as base64 (`document.querySelector('canvas')` or
`chrome.tabs.captureVisibleTab`) and write it with the Write tool.

## Dark mode

Toggle via `javascript_tool`:

```js
document.documentElement.classList.add('dark')     // or .remove('dark')
```

## Methods that do not work

Do not spend turns rediscovering these.

- `screencapture -x` in Bash — the shell process lacks screen recording permission
- `html2canvas` — fails on the modern CSS `color()` function, which many design
  systems use
- `tell application "Google Chrome" to activate` on its own — picks the wrong
  window when several are open; use the URL-matching loop in
  [mss-capture.md](mss-capture.md)
