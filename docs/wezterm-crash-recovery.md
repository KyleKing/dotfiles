# WezTerm crash recovery

Every two minutes WezTerm writes a snapshot of every open tab and pane — working
directory, foreground process and argv, pane layout, and the live session id for
claude, devin, and codex panes — to `~/.local/share/wezterm/snapshots.jsonl`.
The file keeps twelve hours of history and skips writes when nothing changed, so an
idle terminal costs nothing.
After a force-quit or reboot, `wezterm-restore.py` recreates the snapshot as new tabs
in the running WezTerm and resumes each agent session by id.

Pieces:

- `dot_wezterm_snapshot.lua` — the snapshotter, loaded by `dofile` at the bottom of
    `dot_wezterm.lua`.
    Editing it needs a `chezmoi apply` plus a touch of
    `~/.wezterm.lua` before WezTerm reloads it.
- `dot_local/bin/executable_wezterm-restore.py` — installed as
    `~/.local/bin/wezterm-restore.py`.
    Standard library only; runs directly.

## Restoring

```sh
wezterm-restore.py            # interactive picker
wezterm-restore.py latest     # restore the newest snapshot
wezterm-restore.py 2026-11-07T18   # newest snapshot matching an ISO prefix
wezterm-restore.py --list     # print the snapshot index, no UI
```

In the picker, `j`/`k` or the arrow keys step through timestamps; the preview shows
each tab's panes, process, cwd, and resolved session id.
`Enter` restores everything as new tabs in the current window, `q` quits.

What a restore does per pane:

- claude, devin, codex: sends the original argv with the resume flag swapped for the
    resolved session id (`claude --resume <id>`, `devin -r <id>`,
    `codex resume <id>`), preserving flags like `--model` or
    `--dangerously-skip-permissions`.
- A pane that was attached to tmux gets `tmux attach`.
- Anything else (nvim, lazygit, a plain shell) gets a new shell at the recorded cwd —
    the process itself is not restarted.
- Split panes are recreated in the right direction, but sizes and nested layouts are
    approximate.
    Separate windows flatten into tabs in the current window.

## Limits worth knowing

- Snapshots can be up to two minutes stale; a session started just before a crash may
    resolve to the wrong id or none.
- `bottom_line` captures the last visible line, which for agent TUIs is the status
    bar, not the input box.
    `--send-typed` re-sends it, but it is best-effort and off
    by default.
- Scrollback is not captured; restored panes start empty.
- Codex resume is untested. tmux is reattached, not rebuilt — if the tmux server
    died, there is nothing to attach to.

## When it breaks

Snapshot errors land in `~/.local/share/wezterm/wezterm-gui-log-*.txt` — grep for
`snapshot failed`.
The JSONL is one record per line (`ts`, `iso`, `sig`, `windows`); a corrupt line can
be deleted by hand without breaking the file.
