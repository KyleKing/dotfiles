#!/usr/bin/env python3
"""Create or update pr-pass's one challenge comment on a PR.

The comment opens with a hidden marker, so every later call edits the same comment
instead of adding another. Run from inside a checkout of the PR's repo.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import UTC, datetime

MARKER = '<!-- pr-pass:challenge -->'
LABELS = {'validated': 'Validated', 'objection': 'Challenged'}


def gh(*args: str, body: str | None = None) -> str:
    return subprocess.run(['gh', *args], input=body, check=True, text=True, capture_output=True).stdout


def existing(repo: str, pr: int) -> dict | None:
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{repo}/issues/{pr}/comments'))
    return next((c for page in pages for c in page if c['body'].startswith(MARKER)), None)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('pr', type=int)
    parser.add_argument('verdict', choices=LABELS)
    parser.add_argument('note', help='validated: at most two sentences; objection: the objection and its evidence')
    args = parser.parse_args()

    note = args.note.strip()
    if args.verdict == 'validated' and len(re.findall(r'[.!?](\s|$)', note)) > 2:
        sys.exit('a validated note is at most two sentences')
    repo = json.loads(gh('repo', 'view', '--json', 'nameWithOwner'))['nameWithOwner']
    stamp = datetime.now(UTC).strftime('%Y-%m-%dT%H:%MZ')
    body = f'{MARKER}\n**{LABELS[args.verdict]}** {stamp}: {note}\n'
    payload = json.dumps({'body': body})
    if found := existing(repo, args.pr):
        gh('api', '-X', 'PATCH', f'repos/{repo}/issues/comments/{found["id"]}', '--input', '-', body=payload)
        print(f'Updated {found["html_url"]}')
    else:
        url = json.loads(gh('api', '-X', 'POST', f'repos/{repo}/issues/{args.pr}/comments', '--input', '-', body=payload))['html_url']
        print(f'Commented {url}')


if __name__ == '__main__':
    main()
