---

## name: hunk-review description: Drive an interactive hunk diff review session (hunkdiff CLI). Use when the user mentions hunk, asks to review a diff hunk by hunk, or wants comments added and applied through a live hunk session.

# Hunk review

Drive a live session with `hunk session *` subcommands:

```sh
hunk session list
hunk session review --json
hunk session navigate
hunk session comment add
hunk session comment apply
```

If no session exists, ask the user to launch one — do not start one on their behalf.

Fuller documentation ships with the tool at
`~/node_modules/hunkdiff/skills/hunk-review/SKILL.md`.
Read that when a subcommand's behavior is unclear.
