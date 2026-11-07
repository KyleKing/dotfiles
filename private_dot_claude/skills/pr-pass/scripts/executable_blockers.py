#!/usr/bin/env python3
"""Prepend, replace, or clear the pr-pass blockers block at the top of a PR description.

The block sits below the validated line (validated.py) when one is present.

Everything outside the markers is left byte-for-byte, so a human-written body survives.
Run from inside a checkout of the PR's repo.
"""

import argparse
import json
import re
import subprocess
import sys

START, END = '<!-- pr-pass:blockers -->', '<!-- /pr-pass:blockers -->'
BLOCK = re.compile(re.escape(START) + r'.*?' + re.escape(END) + r'\n*', re.DOTALL)
VALIDATED = re.compile(r'\A<!-- pr-pass:validated [^\n]*?-->\n')


def body_of(pr: int) -> str:
    out = subprocess.run(['gh', 'pr', 'view', str(pr), '--json', 'body'], check=True, text=True,
                         capture_output=True).stdout
    return json.loads(out)['body'] or ''


def write(pr: int, body: str) -> None:
    subprocess.run(['gh', 'pr', 'edit', str(pr), '--body-file', '-'], input=body, check=True, text=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('action', choices=['set', 'clear'])
    parser.add_argument('pr', type=int)
    parser.add_argument('--file', help='markdown for the block (set only); - reads stdin')
    args = parser.parse_args()

    body = BLOCK.sub('', body_of(args.pr), count=1)
    top = match.group(0) if (match := VALIDATED.match(body)) else ''
    rest = body[len(top):]
    if args.action == 'clear':
        write(args.pr, top + rest)
        return
    if not args.file:
        sys.exit('set needs --file')
    text = (sys.stdin.read() if args.file == '-' else open(args.file).read()).strip()
    write(args.pr, f'{top}{START}\n{text}\n{END}\n\n{rest}')


if __name__ == '__main__':
    main()
