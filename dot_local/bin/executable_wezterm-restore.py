#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Step through wezterm session snapshots and restore one into the running wezterm.

Reads the append-only JSONL written by ~/.wezterm_snapshot.lua. Left/right (or
j/k) steps through timestamps, Enter restores every tab/pane of the selected
snapshot as new tabs in the current wezterm, resuming claude/devin/codex
sessions by id and re-attaching tmux.

Usage:
  wezterm-restore.py              interactive picker
  wezterm-restore.py latest       restore the newest snapshot, no UI
  wezterm-restore.py <iso-prefix> restore the newest snapshot matching a prefix
                                  (e.g. "2026-11-06T14")
  --list                          print snapshot index, no UI
  --send-typed                    also re-send the captured input line (best
                                  effort; prompt glyphs are stripped crudely)
"""

import argparse
import curses
import json
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

SNAPSHOT_PATH = Path.home() / '.local/share/wezterm/snapshots.jsonl'

PROMPT_GLYPHS = ('❯', '>', '$', '#', '%', '➜', '→', '')


def load_snapshots(path: Path) -> list[dict]:
    snaps = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    snaps.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return snaps


def cli(*args: str, input_text: str | None = None) -> str:
    wezterm = shutil.which('wezterm')
    if not wezterm:
        sys.exit('wezterm not on PATH')
    result = subprocess.run(
        [wezterm, 'cli', *args],
        input=input_text,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"wezterm cli {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout.strip()


def strip_resume_flags(argv: list[str]) -> list[str]:
    out, skip_next = [], False
    resume_flags = {'--resume', '-r', '--continue', '-c', 'resume', '--last'}
    for i, arg in enumerate(argv):
        if skip_next:
            skip_next = False
            continue
        if i == 0:
            out.append(arg)
            continue
        base = arg.split('=', 1)[0]
        if base in resume_flags:
            if '=' not in arg and arg not in {'resume', '--last'}:
                skip_next = True
            continue
        out.append(arg)
    return out


def resume_command(pane: dict) -> str | None:
    session = pane.get('session') or {}
    agent = session.get('agent')
    argv = pane.get('fg', {}).get('argv') or []

    if agent:
        base = strip_resume_flags(argv) if argv else [agent]
        if 'acp' in base[1:]:
            return None
        sid = session.get('id')
        if agent == 'claude':
            return shlex.join(base + (['--resume', sid] if sid else ['--continue']))
        if agent == 'devin':
            return shlex.join(base + (['-r', sid] if sid else ['--continue']))
        if agent == 'codex':
            return shlex.join(base + ['resume'] + ([sid] if sid else ['--last']))

    if pane.get('fg', {}).get('name') == 'tmux':
        return 'tmux attach'
    return None


def typed_text(pane: dict) -> str | None:
    line = (pane.get('bottom_line') or '').strip()
    if not line:
        return None
    for glyph in PROMPT_GLYPHS:
        if line.startswith(glyph):
            stripped = line[len(glyph):].lstrip()
            return stripped or None
    return line


def restore(snap: dict, send_typed: bool = False) -> None:
    for window in snap.get('windows', []):
        for tab in window.get('tabs', []):
            panes = tab.get('panes', [])
            if not panes:
                continue
            new_ids = []
            for i, pane in enumerate(panes):
                cwd = pane.get('cwd') or str(Path.home())
                if i == 0:
                    new_ids.append(cli('spawn', '--cwd', cwd))
                else:
                    direction = '--horizontal' if pane.get('left', 0) > 0 else '--vertical'
                    new_ids.append(
                        cli('split-pane', '--pane-id', new_ids[0], direction, '--cwd', cwd)
                    )
            for pane_id, pane in zip(new_ids, panes):
                cmd = resume_command(pane)
                if cmd:
                    cli('send-text', '--pane-id', pane_id, '--no-paste', cmd + '\n')
                if send_typed:
                    typed = typed_text(pane)
                    if typed:
                        cli('send-text', '--pane-id', pane_id, '--no-paste', typed)


def summarize(snap: dict) -> str:
    tabs = sum(len(w.get('tabs', [])) for w in snap.get('windows', []))
    agents = {}
    for w in snap.get('windows', []):
        for t in w.get('tabs', []):
            for p in t.get('panes', []):
                s = p.get('session') or {}
                if s.get('agent'):
                    agents[s['agent']] = agents.get(s['agent'], 0) + 1
    agent_str = '  ' + ' '.join(f"{k}x{v}" for k, v in sorted(agents.items())) if agents else ''
    return f"{snap.get('iso', '?')}  tabs={tabs}{agent_str}"


def detail_lines(snap: dict) -> list[str]:
    lines = [f"snapshot {snap.get('iso')}  ts={snap.get('ts')}", '']
    for w in snap.get('windows', []):
        lines.append(f"window {w.get('window_id')}  workspace={w.get('workspace')}")
        for t in w.get('tabs', []):
            title = f"  [{t.get('title')}]" if t.get('title') else ''
            lines.append(f"  tab {t.get('tab_id')}{title}")
            for p in t.get('panes', []):
                fg = p.get('fg', {})
                s = p.get('session') or {}
                sess = f"  -> {s['agent']} {s.get('id') or '(latest)'}" if s.get('agent') else ''
                lines.append(f"    {fg.get('name', '?'):<14} {p.get('cwd', '')}{sess}")
                if p.get('bottom_line'):
                    lines.append(f"      last: {p['bottom_line']}")
    tmux = snap.get('tmux')
    if tmux:
        lines.append('')
        lines.append('tmux:')
        for tp in tmux:
            att = '*' if tp.get('attached') else ' '
            lines.append(
                f"  {att}{tp.get('session')}:{tp.get('window_index')}.{tp.get('pane_index')}"
                f"  {tp.get('command'):<12} {tp.get('cwd')}"
            )
    return lines


def tui(stdscr, snaps: list[dict], send_typed: bool) -> None:
    curses.curs_set(0)
    idx = 0
    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        left_w = min(44, w // 2)
        stdscr.addnstr(0, 0, 'wezterm-restore  j/k step  Enter restore  q quit', w - 1,
                       curses.A_BOLD)
        for row, snap in enumerate(snaps[: h - 2]):
            attr = curses.A_REVERSE if row == idx else curses.A_NORMAL
            stdscr.addnstr(row + 1, 0, summarize(snap), left_w - 1, attr)
        for row, line in enumerate(detail_lines(snaps[idx])):
            if row + 1 >= h:
                break
            stdscr.addnstr(row + 1, left_w + 1, line, w - left_w - 2)
        stdscr.refresh()

        key = stdscr.getch()
        if key in (ord('q'), 27):
            return
        if key in (curses.KEY_DOWN, ord('j')) and idx < len(snaps) - 1:
            idx += 1
        elif key in (curses.KEY_UP, ord('k')) and idx > 0:
            idx -= 1
        elif key in (curses.KEY_ENTER, 10, 13):
            restore(snaps[idx], send_typed)
            stdscr.addnstr(h - 1, 0, 'restored. press any key', w - 1, curses.A_BOLD)
            stdscr.getch()
            return


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('which', nargs='?', help="'latest' or an iso timestamp prefix")
    parser.add_argument('--file', type=Path, default=SNAPSHOT_PATH)
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--send-typed', action='store_true')
    args = parser.parse_args()

    snaps = load_snapshots(args.file)
    if not snaps:
        sys.exit(f"no snapshots in {args.file}")

    if args.list:
        for snap in snaps:
            print(summarize(snap))
        return

    if args.which:
        if args.which == 'latest':
            target = snaps[-1]
        else:
            matches = [s for s in snaps if s.get('iso', '').startswith(args.which)]
            if not matches:
                sys.exit(f"no snapshot matching {args.which!r}")
            target = matches[-1]
        print('restoring:', summarize(target))
        restore(target, args.send_typed)
        return

    curses.wrapper(tui, list(reversed(snaps)), args.send_typed)


if __name__ == '__main__':
    main()
