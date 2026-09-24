#!/usr/bin/env python3
"""Report what each PR in a pass still needs, grouped into stacks (bottom-up) and single PRs.

Read-only. Run from inside a checkout: gh and ai-cr-review.py resolve the repo from cwd.
"""

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

CR_REVIEW = Path.home() / '.config/my_config/ai-cr-review.py'
PR_FIELDS = 'number,title,url,headRefName,baseRefName,headRefOid,isDraft,mergeable,statusCheckRollup'
FAILED = {'FAILURE', 'ERROR', 'TIMED_OUT', 'CANCELLED', 'ACTION_REQUIRED', 'STARTUP_FAILURE'}
PENDING = {'PENDING', 'EXPECTED', 'QUEUED', 'IN_PROGRESS', 'WAITING', 'REQUESTED'}
WARNING_NOISE = ('Node.js 16 actions are deprecated', 'Node.js 20 actions are deprecated',
                 'The following actions use a deprecated Node.js version')


def run(*cmd: str) -> str:
    return subprocess.run(cmd, check=True, text=True, capture_output=True).stdout


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def repo_and_trunk() -> tuple[str, str]:
    meta = run_json('gh', 'repo', 'view', '--json', 'nameWithOwner,defaultBranchRef')
    return meta['nameWithOwner'], meta['defaultBranchRef']['name']


def open_prs(repo: str) -> list[dict]:
    return run_json('gh', 'pr', 'list', '--repo', repo, '--author', '@me', '--state', 'open',
                    '--limit', '100', '--json', PR_FIELDS)


def select(prs: list[dict], wanted: list[int], expand: bool) -> list[dict]:
    if not wanted:
        return prs
    by_head = {p['headRefName']: p for p in prs}
    chosen = {p['number'] for p in prs if p['number'] in wanted}
    missing = set(wanted) - chosen
    if missing:
        sys.exit(f"not an open PR authored by you: {sorted(missing)}")
    while expand:
        grown = set(chosen)
        for p in prs:
            below = by_head.get(p['baseRefName'])
            if p['number'] in chosen and below:
                grown.add(below['number'])
            if below and below['number'] in chosen:
                grown.add(p['number'])
        if grown == chosen:
            break
        chosen = grown
    return [p for p in prs if p['number'] in chosen]


def units(prs: list[dict]) -> list[list[dict]]:
    by_head = {p['headRefName']: p for p in prs}
    above: dict[str, list[dict]] = {}
    for p in prs:
        above.setdefault(p['baseRefName'], []).append(p)
    result = []
    for root in sorted((p for p in prs if p['baseRefName'] not in by_head), key=lambda p: p['number']):
        chain, frontier = [], [root]
        while frontier:
            node = frontier.pop(0)
            chain.append(node)
            frontier.extend(sorted(above.get(node['headRefName'], []), key=lambda p: p['number']))
        result.append(chain)
    return result


def checks(rollup: list[dict]) -> dict:
    failed, pending, passed = [], [], 0
    for c in rollup or []:
        name = c.get('name') or c.get('context') or '?'
        state = (c.get('conclusion') or c.get('state') or '').upper()
        if c.get('status') and c['status'].upper() != 'COMPLETED':
            pending.append(name)
        elif state in FAILED:
            failed.append(name)
        elif state in PENDING or not state:
            pending.append(name)
        else:
            passed += 1
    return {'failed': sorted(set(failed)), 'pending': sorted(set(pending)), 'passed': passed}


def warnings(repo: str, sha: str) -> list[str]:
    runs = run_json('gh', 'api', '--paginate', f'repos/{repo}/commits/{sha}/check-runs?per_page=100',
                    '--jq', '[.check_runs[] | select(.output.annotations_count > 0) | {id, name}]')
    found = []
    for r in runs:
        notes = run_json('gh', 'api', f"repos/{repo}/check-runs/{r['id']}/annotations?per_page=100")
        for n in notes:
            msg = n.get('message', '').strip().splitlines()[0] if n.get('message') else ''
            if n.get('annotation_level') == 'warning' and not msg.startswith(WARNING_NOISE):
                found.append(f"{r['name']}: {n.get('path', '')}:{n.get('start_line', '')} {msg}"[:200])
    return found


def behind_base(repo: str, head: str, base: str) -> int:
    return run_json('gh', 'api', f'repos/{repo}/compare/{head}...{base}', '--jq', '{n: .ahead_by}')['n']


def reviews(number: int) -> list[dict]:
    pending = run_json(str(CR_REVIEW), 'status', '--pr', str(number))
    return [{'author': r['author'], 'open_threads': r['open_threads'], 'url': r['url']} for r in pending]


def describe(repo: str, pr: dict, heads: dict[str, int]) -> dict:
    ci = checks(pr['statusCheckRollup'])
    entry = {
        'number': pr['number'],
        'title': pr['title'],
        'head': pr['headRefName'],
        'base': pr['baseRefName'],
        'sha': pr['headRefOid'][:10],
        'below': heads.get(pr['baseRefName']),
        'conflicted': {'CONFLICTING': True, 'UNKNOWN': 'unknown'}.get(pr['mergeable'], False),
        'behind_base': behind_base(repo, pr['headRefName'], pr['baseRefName']),
        'ci_failed': ci['failed'],
        'ci_pending': ci['pending'],
        'ci_warnings': warnings(repo, pr['headRefOid']),
        'reviews': reviews(pr['number']),
    }
    entry['done'] = not (entry['conflicted'] or entry['behind_base'] or entry['ci_failed']
                         or entry['ci_pending'] or entry['ci_warnings'] or entry['reviews'])
    return entry


def needs(p: dict) -> list[str]:
    threads = sum(r['open_threads'] for r in p['reviews'])
    candidates = [
        ('conflict', p['conflicted']),
        (f"behind {p['base']} by {p['behind_base']}", p['behind_base']),
        (f"failed {', '.join(p['ci_failed'])}", p['ci_failed']),
        (f"{len(p['ci_pending'])} pending", p['ci_pending']),
        (f"{len(p['ci_warnings'])} warnings", p['ci_warnings']),
        (f"{threads} open threads in {len(p['reviews'])} reviews", p['reviews']),
    ]
    return [label for label, present in candidates if present]


def render(result: dict) -> None:
    for i, unit in enumerate(result['units'], 1):
        kind = 'stack' if len(unit) > 1 else 'single'
        print(f"unit {i} ({kind}): {' > '.join('#' + str(p['number']) for p in unit)}")
        for p in unit:
            print(f"  #{p['number']} {p['head']}  {'DONE' if p['done'] else '; '.join(needs(p))}")
    print(f"all done: {result['done']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('prs', nargs='*', type=int, help='PR numbers; none means every open PR you authored')
    parser.add_argument('--no-expand', action='store_true', help='do not pull in stack-mates of the PRs named')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    repo, trunk = repo_and_trunk()
    prs = select(open_prs(repo), args.prs, expand=not args.no_expand)
    heads = {p['headRefName']: p['number'] for p in prs}
    with ThreadPoolExecutor(max_workers=6) as pool:
        described = {d['number']: d for d in pool.map(lambda p: describe(repo, p, heads), prs)}
    grouped = [[described[p['number']] for p in unit] for unit in units(prs)]
    result = {'repo': repo, 'trunk': trunk, 'units': grouped, 'done': all(d['done'] for d in described.values())}
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        render(result)


if __name__ == '__main__':
    main()
