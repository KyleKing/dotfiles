---

## name: local-ocr description: Extract text from images and screenshots locally with mac-ocr, Apple's on-device Vision engine. Use when bulk-triaging screenshots or images (sorting Desktop or Downloads clutter), reading text out of a PNG or JPG, or any time image text needs extracting without spending vision tokens.

# Local OCR

`npx --yes mac-ocr <file>` wraps Apple's Vision framework, the same on-device engine
behind Preview's copy-paste.
It runs fully local, costs nothing, needs no API key, and ships a prebuilt binary via
npm — no Xcode or Swift toolchain.
Despite the name there is no brew tap; `npx --yes mac-ocr` is the working invocation.

Use it for bulk triage. Fall back to model-based OCR (the Read tool) only for images
mac-ocr cannot parse — handwriting, heavy stylization — or when the task needs layout or
semantic understanding beyond raw text.

## Spaced file paths

The Bash tool's sandbox has an intermittent bug with literal spaced paths:
`"Screenshot 2026-01-01 at 9.35.00 AM.png"` fails to open even when the path is correct,
and `dangerouslyDisableSandbox: true` does not help.

Always `cd` into the directory and use a glob or a variable instead of typing the
literal spaced path:

```sh
cd ~/Desktop && for f in Screenshot*9.35*; do npx --yes mac-ocr "$f"; done
```
