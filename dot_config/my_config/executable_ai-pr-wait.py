#!/usr/bin/env python3
"""Block until something happens on any of several PRs, print what, and exit.

Run it in the background while PRs are in flight: the exit is the wake-up, so a
review, a CI result, a push, or a merge reaches the caller within one interval
instead of whenever a subagent or a fixed sleep happens to check.

    ai-pr-wait.py coverbasedev/irm#16995 coverbasedev/watch-doggo#1068

Every event on the first poll that sees any is printed, one per line, then it
exits 0. Rerun with the same arguments to wait for the next one. It exits 2 on
`--timeout` and 1 after three consecutive failed reads, so a dead `gh` never
looks like a quiet PR.
"""

import argparse
import json
import re
import subprocess
import sys
import time

QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      state
      headRefOid
      reviews(last: 1) { nodes { id commit { oid } state author { login } } }
      comments(last: 1) { nodes { id author { login } body } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
  }
}
"""

SETTLED = {'SUCCESS', 'FAILURE', 'ERROR'}
QUIET_AUTHORS = {'github-actions'}
MAX_FAILURES = 3


def parse_target(raw: str) -> tuple[str, str, int]:
    match = re.fullmatch(r'([\w.-]+)/([\w.-]+)#(\d+)', raw)
    if not match:
        raise argparse.ArgumentTypeError(f"expected owner/repo#N, got {raw!r}")
    return match[1], match[2], int(match[3])


def read(owner: str, name: str, number: int) -> dict:
    out = subprocess.run(
        ['gh', 'api', 'graphql', '-f', f"query={QUERY}", '-F', f"owner={owner}",
         '-F', f"name={name}", '-F', f"number={number}"],
        check=True, text=True, capture_output=True,
    ).stdout
    pr = json.loads(out)['data']['repository']['pullRequest']
    review = (pr['reviews']['nodes'] or [None])[0]
    comment = (pr['comments']['nodes'] or [None])[0]
    rollup = pr['commits']['nodes'][0]['commit']['statusCheckRollup']
    return {
        'state': pr['state'],
        'head': pr['headRefOid'],
        'review': review,
        'comment': comment,
        'checks': rollup['state'] if rollup else 'NONE',
    }


def events(label: str, old: dict, new: dict) -> list[str]:
    found = []
    if new['state'] != old['state']:
        found.append(f"{label} {new['state'].lower()}")
    if new['head'] != old['head']:
        found.append(f"{label} pushed {old['head'][:8]} -> {new['head'][:8]}")
    review = new['review']
    if review and review['id'] != (old['review'] or {}).get('id'):
        on = (review['commit'] or {}).get('oid', '')
        where = 'on head' if on == new['head'] else f"on {on[:8]}, head is {new['head'][:8]}"
        found.append(f"{label} review {review['state'].lower()} by {review['author']['login']} {where}")
    comment = new['comment']
    if comment and comment['id'] != (old['comment'] or {}).get('id') and comment['author']['login'] not in QUIET_AUTHORS:
        first = comment['body'].strip().splitlines()[0][:100] if comment['body'].strip() else ''
        found.append(f"{label} comment by {comment['author']['login']}: {first}")
    if new['checks'] in SETTLED and (new['checks'] != old['checks'] or new['head'] != old['head']):
        found.append(f"{label} checks {new['checks'].lower()} on {new['head'][:8]}")
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('targets', nargs='+', type=parse_target, metavar='owner/repo#N')
    parser.add_argument('--interval', type=int, default=60, help='seconds between polls (default 60)')
    parser.add_argument('--timeout', type=int, default=3600, help='seconds before exit 2 (default 3600)')
    args = parser.parse_args()

    labels = {t: f"{t[0]}/{t[1]}#{t[2]}" for t in args.targets}
    seen = {t: read(*t) for t in args.targets}
    for t, snap in seen.items():
        print(f"{labels[t]} watching: {snap['state'].lower()} head {snap['head'][:8]} checks {snap['checks'].lower()}", flush=True)

    deadline = time.monotonic() + args.timeout
    failures = 0
    while time.monotonic() < deadline:
        time.sleep(args.interval)
        found = []
        for t in args.targets:
            try:
                snap = read(*t)
            except (subprocess.CalledProcessError, KeyError, TypeError, json.JSONDecodeError) as err:
                failures += 1
                detail = err.stderr.strip() if isinstance(err, subprocess.CalledProcessError) else repr(err)
                print(f"{labels[t]} read failed ({failures}/{MAX_FAILURES}): {detail}", file=sys.stderr, flush=True)
                if failures >= MAX_FAILURES:
                    return 1
                continue
            failures = 0
            found += events(labels[t], seen[t], snap)
            seen[t] = snap
        if found:
            print('\n'.join(found), flush=True)
            return 0
    print(f"timed out after {args.timeout}s with no change", file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
