#!/usr/bin/env python3
"""Attribute GitHub API spend to callers: `watch` samples, `report` summarizes.

`watch` polls processes, never wraps or changes `gh`: each new `gh` process is logged with its
parent script and Claude session, each other process holding a connection to GitHub's API is
logged as a direct caller, and the free `rate_limit` endpoint is logged every 30 seconds.
A short-lived `gh` can slip between polls, so counts are a floor.
"""

import argparse
import collections
import ipaddress
import json
import subprocess
import time
from datetime import datetime
from pathlib import Path

LOG = Path.home() / '.cache/gh-spend/samples.jsonl'
GITHUB_NETS = [ipaddress.ip_network(n) for n in ('140.82.112.0/20', '143.55.64.0/20', '192.30.252.0/22')]


def processes() -> dict[int, tuple[int, str]]:
    out = subprocess.run(['ps', '-axo', 'pid=,ppid=,command='], check=False, capture_output=True, text=True).stdout
    rows = (line.split(None, 2) for line in out.splitlines())
    return {int(r[0]): (int(r[1]), r[2][:300]) for r in rows if len(r) == 3}


def cwd_of(pid: int) -> str:
    out = subprocess.run(['lsof', '-a', '-p', str(pid), '-d', 'cwd', '-Fn'], check=False, capture_output=True, text=True).stdout
    return next((line[1:] for line in out.splitlines() if line.startswith('n')), '?')


def is_gh(command: str) -> bool:
    return command.split(None, 1)[0].rsplit('/', 1)[-1] == 'gh'


def caller(pid: int, procs: dict[int, tuple[int, str]]) -> tuple[str, str]:
    """The nearest non-shell ancestor's command, and the cwd of the Claude session above it."""
    script, session = '', ''
    pid = procs[pid][0]
    while pid in procs and pid > 1:
        ppid, command = procs[pid]
        exe = command.split(None, 1)[0].rsplit('/', 1)[-1]
        if not script and exe not in ('zsh', 'bash', 'sh', '-zsh', 'xargs', 'timeout'):
            script = command[:160]
        if exe == 'claude' or exe[:1].isdigit():
            session = cwd_of(pid)
            break
        pid = ppid
    return script, session


def github_connections() -> dict[int, str]:
    out = subprocess.run(['lsof', '-nP', '-iTCP', '-sTCP:ESTABLISHED', '-Fpn'], check=False, capture_output=True, text=True).stdout
    pid, found = 0, {}
    for line in out.splitlines():
        if line.startswith('p'):
            pid = int(line[1:])
        elif line.startswith('n') and '->' in line:
            host = line.split('->', 1)[1].rsplit(':', 1)[0].strip('[]')
            try:
                if any(ipaddress.ip_address(host) in net for net in GITHUB_NETS):
                    found[pid] = host
            except ValueError:
                continue
    return found


def watch(_: argparse.Namespace) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    seen: set[int] = set()
    next_rate = next_conn = 0.0
    with LOG.open('a') as log:
        while True:
            now, procs = time.time(), processes()
            rows = []
            for pid, (_, command) in procs.items():
                if is_gh(command) and pid not in seen and 'rate_limit' not in command:
                    seen.add(pid)
                    script, session = caller(pid, procs)
                    rows.append({'t': now, 'kind': 'gh', 'cmd': command, 'caller': script, 'session': session})
            if now >= next_conn:
                next_conn = now + 3
                for pid in github_connections():
                    if pid in procs and not is_gh(procs[pid][1]):
                        rows.append({'t': now, 'kind': 'direct', 'cmd': procs[pid][1][:200], 'cwd': cwd_of(pid)})
            if now >= next_rate:
                next_rate = now + 30
                seen &= set(procs)
                rate = subprocess.run(['gh', 'api', 'rate_limit', '--jq', '.resources|[.core.remaining,.core.reset,.graphql.remaining]'],
                                      check=False, capture_output=True, text=True).stdout
                if rate.strip():
                    core, reset, graphql = json.loads(rate)
                    rows.append({'t': now, 'kind': 'rate', 'core': core, 'reset': reset, 'graphql': graphql})
            for row in rows:
                log.write(json.dumps(row) + '\n')
            log.flush()
            time.sleep(0.15)


def report(args: argparse.Namespace) -> None:
    since = time.time() - args.minutes * 60
    rows = [r for line in LOG.open() if (r := json.loads(line))['t'] >= since] if LOG.exists() else []
    if not rows:
        raise SystemExit(f"no samples in the last {args.minutes} minutes; start `gh-spend.py watch` first")
    rates = [r for r in rows if r['kind'] == 'rate']
    for r in rates[:: max(1, len(rates) // 12)]:
        print(f"{datetime.fromtimestamp(r['t']):%H:%M} REST {r['core']:>5} left  GraphQL {r['graphql']:>5} left")
    calls = collections.Counter((r['caller'] or '(agent shell)', r['session']) for r in rows if r['kind'] == 'gh')
    print('\ngh processes by caller (a floor):')
    for (script, session), n in calls.most_common(args.top):
        print(f"{n:6}  {script[:90]}  [{session}]")
    direct = collections.Counter((r['cmd'], r['cwd']) for r in rows if r['kind'] == 'direct')
    print('\ndirect API callers, in 3-second samples seen connected:')
    for (command, cwd), n in direct.most_common(args.top):
        print(f"{n:6}  {command[:90]}  [{cwd}]")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(required=True)
    sub.add_parser('watch', help=f'sample until interrupted, appending to {LOG}').set_defaults(func=watch)
    rep = sub.add_parser('report', help='summarize the recent samples')
    rep.add_argument('--minutes', type=int, default=60)
    rep.add_argument('--top', type=int, default=15)
    rep.set_defaults(func=report)
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
