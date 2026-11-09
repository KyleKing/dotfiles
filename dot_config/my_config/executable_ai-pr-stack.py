#!/usr/bin/env python3
"""Print the chain of pull requests a given PR is stacked on, bottom first.

A stacked PR's own diff never shows what the PRs below it introduce, so
reviewing only the PR asked for silently skips those levels. This walks the
base chain -- each PR's base branch is the head branch of the PR below it --
down to the one based on the repository's default branch, and prints every
level in the order `second-look get` should run against them: bottom first.

Default output is one line per level, obvious without a legend. `--json`
prints the same chain as an array for a caller that wants to loop over it.
"""

import argparse
import json
import subprocess
import sys

MAX_DEPTH = 25


def run(*cmd: str) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def pr_context(number: int | None) -> tuple[str, dict]:
    cmd = ['gh', 'pr', 'view']
    if number is not None:
        cmd.append(str(number))
    fields = 'number,title,url,state,headRefName,baseRefName'
    pr = run_json(*cmd, '--json', fields)
    owner, repo = pr['url'].split('/')[3:5]
    return f"{owner}/{repo}", pr


def default_branch(repo: str) -> str:
    return run_json('gh', 'repo', 'view', repo, '--json', 'defaultBranchRef')['defaultBranchRef']['name']


def pr_for_head(repo: str, branch: str) -> dict | None:
    """The PR whose head is `branch`, preferring an open one over a closed/merged one."""
    fields = 'number,title,url,state,headRefName,baseRefName'
    candidates = run_json('gh', 'pr', 'list', '--repo', repo, '--head', branch,
                           '--state', 'all', '--json', fields)
    if not candidates:
        return None
    return next((c for c in candidates if c['state'] == 'OPEN'), candidates[0])


def walk_down(repo: str, top: dict, trunk: str) -> list[dict]:
    """The chain from `top` down to the PR based on `trunk`, bottom first."""
    chain = [top]
    seen = {top['number']}

    while chain[-1]['baseRefName'] != trunk:
        base_branch = chain[-1]['baseRefName']
        below = pr_for_head(repo, base_branch)
        if below is None:
            print(f"warning: no pull request found for branch {base_branch!r}; "
                  f"stopping the walk there", file=sys.stderr)
            break
        if below['number'] in seen or len(chain) >= MAX_DEPTH:
            print(f"warning: base chain did not reach {trunk!r} within {MAX_DEPTH} levels "
                  'or looped back on itself; stopping the walk', file=sys.stderr)
            break
        chain.append(below)
        seen.add(below['number'])

    return list(reversed(chain))


def render_text(chain: list[dict], trunk: str, requested: int) -> None:
    if len(chain) == 1:
        print(f"#{chain[0]['number']} is not stacked -- based directly on {trunk}")
        return

    print(f"stack, bottom to top, landing on {trunk}:")
    for pr in chain:
        marker = '*' if pr['number'] == requested else ' '
        print(f"{marker} #{pr['number']:<6} {pr['baseRefName']:<24} -> {pr['headRefName']:<24} "
              f"{pr['state']:<10} {pr['title']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pr', type=int, nargs='?', help='PR number; defaults to the current branch\'s PR')
    parser.add_argument('--json', action='store_true', help='print the chain as JSON instead of text')
    args = parser.parse_args()

    try:
        repo, top = pr_context(args.pr)
        trunk = default_branch(repo)
        chain = walk_down(repo, top, trunk)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))

    if args.json:
        print(json.dumps({'repo': repo, 'trunk': trunk, 'requested': top['number'], 'stack': chain}, indent=2))
    else:
        render_text(chain, trunk, top['number'])


if __name__ == '__main__':
    main()
