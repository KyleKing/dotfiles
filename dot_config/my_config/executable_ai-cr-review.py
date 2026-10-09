#!/usr/bin/env python3
"""Read a review's findings and post verdicts back to its threads.

`fetch` prints every un-acked bot review (CodeRabbit or any other bot) at
once, each split into findings and joined to the thread it came from — a PR
with three pending CodeRabbit passes gets all three, not just the newest.
A review with a CodeRabbit-style roll-up prompt block is parsed for its
per-finding line ranges; a review without one has every open thread tied to
it turned into a finding directly, using the thread's own comment as the
prompt. `--review-id` targets one review outright, including a human's,
which `fetch`'s default sweep never picks on its own.
Every finding gets a reply, whatever its verdict, and every reply opens with
`[AI Bot]: `. A thread nobody answers reads as unaddressed to the next reader
and to the next round of a reviewer that re-reads its own threads, and the
prefix is the only thing in a thread saying a model wrote what my account
posted. `apply` refuses an action missing either.
A bot's review is actioned without asking; replying into a person's thread
needs `replies_approved = true` in the actions file, which the caller sets only
after the human has said yes.
`apply` reads verdicts as TOML (on stdin, or `--file`, since a human
proofreads this one before it posts and TOML's triple-quoted strings hold
reply prose without JSON's escaping), replies, resolves, and rockets the
review body once every finding has been actioned. An optional top-level `body_reply`
posts one PR conversation comment, closing with a link to the review it answers, before
the rocket, for a review with no threads to reply into or alongside thread actions in the
same file. It refuses while the local PR branch holds
commits the PR does not, so every reply describes code the reviewer can open. `status` lists every
review, bot or human, that still has an unresolved thread tied to it (even a
review already rocketed once, since a reply or a manual unresolve can reopen
a thread afterward) or a CHANGES_REQUESTED verdict (or a Watch Doggo body still
withholding approval) with nothing left open, so
a review a later push buried doesn't go silently un-actioned. `sweep` runs that same rule across every
merged pull request an author landed in a window, which is where a review that
arrived at merge time or after it turns up. `status` and `sweep` also list every
unchecked `- [ ]` in the pull request's own description, its `AI Summary:` comment,
and in any review's own body (a bot's non-blocking ticket checklist, e.g.), since each
one is a step a human still owes. `tick` checks boxes off in the description or the
`AI Summary:` comment from a TOML file and appends one `[AI Bot]: ` comment to the
pull request saying how each box was settled: verified automatically, confirmed by the
human, or left open on purpose.
"""

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import tomllib

BLOCK_RE = re.compile(r'Prompt for all review comments.*?\n```\n(.*?)\n```', re.DOTALL)
ITEM_RE = re.compile(r'^- (?:Around lines?|Lines?) (?P<start>\d+)(?:\s*-\s*(?P<end>\d+))?:\s*(?P<text>.*)$')
PATH_RE = re.compile(r'^In `?@(?P<path>.+?)`?:$')
SECTION_RE = re.compile(r'^(?P<name>[A-Za-z][A-Za-z ]*) comments:$')
SKIP_VERDICTS = ('answered', 'noted', 'policy', 'stale', 'wrong')
VERDICTS = ('fixed', *SKIP_VERDICTS)
# A reply posts under my account, so nothing else in the thread says a model wrote
# it. Watch Doggo's own gate reads a reply from a write-access human as an argument
# that can clear a blocking finding, so the prefix is the only marker of authorship
# a later reader or a later round gets.
AI_REPLY_PREFIX = '[AI Bot]: '
WATCH_DOGGO_APPROVED = '✅ approved'
WATCH_DOGGO_MARKER = '<!-- watchdoggo-review '
# ai-gh-pr.py's singleton marker; the two scripts must agree on it.
SUMMARY_MARKER = 'AI Summary:'
OPEN_BOX_RE = re.compile(r'^\s*[-*] \[ \] (?P<text>.+)$')
TICK_HOW = {
    'auto': 'Checked automatically',
    'asked': 'Checked with your confirmation',
    'open': 'Left open on purpose',
}

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
        reactions(content:ROCKET){ totalCount } } } } } }
"""

SWEEP_QUERY = """
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$number){
    reviews(first:100){
      pageInfo{ hasNextPage }
      nodes{ databaseId state submittedAt url body author{login}
        reactions(content:ROCKET){ totalCount } }
    }
    reviewThreads(first:100){
      pageInfo{ hasNextPage }
      nodes{ id isResolved isOutdated path line startLine originalLine originalStartLine
        comments(first:100){ nodes{ databaseId body author{login} pullRequestReview{databaseId} } } }
    }
    comments(last:100){
      pageInfo{ hasPreviousPage }
      nodes{ body url }
    } } } }
"""



def run(*cmd: str, stdin: str | None = None) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True, input=stdin)
    return result.stdout.strip()


def run_json(*cmd: str):
    return json.loads(run(*cmd))


def pr_context(number: int | None) -> tuple[str, int, str, dict]:
    cmd = ['gh', 'pr', 'view']
    if number is not None:
        cmd.append(str(number))
    view = run_json(*cmd, '--json', 'body,headRefName,number,url')
    owner, repo = view['url'].split('/')[3:5]
    return f"{owner}/{repo}", view['number'], view['headRefName'], view


def all_reviews(repo: str, number: int) -> list[dict]:
    return run_json('gh', 'api', '--paginate', f"repos/{repo}/pulls/{number}/reviews")


def pick_review(reviews: list[dict], review_id: int) -> dict:
    match = next((r for r in reviews if r['id'] == review_id), None)
    if match is None:
        sys.exit(f"No review {review_id} on this PR")
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


def pending_review_ids(repo: str, number: int, threads: list[dict]) -> set[int]:
    """Database ids of reviews `status` would still call un-acked, rocketed or not."""
    return {p['review_id'] for p in pending_reviews(fetch_reviews(repo, number), threads)}


def collect(repo: str, number: int, review_id: int, threads: list[dict]) -> dict:
    review = pick_review(all_reviews(repo, number), review_id)
    return {
        'body': (review['body'] or '').strip() or None,
        'other_open_threads': [thread_summary(t) for t in threads
                               if not t['isResolved'] and review_of(t) != review['id']],
        'pr': number,
        'repo': repo,
        'review': {
            'author': review['user']['login'],
            'commit_id': review['commit_id'],
            'id': review['id'],
            'is_bot': is_bot(review),
            'node_id': review['node_id'],
            'submitted_at': review['submitted_at'],
            'url': review['html_url'],
        },
        **review_findings(review, threads),
    }


def is_bot(review: dict) -> bool:
    """Whether a review was posted by a bot rather than a person.

    A bot's thread is a work item: replying to it costs nobody's attention, so
    `apply` posts without asking. A person's thread is a conversation, so a
    reply into one needs the human's explicit go-ahead (`replies_approved`).
    """
    return review['user'].get('type') == 'Bot' or review['user']['login'].endswith('[bot]')


def validate(actions: list[dict], findings: list[dict], *, bot: bool, approved: bool,
             body_reply: str | None = None) -> list[str]:
    by_id = {f['thread_id']: f for f in findings}
    errors = []
    for action in actions:
        thread_id = action.get('thread_id')
        if thread_id not in by_id:
            errors.append(f"{thread_id}: not a finding of this review")
        if action.get('verdict') not in VERDICTS:
            errors.append(f"{thread_id}: verdict must be one of {', '.join(VERDICTS)}")
        reply = (action.get('reply') or '').strip()
        if not reply:
            errors.append(f"{thread_id}: every finding needs a reply, whatever the verdict")
        elif not reply.startswith(AI_REPLY_PREFIX):
            errors.append(f"{thread_id}: a reply must open with {AI_REPLY_PREFIX!r}")
    # A thread already resolved was actioned on an earlier pass; only an open one still owes a verdict.
    open_ids = {thread_id for thread_id, f in by_id.items() if not f['is_resolved']}
    missing = sorted(open_ids - {a.get('thread_id') for a in actions})
    errors += [f"{thread_id}: no verdict given" for thread_id in missing]
    if body_reply is not None and not body_reply.startswith(AI_REPLY_PREFIX):
        errors.append(f"body_reply must open with {AI_REPLY_PREFIX!r}")
    if not bot and not approved and (body_reply or any((a.get('reply') or '').strip() for a in actions)):
        errors.append(
            'replying to a person needs their go-ahead: ask, then set '
            '`replies_approved = true` in the actions file'
        )
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


def rocket(node_id: str) -> None:
    run('gh', 'api', 'graphql',
        '-f', 'query=mutation($id:ID!){addReaction(input:{subjectId:$id,content:ROCKET}){reaction{content}}}',
        '-f', f"id={node_id}")


def post_issue_comment(repo: str, number: int, body: str) -> None:
    run('gh', 'api', '--input', '-', '-X', 'POST', f"repos/{repo}/issues/{number}/comments",
        stdin=json.dumps({'body': body}))


def split_resolved(state: dict) -> dict:
    """Pull already-resolved findings out of `findings` into their own key.

    A thread someone (often the PR author, replying directly on GitHub) already
    resolved owes no verdict — `validate` already knows this — but leaving it mixed
    into `findings` next to every open item is exactly how a resolved finding gets
    re-actioned: the only signal it carries is an `is_resolved` flag buried in the
    object, easy to miss when scanning a list for what still needs a verdict.
    """
    findings = state['findings']
    return {
        **state,
        'findings': [f for f in findings if not f['is_resolved']],
        'already_resolved': [f for f in findings if f['is_resolved']],
    }


def cmd_fetch(number: int | None, review_id: int | None) -> None:
    """A single review with `--review-id`; every un-acked bot review without it.

    The default sweep is what lets one invocation action a PR that collected several
    pending CodeRabbit passes instead of only the one `fetch` happened to be run
    against — a review left unpicked here never gets a rocket, and stays silently
    un-actioned.
    """
    repo, number, branch, _ = pr_context(number)
    threads = fetch_threads(repo, number)
    branch_info = {'name': branch, 'worktree': worktree_for(branch)}
    if review_id is not None:
        state = split_resolved(collect(repo, number, review_id, threads))
        print(json.dumps({'branch': branch_info, **state}, indent=2))
        return
    reviews = all_reviews(repo, number)
    pending_ids = pending_review_ids(repo, number, threads)
    bot_ids = [r['id'] for r in reviews if r['id'] in pending_ids and is_bot(r)]
    states = [split_resolved(collect(repo, number, rid, threads)) for rid in bot_ids]
    print(json.dumps({'branch': branch_info, 'reviews': states}, indent=2))


def cmd_status(number: int | None) -> None:
    """List every review (bot or human) that still needs a look.

    "Needs a look" means it has an unresolved thread tied to it (even one from
    a review already rocketed, since a reply or a manual unresolve can reopen
    a thread after the rocket) or a CHANGES_REQUESTED verdict with no open
    thread left to close it out. A rocketed review with every thread resolved
    is done and stays out. Unchecked boxes in the pull request's description,
    its `AI Summary:` comment, and each review's own body come back under
    `open_checkboxes`, beside the reviews under `pending`.

    A review with no open thread has nowhere to reply into (general feedback
    in the review body itself, not an inline comment), so its `body` is
    quoted in the output instead of a thread to fetch and act on directly.
    """
    repo, number, _, pr = pr_context(number)
    reviews = fetch_reviews(repo, number)
    print(json.dumps({
        'open_checkboxes': (description_checkboxes(pr) + open_checkboxes(fetch_comments(repo, number))
                            + review_checkboxes(reviews)),
        'pending': pending_reviews(reviews, fetch_threads(repo, number)),
    }, indent=2))


def pending_reviews(reviews: list[dict], threads: list[dict]) -> list[dict]:
    open_by_review: dict[int, int] = {}
    for thread in threads:
        if thread['isResolved']:
            continue
        review_id = review_of(thread)
        if review_id is not None:
            open_by_review[review_id] = open_by_review.get(review_id, 0) + 1

    watch_doggo_rounds = [r for r in reviews if WATCH_DOGGO_MARKER in (r['body'] or '')]
    latest_round = max(watch_doggo_rounds, key=lambda r: r['submittedAt'], default=None)
    pending = []
    for review in reviews:
        rocketed = review['reactions']['totalCount'] > 0
        open_threads = open_by_review.get(review['databaseId'], 0)
        if open_threads == 0 and (rocketed or not withholds_approval(review, latest_round)):
            continue
        entry = {
            'author': review['author']['login'] if review['author'] else None,
            'open_threads': open_threads,
            'previously_rocketed': rocketed,
            'review_id': review['databaseId'],
            'state': review['state'],
            'submitted_at': review['submittedAt'],
            'url': review['url'],
        }
        if open_threads == 0 and (review['body'] or '').strip():
            entry['body'] = '\n'.join(f"> {line}" for line in review['body'].splitlines())
        pending.append(entry)
    return pending


def withholds_approval(review: dict, latest_round: dict | None) -> bool:
    """A verdict that still blocks with no thread left open to carry it.

    Watch Doggo posts COMMENTED and lists earlier blocking findings only in the
    body ("Still open from earlier rounds"), and each round supersedes the last,
    so only its newest body's headline counts.
    """
    if review['state'] == 'CHANGES_REQUESTED':
        return True
    return review is latest_round and WATCH_DOGGO_APPROVED not in (review['body'] or '')


def since_date(since: str) -> str:
    """A --since of "8h", "7d", or "2026-08-28", as the date or UTC instant GitHub search wants."""
    if since.endswith('h') and since[:-1].isdigit():
        cutoff = dt.datetime.now(dt.UTC) - dt.timedelta(hours=int(since[:-1]))
        return cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')
    if since.endswith('d') and since[:-1].isdigit():
        return (dt.date.today() - dt.timedelta(days=int(since[:-1]))).isoformat()
    try:
        return dt.date.fromisoformat(since).isoformat()
    except ValueError:
        sys.exit(f"--since takes Nh, Nd, or YYYY-MM-DD, not {since!r}")


def merged_prs(repo: str, author: str, since: str, limit: int) -> list[dict]:
    return run_json('gh', 'search', 'prs', f"--repo={repo}", f"--author={author}",
                    '--merged', f"--merged-at=>={since}", f"--limit={limit}",
                    '--json', 'body,number,title,url,closedAt')


def summary_comment(comments: list[dict]) -> dict | None:
    return next((c for c in comments if (c['body'] or '').startswith(SUMMARY_MARKER)), None)


def box_lines(body: str) -> list[tuple[int, str]]:
    """Index and text of every unchecked box outside fenced code."""
    boxes, fenced = [], False
    for index, line in enumerate(body.splitlines()):
        if line.lstrip().startswith('```'):
            fenced = not fenced
        elif not fenced and (match := OPEN_BOX_RE.match(line)):
            boxes.append((index, match['text'].strip()))
    return boxes


def description_checkboxes(pr: dict) -> list[dict]:
    """Unchecked boxes in the pull request's own description, skipping fenced code.

    `tick` can check these off too, PATCHing the pull request body directly
    rather than the `AI Summary:` comment.
    """
    return [{'source': 'description', 'text': text, 'url': pr['url']}
            for _, text in box_lines(pr['body'] or '')]


def open_checkboxes(comments: list[dict]) -> list[dict]:
    """Unchecked boxes in the `AI Summary:` comment, skipping fenced code.

    `tick` checks these off in place, by PATCHing this same comment, the same
    as it does the pull request description.
    """
    summary = summary_comment(comments)
    if summary is None:
        return []
    return [{'source': 'summary', 'text': text, 'url': summary['url']}
            for _, text in box_lines(summary['body'])]


def review_checkboxes(reviews: list[dict]) -> list[dict]:
    """Unchecked boxes in a review's own body, e.g. Watch Doggo's non-blocking
    "Ticket progress" checklist.

    These sit outside the review's approval state, so an approved review can
    still carry one, and outside the `AI Summary:` comment `tick` patches, so
    settling one is recorded in the report or the new PR rather than checked
    off in place.
    """
    return [{'source': 'review', 'text': text, 'url': review['url']}
            for review in reviews for _, text in box_lines(review['body'] or '')]


def fetch_comments(repo: str, number: int) -> list[dict]:
    comments = run_json('gh', 'api', '--paginate', f"repos/{repo}/issues/{number}/comments")
    return [{'body': c['body'], 'id': c['id'], 'url': c['html_url']} for c in comments]


def sweep_pr(repo: str, pr: dict) -> tuple[list[dict], list[dict]]:
    """Every un-acked review and unchecked box (description, summary, or review
    body) on one pull request, in one read where a page holds it."""
    number = pr['number']
    owner, name = repo.split('/')
    data = run_json('gh', 'api', 'graphql', '-f', f"query={SWEEP_QUERY}",
                    '-f', f"owner={owner}", '-f', f"repo={name}",
                    '-F', f"number={number}")['data']['repository']['pullRequest']
    reviews, threads, comments = data['reviews'], data['reviewThreads'], data['comments']
    if reviews['pageInfo']['hasNextPage'] or threads['pageInfo']['hasNextPage']:
        review_nodes = fetch_reviews(repo, number)
        pending = pending_reviews(review_nodes, fetch_threads(repo, number))
    else:
        review_nodes = reviews['nodes']
        pending = pending_reviews(review_nodes, threads['nodes'])
    boxes = description_checkboxes(pr) + review_checkboxes(review_nodes)
    if comments['pageInfo']['hasPreviousPage']:
        boxes += open_checkboxes(fetch_comments(repo, number))
    else:
        boxes += open_checkboxes(comments['nodes'])
    return pending, boxes


def cmd_sweep(repo: str | None, author: str, since: str, limit: int) -> None:
    """Un-acked reviews across the pull requests an author merged in a window.

    A review submitted at merge time or after it never blocks anything, so it
    goes unread; this is the only surface that finds one. The rule is `status`'s,
    per pull request, plus any unchecked box in its description or `AI Summary:`
    comment, and a pull request with neither is left out.
    """
    repo = repo or run_json('gh', 'repo', 'view', '--json', 'nameWithOwner')['nameWithOwner']
    cutoff = since_date(since)
    prs = merged_prs(repo, author, cutoff, limit)
    swept = []
    for pr in prs:
        pending, boxes = sweep_pr(repo, pr)
        if pending or boxes:
            swept.append({'merged_at': pr['closedAt'], 'number': pr['number'],
                          'open_checkboxes': boxes, 'pending': pending,
                          'title': pr['title'], 'url': pr['url']})
    print(json.dumps({'author': author, 'pull_requests': sorted(swept, key=lambda p: p['number']),
                      'repo': repo, 'scanned': len(prs), 'since': cutoff}, indent=2))


def require_pushed(number: int, branch: str) -> None:
    """A reply must describe code the reviewer can open, so the local branch may not be ahead of the PR."""
    local = subprocess.run(
        ['git', 'rev-parse', '--verify', '--quiet', f"refs/heads/{branch}^{{commit}}"],
        text=True, capture_output=True,
    ).stdout.strip()
    if not local:
        print(f"note: no local {branch} branch here, skipping the push check", file=sys.stderr)
        return
    head = run('gh', 'pr', 'view', str(number), '--json', 'headRefOid', '--jq', '.headRefOid')
    if local == head:
        return
    if subprocess.run(['git', 'cat-file', '-e', f"{head}^{{commit}}"], capture_output=True).returncode:
        run('git', 'fetch', '--quiet', 'origin', head)
    ancestor = subprocess.run(['git', 'merge-base', '--is-ancestor', local, head], capture_output=True, text=True)
    if ancestor.returncode == 1:
        sys.exit(f"Refusing to post: {branch} ({local[:10]}) has commits #{number} ({head[:10]}) does not. Push first.")
    if ancestor.returncode:
        sys.exit(f"Could not compare {branch} with #{number}'s head: {ancestor.stderr.strip()}")


def cmd_apply(number: int | None, path: str | None) -> None:
    payload = tomllib.loads(sys.stdin.read() if path is None else open(path).read())
    review_id = payload.get('review_id')
    if review_id is None:
        sys.exit('Actions file needs a review_id')
    repo, number, branch, _ = pr_context(number)
    require_pushed(number, branch)
    threads = {t['id']: t for t in fetch_threads(repo, number)}
    state = collect(repo, number, review_id, list(threads.values()))
    actions = payload.get('actions') or []
    body_reply = payload.get('body_reply')

    bot = state['review']['is_bot']
    errors = validate(
        actions,
        state['findings'],
        bot=bot,
        approved=bool(payload.get('replies_approved')),
        body_reply=body_reply,
    )
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

    if body_reply:
        try:
            review = state['review']
            post_issue_comment(repo, number,
                               f"{body_reply}\n\nIn reply to [{review['author']}'s review]({review['url']})")
            print('posted body_reply')
        except subprocess.CalledProcessError as error:
            failed.append(f"body_reply: {error.stderr.strip() or error}")

    if failed:
        sys.exit('Left the review un-acknowledged:\n' + '\n'.join(f"  {f}" for f in failed))
    rocket(state['review']['node_id'])
    who = state['review']['author'] + (' (bot)' if bot else '')
    print(f"🚀 review {state['review']['id']} by {who} — {len(actions)} actioned")


def validate_ticks(ticks: list[dict], open_texts: list[str]) -> list[str]:
    errors = []
    for tick in ticks:
        text = tick.get('text', '')
        if tick.get('how') not in TICK_HOW:
            errors.append(f"{text[:60]!r}: how must be one of {', '.join(TICK_HOW)}")
        if not (tick.get('note') or '').strip():
            errors.append(f"{text[:60]!r}: note is required, it is the reader's only evidence")
        if open_texts.count(text) != 1:
            errors.append(f"{text[:60]!r}: must match exactly one unchecked box, verbatim")
    return errors


def ticked_body(body: str, texts: set[str]) -> str:
    lines = body.splitlines()
    for index, text in box_lines(body):
        if text in texts:
            lines[index] = lines[index].replace('[ ]', '[x]', 1)
    return '\n'.join(lines)


def tick_report(ticks: list[dict], locations: list[tuple[str, str]]) -> str:
    where = ' and '.join(f"the [{label}]({url})" for label, url in locations)
    sections = [f"{AI_REPLY_PREFIX}Settled checkboxes in {where}."]
    for how, label in TICK_HOW.items():
        rows = [f"- {t['text']}\n  {t['note'].strip()}" for t in ticks if t['how'] == how]
        if rows:
            sections.append(f"**{label}**\n\n" + '\n'.join(rows))
    return '\n\n'.join(sections)


def cmd_tick(number: int | None, path: str | None) -> None:
    """Check off description or `AI Summary:` boxes and append one comment saying
    how each settled.

    `how` is `auto` (verified by the agent), `asked` (the human confirmed it), or
    `open` (deliberately left unchecked, and still reported so the reader knows it
    was looked at). Every entry needs a `note` and must name one unchecked box
    verbatim, in either place, or nothing is posted. A box from a review's own body
    (`source: "review"` in `sweep`/`status` output) has no comment or description
    `tick` can PATCH, so it isn't a valid target; settle it in the report or the new
    PR instead.
    """
    payload = tomllib.loads(sys.stdin.read() if path is None else open(path).read())
    ticks = payload.get('boxes') or []
    if not ticks:
        sys.exit('Tick file needs at least one [[boxes]] entry')
    repo, number, _, pr = pr_context(number)
    summary = summary_comment(fetch_comments(repo, number))
    description_texts = [text for _, text in box_lines(pr['body'] or '')]
    summary_texts = [text for _, text in box_lines(summary['body'])] if summary else []
    errors = validate_ticks(ticks, description_texts + summary_texts)
    if errors:
        sys.exit('Refusing to tick:\n' + '\n'.join(f"  {e}" for e in errors))

    checked = {t['text'] for t in ticks if t['how'] != 'open'}
    tick_texts = {t['text'] for t in ticks}
    description_set, summary_set = set(description_texts), set(summary_texts)
    locations = []

    if tick_texts & description_set:
        locations.append(('description', pr['url']))
        if checked & description_set:
            run('gh', 'api', '-X', 'PATCH', f"repos/{repo}/pulls/{number}",
                '-f', f"body={ticked_body(pr['body'] or '', checked)}")
    if summary is not None and tick_texts & summary_set:
        locations.append(('AI Summary', summary['url']))
        if checked & summary_set:
            run('gh', 'api', '--input', '-', '-X', 'PATCH',
                f"repos/{repo}/issues/comments/{summary['id']}",
                stdin=json.dumps({'body': ticked_body(summary['body'], checked)}))

    post_issue_comment(repo, number, tick_report(ticks, locations))
    print(f"#{number}: ticked {len(checked)}, left {len(ticks) - len(checked)} open")


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

    tick_parser = sub.add_parser('tick')
    tick_parser.add_argument('--pr', type=int)
    tick_parser.add_argument('--file')

    sweep_parser = sub.add_parser('sweep')
    sweep_parser.add_argument('--repo')
    sweep_parser.add_argument('--author', default='@me')
    sweep_parser.add_argument('--since', default='7d')
    sweep_parser.add_argument('--limit', type=int, default=100)

    args = parser.parse_args()
    try:
        if args.command == 'fetch':
            cmd_fetch(args.pr, args.review_id)
        elif args.command == 'status':
            cmd_status(args.pr)
        elif args.command == 'sweep':
            cmd_sweep(args.repo, args.author, args.since, args.limit)
        elif args.command == 'tick':
            cmd_tick(args.pr, args.file)
        else:
            cmd_apply(args.pr, args.file)
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr or str(error))


if __name__ == '__main__':
    main()
