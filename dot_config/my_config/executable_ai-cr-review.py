#!/usr/bin/env python3
"""Read a review's findings and post verdicts back to its threads.

`fetch` prints the newest CodeRabbit review that carries a roll-up prompt
block, split into findings and joined to the thread each one came from.
`--review-id` targets any review instead, bot or human: one with a prompt
block is parsed the same way, and one without turns every open thread tied
to it into a finding directly, using the thread's own comment as the prompt.
`apply` reads verdicts as TOML (on stdin, or `--file`, since a human
proofreads this one before it posts and TOML's triple-quoted strings hold
reply prose without JSON's escaping), replies, resolves, and thumbs-up the
review body once every finding has been actioned. `status` lists every
review, bot or human, that has no thumbs-up and still has an unresolved
thread or a CHANGES_REQUESTED verdict, so a review a later push buried
doesn't go silently un-actioned.
"""

import argparse
import json
import re
import subprocess
import sys
import tomllib

BOT_REST = 'coderabbitai[bot]'
BLOCK_RE = re.compile(r'Prompt for all review comments.*?\n```\n(.*?)\n```', re.DOTALL)
ITEM_RE = re.compile(r'^- (?:Around lines?|Lines?) (?P<start>\d+)(?:\s*-\s*(?P<end>\d+))?:\s*(?P<text>.*)$')
PATH_RE = re.compile(r'^In `?@(?P<path>.+?)`?:$')
SECTION_RE = re.compile(r'^(?P<name>[A-Za-z][A-Za-z ]*) comments:$')
SKIP_VERDICTS = ('policy', 'stale', 'wrong')
VERDICTS = ('fixed', *SKIP_VERDICTS)

THREADS_QUERY = """
query($owner:String!,$repo:String!,$number:Int!,$after:String){
  repository(owner:$owner,name:$repo){ pullRequest(number:$number){
    reviewThreads(first:100,after:$after){
      pageInfo{ hasNextPage endCursor }
      nodes{ id isResolved isOutdated path line startLine originalLine originalStartLine
        comments(first:100){ nodes{ databaseId body author{login} pullRequestReview{databaseId} } } } } } } }
"""

REVIEWS_QUERY = """
query($owner:String!,$repo:String!,$number:Int!,$after:String){
  repository(owner:$owner,name:$repo){ pullRequest(number:$number){
    reviews(first:100,after:$after){
      pageInfo{ hasNextPage endCursor }
      nodes{ databaseId state submittedAt url body author{login}
        reactions(content:THUMBS_UP){ totalCount } } } } } }
"""


def run(*cmd: str, stdin: str | None = None) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True, input=stdin)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def pr_context(number: int | None) -> tuple[str, int, str]:
    cmd = ['gh', 'pr', 'view']
    if number is not None:
        cmd.append(str(number))
    view = run_json(*cmd, '--json', 'headRefName,number,url')
    owner, repo = view['url'].split('/')[3:5]
    return f"{owner}/{repo}", view['number'], view['headRefName']


def all_reviews(repo: str, number: int) -> list[dict]:
    return run_json('gh', 'api', '--paginate', f"repos/{repo}/pulls/{number}/reviews")


def pick_review(reviews: list[dict], review_id: int | None) -> dict:
    if review_id is not None:
        match = next((r for r in reviews if r['id'] == review_id), None)
        if match is None:
            sys.exit(f"No review {review_id} on this PR")
        return match
    match = next((r for r in reversed(reviews)
                  if r['user']['login'] == BOT_REST and BLOCK_RE.search(r['body'] or '')), None)
    if match is None:
        sys.exit('No CodeRabbit review on this PR carries a prompt block')
    return match


def unwrap(block: str) -> list[str]:
    """Rejoin CodeRabbit's hard-wrapped block into one line per header or item."""
    logical: list[str] = []
    for raw in block.splitlines():
        line = raw.strip()
        if not line:
            continue
        starts_entry = line == 'In' or line.startswith(('- ', 'In @', 'In `')) or SECTION_RE.match(line)
        if starts_entry or not logical:
            logical.append(line)
        else:
            logical[-1] += ' ' + line
    return logical


def parse_findings(block: str) -> tuple[list[dict], list[str]]:
    findings: list[dict] = []
    unparsed: list[str] = []
    path, section, started = None, 'inline', False
    for line in unwrap(block):
        header = SECTION_RE.match(line)
        if header:
            path, section, started = None, header['name'].strip().lower(), True
            continue
        location = PATH_RE.match(line)
        if location:
            path, started = location['path'], True
            continue
        item = ITEM_RE.match(line)
        if item and path:
            findings.append({
                'end': int(item['end'] or item['start']),
                'path': path,
                'prompt': item['text'],
                'section': section,
                'start': int(item['start']),
            })
        elif started and line != '---':
            unparsed.append(line)
    return findings, unparsed


def fetch_threads(repo: str, number: int) -> list[dict]:
    owner, name = repo.split('/')
    nodes: list[dict] = []
    after: str | None = None
    while True:
        args = ['gh', 'api', 'graphql', '-f', f"query={THREADS_QUERY}",
                '-f', f"owner={owner}", '-f', f"repo={name}", '-F', f"number={number}"]
        if after is not None:
            args += ['-f', f"after={after}"]
        page = run_json(*args)['data']['repository']['pullRequest']['reviewThreads']
        nodes += page['nodes']
        if not page['pageInfo']['hasNextPage']:
            return nodes
        after = page['pageInfo']['endCursor']


def review_of(thread: dict) -> int | None:
    return (thread['comments']['nodes'][0]['pullRequestReview'] or {}).get('databaseId')


def thread_spans(thread: dict) -> list[tuple[int, int]]:
    pairs = ((thread['startLine'], thread['line']), (thread['originalStartLine'], thread['originalLine']))
    return [(start if start is not None else end, end) for start, end in pairs if end is not None]


def thread_summary(thread: dict) -> dict:
    spans = thread_spans(thread)
    return {
        'comment_id': thread['comments']['nodes'][0]['databaseId'],
        'end': spans[0][1] if spans else None,
        'is_outdated': thread['isOutdated'],
        'is_resolved': thread['isResolved'],
        'path': thread['path'],
        'review_id': review_of(thread),
        'start': spans[0][0] if spans else None,
        'thread_id': thread['id'],
    }


def overlap(finding: dict, thread: dict) -> int:
    """Longest run of lines the finding shares with any of the thread's anchors.

    The block records the range the prompt talks about, which routinely differs
    from where the comment anchors, so anchors are matched by overlap.
    """
    if thread['path'] != finding['path']:
        return 0
    return max((min(finding['end'], end) - max(finding['start'], start) + 1
                for start, end in thread_spans(thread)), default=0)


def best_thread(finding: dict, threads: list[dict]) -> dict | None:
    scored = sorted(((overlap(finding, t), t) for t in threads), key=lambda pair: pair[0], reverse=True)
    if not scored or scored[0][0] <= 0:
        return None
    if len(scored) > 1 and scored[1][0] == scored[0][0]:
        return None
    return scored[0][1]


def join_threads(findings: list[dict], threads: list[dict], review_id: int) -> tuple[list[dict], list[dict], list[dict]]:
    available = {t['id']: t for t in threads if review_of(t) == review_id}
    joined, unmatched = [], []
    for finding in sorted((f for f in findings if f['section'] == 'inline'), key=lambda f: (f['path'], f['start'])):
        hit = best_thread(finding, list(available.values()))
        if hit is None:
            unmatched.append(finding)
            continue
        del available[hit['id']]
        joined.append({**finding, **thread_summary(hit)})
    return joined, unmatched, [thread_summary(t) for t in available.values()]


def fetch_reviews(repo: str, number: int) -> list[dict]:
    owner, name = repo.split('/')
    nodes: list[dict] = []
    after: str | None = None
    while True:
        args = ['gh', 'api', 'graphql', '-f', f"query={REVIEWS_QUERY}",
                '-f', f"owner={owner}", '-f', f"repo={name}", '-F', f"number={number}"]
        if after is not None:
            args += ['-f', f"after={after}"]
        page = run_json(*args)['data']['repository']['pullRequest']['reviews']
        nodes += page['nodes']
        if not page['pageInfo']['hasNextPage']:
            return nodes
        after = page['pageInfo']['endCursor']


def worktree_for(branch: str) -> str | None:
    path = None
    for line in run('git', 'worktree', 'list', '--porcelain').splitlines():
        if line.startswith('worktree '):
            path = line.removeprefix('worktree ')
        elif line == f"branch refs/heads/{branch}":
            return path
    return None


def review_findings(review: dict, threads: list[dict]) -> dict:
    """Findings for one review, whether or not it carries a CodeRabbit prompt block.

    A CodeRabbit review's block names findings by their own line ranges, joined to
    threads by anchor overlap since the two rarely agree exactly. Any other review
    (human, or a non-CodeRabbit bot) has no such block, so every open thread tied to
    it becomes a finding directly, with the thread's own comment standing in for the
    synthesized prompt.
    """
    block = BLOCK_RE.search(review['body'] or '')
    if block is None:
        review_threads = [t for t in threads if review_of(t) == review['id']]
        findings = [{**thread_summary(t), 'prompt': t['comments']['nodes'][0]['body'], 'section': 'inline'}
                    for t in review_threads]
        return {'findings': findings, 'outside_diff': [], 'unclaimed_threads': [],
                'unmatched_findings': [], 'unparsed_prompt_lines': []}
    parsed, unparsed = parse_findings(block.group(1))
    joined, unmatched, unclaimed = join_threads(parsed, threads, review['id'])
    return {
        'findings': joined,
        'outside_diff': [f for f in parsed if f['section'] != 'inline'],
        'unclaimed_threads': unclaimed,
        'unmatched_findings': unmatched,
        'unparsed_prompt_lines': unparsed,
    }


def collect(repo: str, number: int, review_id: int | None, threads: list[dict]) -> dict:
    review = pick_review(all_reviews(repo, number), review_id)
    return {
        'body': (review['body'] or '').strip() or None,
        'other_open_threads': [thread_summary(t) for t in threads
                               if not t['isResolved'] and review_of(t) != review['id']],
        'pr': number,
        'repo': repo,
        'review': {
            'commit_id': review['commit_id'],
            'id': review['id'],
            'node_id': review['node_id'],
            'submitted_at': review['submitted_at'],
            'url': review['html_url'],
        },
        **review_findings(review, threads),
    }


def validate(actions: list[dict], findings: list[dict]) -> list[str]:
    by_id = {f['thread_id']: f for f in findings}
    errors = []
    for action in actions:
        thread_id = action.get('thread_id')
        if thread_id not in by_id:
            errors.append(f"{thread_id}: not a finding of this review")
        if action.get('verdict') not in VERDICTS:
            errors.append(f"{thread_id}: verdict must be one of {', '.join(VERDICTS)}")
        if action.get('verdict') in SKIP_VERDICTS and not (action.get('reply') or '').strip():
            errors.append(f"{thread_id}: a skipped finding needs a reply saying why")
    missing = sorted(set(by_id) - {a.get('thread_id') for a in actions})
    errors += [f"{thread_id}: no verdict given" for thread_id in missing]
    return errors


def already_replied(thread: dict, body: str) -> bool:
    return any(c['body'].strip() == body.strip() for c in thread['comments']['nodes'][1:])


def post_reply(repo: str, number: int, comment_id: int, body: str) -> None:
    run('gh', 'api', '--input', '-', '-X', 'POST',
        f"repos/{repo}/pulls/{number}/comments/{comment_id}/replies",
        stdin=json.dumps({'body': body}))


def resolve_thread(thread_id: str) -> None:
    run('gh', 'api', 'graphql',
        '-f', 'query=mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}',
        '-f', f"id={thread_id}")


def thumbs_up(node_id: str) -> None:
    run('gh', 'api', 'graphql',
        '-f', 'query=mutation($id:ID!){addReaction(input:{subjectId:$id,content:THUMBS_UP}){reaction{content}}}',
        '-f', f"id={node_id}")


def cmd_fetch(number: int | None, review_id: int | None) -> None:
    repo, number, branch = pr_context(number)
    state = collect(repo, number, review_id, fetch_threads(repo, number))
    print(json.dumps({'branch': {'name': branch, 'worktree': worktree_for(branch)}, **state}, indent=2))


def cmd_status(number: int | None) -> None:
    """List every review (bot or human) that still needs a look.

    "Needs a look" means no thumbs-up reaction and either an unresolved thread
    tied to it or a CHANGES_REQUESTED verdict, so a review a push buried
    doesn't go un-actioned just because a newer one landed on top of it.

    A review with no open thread has nowhere to reply into (general feedback
    in the review body itself, not an inline comment), so its `body` is
    quoted in the output instead of a thread to fetch and act on directly.
    """
    repo, number, _ = pr_context(number)
    reviews = fetch_reviews(repo, number)
    threads = fetch_threads(repo, number)
    open_by_review: dict[int, int] = {}
    for thread in threads:
        if thread['isResolved']:
            continue
        review_id = review_of(thread)
        if review_id is not None:
            open_by_review[review_id] = open_by_review.get(review_id, 0) + 1

    pending = []
    for review in reviews:
        thumbs_up = review['reactions']['totalCount'] > 0
        open_threads = open_by_review.get(review['databaseId'], 0)
        if thumbs_up or (open_threads == 0 and review['state'] != 'CHANGES_REQUESTED'):
            continue
        entry = {
            'author': review['author']['login'] if review['author'] else None,
            'open_threads': open_threads,
            'review_id': review['databaseId'],
            'state': review['state'],
            'submitted_at': review['submittedAt'],
            'url': review['url'],
        }
        if open_threads == 0 and (review['body'] or '').strip():
            entry['body'] = '\n'.join(f"> {line}" for line in review['body'].splitlines())
        pending.append(entry)
    print(json.dumps(pending, indent=2))


def cmd_apply(number: int | None, path: str | None) -> None:
    payload = tomllib.loads(sys.stdin.read() if path is None else open(path).read())
    repo, number, _ = pr_context(number)
    threads = {t['id']: t for t in fetch_threads(repo, number)}
    state = collect(repo, number, payload.get('review_id'), list(threads.values()))
    actions = payload.get('actions') or []

    errors = validate(actions, state['findings'])
    if errors:
        sys.exit('Refusing to post:\n' + '\n'.join(f"  {e}" for e in errors))

    by_id = {f['thread_id']: f for f in state['findings']}
    failed = []
    for action in actions:
        finding = by_id[action['thread_id']]
        label = f"{finding['path']}:{finding['start']} ({action['verdict']})"
        try:
            reply = (action.get('reply') or '').strip()
            if reply and not already_replied(threads[action['thread_id']], reply):
                post_reply(repo, number, finding['comment_id'], reply)
            if not finding['is_resolved']:
                resolve_thread(action['thread_id'])
            print(f"actioned {label}")
        except subprocess.CalledProcessError as error:
            failed.append(f"{label}: {error.stderr.strip() or error}")

    if failed:
        sys.exit('Left the review un-acknowledged:\n' + '\n'.join(f"  {f}" for f in failed))
    thumbs_up(state['review']['node_id'])
    print(f"👍 review {state['review']['id']} — {len(actions)} actioned")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)

    fetch_parser = sub.add_parser('fetch')
    fetch_parser.add_argument('--pr', type=int)
    fetch_parser.add_argument('--review-id', type=int)

    apply_parser = sub.add_parser('apply')
    apply_parser.add_argument('--pr', type=int)
    apply_parser.add_argument('--file')

    status_parser = sub.add_parser('status')
    status_parser.add_argument('--pr', type=int)

    args = parser.parse_args()
    try:
        if args.command == 'fetch':
            cmd_fetch(args.pr, args.review_id)
        elif args.command == 'status':
            cmd_status(args.pr)
        else:
            cmd_apply(args.pr, args.file)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))


if __name__ == '__main__':
    main()
