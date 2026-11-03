#!/usr/bin/env python3
"""Wrap `gh pr` so an AI-authored PR keeps its summary in the description.

A description I wrote myself is never touched. An empty one, a legacy pointer,
or one that already starts with "AI Summary:" belongs to the AI and is
rewritten in place on every update. The summary opens the description so the
reviewer does not scroll for it.

`get` prints the current summary, or exits 1 if there isn't one yet, so the
caller edits the real thing -- keep what's still true, update what changed,
drop what's stale -- instead of drafting a fresh summary from memory and
resubmitting that, which silently drops whatever it doesn't happen to
restate. `describe <body>` then submits the full result; it always replaces
the whole summary, on the assumption the caller built `<body>` from what
`get` returned. A PR that still carries its summary in a comment is migrated:
the comment's text moves into the description and the comment is deleted.

Anything after a bare `--` on `describe` goes to `gh pr edit`, so `-- --attach
'shot.png#alt'` uploads an image and rewrites a matching `![alt](./shot.png)` in the body.

`describe` re-stamps the body with the short SHA and subject line of the commit
it describes, stripping the previous stamp first. The SHA is what says the
summary is out of sync; the subject is what survives a rebase, which changes
every SHA on the branch and leaves the subjects alone, so a stale SHA under a
matching subject reads as a rebase rather than as new work the summary missed.
Never write or edit the stamp by hand: `get` returns it and `describe` replaces
it.

`get` and `describe` take `--pr <number|branch>` and default to the current branch. A stack of
PRs is the case that needs it: only one branch is checked out at a time, so
without it the summary for every PR but that one is unreachable.

A checklist item belongs in the summary only if it needs a human judgment
call the CI gate does not already make (a security-relevant permission
change, a step that can only be verified on another machine) -- never a step
already covered by CI or the merge button.

`create()` always opens the PR ready for review; there is no draft option.

`create()` rejects a title that isn't Conventional Commits
(`<type>(<scope>): <Subject>`), since many repos gate PRs on exactly this with
action-semantic-pull-request -- catch it here so a malformed title fails
before `gh pr create` runs, not after CI does.

`create --base <branch>` opens the PR against something other than the
repository default. A stack needs it on every level but the bottom, and
getting it wrong is expensive: a PR opened against the default branch shows
the levels below it in its own diff, and retargeting later is manual. When the
base is not the default branch, `create` also runs `gh stack link <base> <head>`
so the PR joins a GitHub native stack; land its bottom PR with
`gh stack merge <pr> --yes`. Anything else `gh pr create` accepts still goes
through after a bare `--`.

`create` adds the `watch-doggo-review` label wherever the repo defines it,
so the review starts on open instead of waiting for the repo's poll.

`title <title>` retitles an open PR under the same Conventional Commits check
as `create`, and touches nothing else. The title becomes the squash-merge
subject, so a plan that changed after the PR opened needs it to follow.
"""

import argparse
import json
import re
import subprocess
import sys

MARKER = 'AI Summary:'
STAMP_MARKER = '<!-- ai-gh-pr:commit -->'
# Anchored on the stamp's exact one-line shape at the very end: a body that quotes
# the marker (an Evidence block showing a stamp) must not truncate from there.
STAMP_RE = re.compile(rf"\n*{re.escape(STAMP_MARKER)}\n_Describes [^\n]*_\s*\Z")
# The stamp's subject sits inside `_..._`; an unescaped one of these closes it early.
EMPHASIS_RE = re.compile(r'([_*])')

REVIEW_LABEL = 'watch-doggo-review'

CODESMITH_FOOTER = '<!-- codesmith:footer -->'

TITLE_RE = re.compile(
    r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?: [A-Z]'
)


def run(*cmd: str) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def _repo_has_label(name: str) -> bool:
    # A search with no match prints nothing rather than `[]`.
    labels = json.loads(run('gh', 'label', 'list', '--search', name, '--json', 'name') or '[]')
    return any(label['name'] == name for label in labels)


def _require_conventional(title: str) -> None:
    if not TITLE_RE.match(title):
        sys.exit(
            f"Title {title!r} is not Conventional Commits: <type>(<scope>): <Subject>."
        )


def create(title: str, base: str | None, extra: list[str]) -> None:
    _require_conventional(title)
    cmd = ['gh', 'pr', 'create', '--title', title, '--body', '', '--assignee', '@me']
    if base:
        cmd += ['--base', base]
    if _repo_has_label(REVIEW_LABEL):
        cmd += ['--label', REVIEW_LABEL]
    subprocess.run([*cmd, *extra], check=True)
    default = run_json('gh', 'repo', 'view', '--json', 'defaultBranchRef')['defaultBranchRef']['name']
    if base and base != default:
        _link_stack(base, _forwarded_head(extra) or run('git', 'branch', '--show-current'))


def _forwarded_head(extra: list[str]) -> str | None:
    for i, arg in enumerate(extra):
        if arg == '--head' and i + 1 < len(extra):
            return extra[i + 1]
        if arg.startswith('--head='):
            return arg.split('=', 1)[1]
    return None


def _link_stack(base: str, head: str) -> None:
    result = subprocess.run(['gh', 'stack', 'link', base, head], check=False)
    if result.returncode != 0:
        sys.exit(
            f"PR for {head} was created, but `gh stack link {base} {head}` failed;"
            ' install github/gh-stack (`gh extension install github/gh-stack`) and rerun it.'
        )


def _find_existing_comment(pr: str | None) -> tuple[int, str, dict | None]:
    view = ['gh', 'pr', 'view', *([pr] if pr else []), '--json', 'number']
    number = run_json(*view)['number']
    repo = run_json('gh', 'repo', 'view', '--json', 'nameWithOwner')['nameWithOwner']
    comments = run_json('gh', 'api', f"repos/{repo}/issues/{number}/comments")
    existing = next((c for c in comments if c['body'].startswith(MARKER)), None)
    return number, repo, existing


def _commit_stamp(repo: str, number: int) -> str:
    """Record which commit the summary describes, so a stale summary is visible."""
    sha = run('git', 'rev-parse', 'HEAD')
    pr_head = run_json('gh', 'pr', 'view', str(number), '--json', 'headRefOid')['headRefOid']
    if sha != pr_head:
        print(
            f"warning: local HEAD {sha[:10]} is not the PR head {pr_head[:10]}; push"
            ' first, or the stamp points at a commit the reviewer cannot open.',
            file=sys.stderr,
        )
    if run('git', 'status', '--porcelain', '-uno'):
        print(
            'warning: tracked files have uncommitted changes; commit and push them,'
            ' or the stamp describes a commit that predates them.',
            file=sys.stderr,
        )
    subject = EMPHASIS_RE.sub(r'\\\1', run('git', 'log', '-1', '--format=%s', sha))
    return (
        f"\n\n{STAMP_MARKER}\n_Describes "
        f"[`{sha[:10]}`](https://github.com/{repo}/commit/{sha}) — {subject}._"
    )


def retitle(new: str, pr: str | None) -> None:
    _require_conventional(new)
    view = run_json('gh', 'pr', 'view', *([pr] if pr else []), '--json', 'number,title')
    if view['title'] == new:
        print(f"#{view['number']} is already titled {new!r}")
        return
    run('gh', 'pr', 'edit', str(view['number']), '--title', new)
    print(f"Retitled #{view['number']}: {view['title']!r} -> {new!r}")


LEGACY_POINTER = 'See full AI Summary below:'


def _split_description(body: str) -> tuple[str, str]:
    """Return the written text and the Blacksmith footer, which is never human text."""
    written, marker, footer = body.partition(CODESMITH_FOOTER)
    return written.strip(), (marker + footer) if marker else ''


def _ai_owned(written: str) -> bool:
    return not written or written.startswith((MARKER, LEGACY_POINTER))


def get(pr: str | None) -> None:
    number, _, existing = _find_existing_comment(pr)
    written, _ = _split_description(
        run_json('gh', 'pr', 'view', str(number), '--json', 'body')['body']
    )
    if written.startswith(MARKER):
        print(written)
    elif existing is not None:
        print(existing['body'])
    else:
        sys.exit('No AI Summary yet')


def describe(body: str, pr: str | None, extra: list[str]) -> None:
    if not body.startswith(MARKER):
        sys.exit(
            f"Summary body must start with {MARKER!r}: it is how the description is"
            ' recognised as AI-owned and re-written, and how it names its own authorship.'
        )
    number, repo, existing = _find_existing_comment(pr)
    written, footer = _split_description(
        run_json('gh', 'pr', 'view', str(number), '--json', 'body')['body']
    )
    if not _ai_owned(written):
        sys.exit(
            f"#{number} has a description someone wrote; it is left alone."
            ' Put the summary in a PR comment by hand if it is needed.'
        )

    body = STAMP_RE.sub('', body).rstrip() + _commit_stamp(repo, number)
    run(
        'gh', 'pr', 'edit', str(number),
        '--body', f"{body}\n\n{footer}" if footer else body,
        *extra,
    )
    print(f"Wrote AI Summary into the description of #{number}")

    if existing is not None:
        run('gh', 'api', '-X', 'DELETE', f"repos/{repo}/issues/comments/{existing['id']}")
        print('Deleted the legacy AI Summary comment')


def main() -> None:
    argv = sys.argv[1:]
    extra: list[str] = []
    if '--' in argv:
        split = argv.index('--')
        extra, argv = argv[split + 1:], argv[:split]

    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)

    create_parser = sub.add_parser(
        'create',
        help='Open the PR. Pass any other `gh pr create` flag after a bare `--`.',
    )
    create_parser.add_argument('title')
    create_parser.add_argument(
        '--base',
        metavar='<branch>',
        help='Branch to open against. Defaults to the repository default; a stacked'
        ' PR needs the branch below it.',
    )

    get_parser = sub.add_parser(
        'get', help='Print the current AI Summary, or exit 1 if none exists.'
    )

    describe_parser = sub.add_parser(
        'describe', help='Write the AI Summary into the PR description.'
    )
    describe_parser.add_argument('body', help='Full summary -- replaces the whole AI Summary.')

    title_parser = sub.add_parser(
        'title', help='Retitle the PR, under the same Conventional Commits check as create.'
    )
    title_parser.add_argument('title')

    for target in (get_parser, describe_parser, title_parser):
        target.add_argument(
            '--pr',
            metavar='<number|branch>',
            help='Which PR to read or write. Defaults to the current branch.',
        )

    args = parser.parse_args(argv)

    try:
        if args.command == 'create':
            create(args.title, args.base, extra)
        elif args.command == 'get':
            get(args.pr)
        elif args.command == 'title':
            retitle(args.title, args.pr)
        else:
            describe(args.body, args.pr, extra)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))


if __name__ == '__main__':
    main()
