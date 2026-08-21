#!/usr/bin/env python3
"""Wrap `gh pr` so an AI-authored PR keeps a stable, singleton description.

A description I wrote myself is never touched; an empty one gets replaced,
once, with a pointer to a comment that starts with "AI Summary:" and is
PATCHed in place on every later update.

`get` prints the current comment, or exits 1 if there isn't one yet, so the
caller edits the real thing -- keep what's still true, update what changed,
drop what's stale -- instead of drafting a fresh summary from memory and
resubmitting that, which silently drops whatever it doesn't happen to
restate. `comment <body>` then submits the full result; it always replaces
the whole comment, on the assumption the caller built `<body>` from what
`get` returned.

A checklist item belongs in the comment only if it needs a human judgment
call the CI gate does not already make (a security-relevant permission
change, a step that can only be verified on another machine) -- never a step
already covered by CI or the merge button.

`create()` only sets draft/ready at creation. Nothing here flips that status
later: once a PR exists, draft/ready is the user's call, and no subcommand
should be added that changes it after the fact.

`create()` rejects a title that isn't Conventional Commits
(`<type>(<scope>): <Subject>`), since many repos gate PRs on exactly this with
action-semantic-pull-request -- catch it here so a malformed title fails
before `gh pr create` runs, not after CI does.
"""

import argparse
import json
import re
import subprocess
import sys

TITLE_RE = re.compile(
    r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: [A-Z]'
)


def run(*cmd: str) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def create(title: str, ready: bool, extra: list[str]) -> None:
    if not TITLE_RE.match(title):
        sys.exit(
            f"Title {title!r} is not Conventional Commits: <type>(<scope>): <Subject>."
        )

    cmd = ['gh', 'pr', 'create', '--title', title, '--body', '', '--assignee', '@me']
    if not ready:
        cmd.append('--draft')
    subprocess.run([*cmd, *extra], check=True)


def _find_existing_comment() -> tuple[int, str, dict | None]:
    number = run_json('gh', 'pr', 'view', '--json', 'number')['number']
    repo = run_json('gh', 'repo', 'view', '--json', 'nameWithOwner')['nameWithOwner']
    comments = run_json('gh', 'api', f"repos/{repo}/issues/{number}/comments")
    existing = next((c for c in comments if c['body'].startswith('AI Summary:')), None)
    return number, repo, existing


def get() -> None:
    _, _, existing = _find_existing_comment()
    if existing is None:
        sys.exit('No AI Summary comment yet')
    print(existing['body'])


def comment(body: str) -> None:
    number, repo, existing = _find_existing_comment()

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

    sub.add_parser('get', help='Print the current AI Summary comment, or exit 1 if none exists.')

    comment_parser = sub.add_parser('comment')
    comment_parser.add_argument('body', help='Full comment body -- replaces the whole comment.')

    args = parser.parse_args(argv)

    try:
        if args.command == 'create':
            create(args.title, args.ready, extra)
        elif args.command == 'get':
            get()
        else:
            comment(args.body)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))


if __name__ == '__main__':
    main()
