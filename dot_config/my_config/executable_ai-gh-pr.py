#!/usr/bin/env python3
"""Wrap `gh pr` so an AI-authored PR keeps a stable, singleton description.

A description I wrote myself is never touched; an empty one gets replaced,
once, with a pointer to a comment that starts with "AI Summary:" and is
PATCHed in place on every later update.
"""

import argparse
import json
import subprocess
import sys


def run(*cmd: str) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def create(title: str, ready: bool, extra: list[str]) -> None:
    cmd = ['gh', 'pr', 'create', '--title', title, '--body', '', '--assignee', '@me']
    if not ready:
        cmd.append('--draft')
    subprocess.run([*cmd, *extra], check=True)


def comment(body: str) -> None:
    number = run_json('gh', 'pr', 'view', '--json', 'number')['number']
    repo = run_json('gh', 'repo', 'view', '--json', 'nameWithOwner')['nameWithOwner']

    comments = run_json('gh', 'api', f"repos/{repo}/issues/{number}/comments")
    existing = next((c for c in comments if c['body'].startswith('AI Summary:')), None)

    if existing is not None:
        run(
            'gh', 'api', '-X', 'PATCH',
            f"repos/{repo}/issues/comments/{existing['id']}",
            '-f', f"body={body}",
        )
        print(f"Updated AI Summary comment on #{number}")
        return

    comment_url = run('gh', 'pr', 'comment', str(number), '--body', body)
    print(f"Posted AI Summary comment: {comment_url}")

    current_body = run_json('gh', 'pr', 'view', str(number), '--json', 'body')['body']
    if not current_body:
        run('gh', 'pr', 'edit', str(number), '--body', f"See full AI Summary below: {comment_url}")
        print('Replaced empty description with pointer')


def main() -> None:
    argv = sys.argv[1:]
    extra: list[str] = []
    if '--' in argv:
        split = argv.index('--')
        extra, argv = argv[split + 1:], argv[:split]

    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)

    create_parser = sub.add_parser('create')
    create_parser.add_argument('title')
    create_parser.add_argument('--ready', action='store_true')

    comment_parser = sub.add_parser('comment')
    comment_parser.add_argument('body')

    args = parser.parse_args(argv)

    try:
        if args.command == 'create':
            create(args.title, args.ready, extra)
        else:
            comment(args.body)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))


if __name__ == '__main__':
    main()
