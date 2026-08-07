---

## name: coderabbit-apply description: Pull the latest CodeRabbit review's "Prompt for all review comments with AI agents" block off a PR and action it — adversarially verifying each finding, fixing the whole class of problem rather than the cited lines, committing incrementally, and resolving that review's threads. Use when asked to apply, address, or action CodeRabbit comments.

# Apply a CodeRabbit review

CodeRabbit posts one review per push. Its top-level review body carries a collapsed
`🤖 Prompt for all review comments with AI agents` block that lists every inline and
nitpick finding in one place.
That block is the work list — read it instead of walking threads one by one.

## Step 1 — Find the review

```sh
PR=$(gh pr view --json number --jq .number)     # or take the number/URL the user gave
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate \
    --jq '[.[] | select(.user.login=="coderabbitai[bot]")] | last | {id, submitted_at, state}'
```

The newest CodeRabbit review is not always the right one: a review posted for a push
with no findings has no prompt block.
Walk backwards until a body contains the marker, and say which review id you settled on.

**The PR branch is usually not the checked-out `HEAD`.** Resolve where the branch
actually lives before editing — `gh pr view <n> --json headRefName` plus
`git worktree list`.
If it sits in another worktree, `cd` there; never fetch the branch into the current tree
and edit alongside unrelated work.
If that worktree has uncommitted changes you did not make, stop and report it (see the
working-tree rule in `CLAUDE.md`).

## Step 2 — Extract the prompt block

````sh
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID" --jq .body > cr-body.md
awk '/Prompt for all review comments/{f=1} f&&/^```/{n++; if(n==1)next; if(n==2)exit} f&&n==1' cr-body.md
````

Keep `cr-body.md` around: the per-finding sections above the block carry CodeRabbit's
severity labels and reasoning, which the combined block strips.
Write it to the worktree, not the scratchpad, if you want it after the task.

Also list the threads so you can resolve them in step 5 and cross-check that the block
covers everything:

```sh
gh api graphql -f query='
query($owner:String!,$repo:String!,$number:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$number){
    reviewThreads(first:50){ nodes { id isResolved isOutdated path line
      comments(first:1){ nodes { author{login} pullRequestReview{ databaseId } } } } } } } }' \
    -f owner="$OWNER" -f repo="$REPO" -F number="$PR" \
--jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved==false)
        | {id, path, line, review: .comments.nodes[0].pullRequestReview.databaseId}'
```

Match threads to the review id from step 1.
Threads from earlier reviews are out of scope unless the user says otherwise — name them
in the final report rather than silently resolving them.

## Step 3 — Verify each finding adversarially

CodeRabbit reasons about a diff snapshot and is confidently wrong often enough that
applying its prompt verbatim regresses code.
For every finding, read the current file and decide which it is:

- **Real** — reproduce the failure in your head or in a test first.
    State the concrete input or interleaving that breaks.
    If you cannot, it is not yet real
- **Stale** — a later commit already fixed it.
    Skip with the commit or line as evidence
- **Wrong** — the premise misreads the code (a guard it did not see, a caller that cannot
    pass that value, a library contract it assumed).
    Skip with the specific reason
- **Against repo policy** — the fix conflicts with the repo's `AGENTS.md`/`CLAUDE.md` or a
    project skill.
    CodeRabbit is fond of suggestions this rules out: explanatory inline comments,
    docstrings on private helpers, layering violations, hand-rolled versions of a shared
    component.
    Do the policy-compliant equivalent, or skip

Push back hardest on findings that ask you to widen scope for its own sake: version
pinning, extra abstraction, "add a contract test" for behavior a real test already
covers.
Those are often busywork. Where a finding names a security or data-loss risk, treat it
as real until you have disproved it.

## Step 4 — Fix the class, not the line

CodeRabbit cites the instances it happened to look at.
Fix every instance of the same defect inside the PR's diff, then say what you widened
and why:

- the bare `except:` it flagged at one call site, and the three siblings in the same
    module
- the missing `await`/cancellation guard on one path, and the other paths through the same
    executor
- one unbound exception variable, and every other swallowed exception in the file
- a test fake that does not mirror the real guard, and the other fakes in that test module
    that drift the same way

Stay inside the PR's scope. A defect in a file this PR does not touch is a follow-up
note, not an edit.

## Step 5 — Commit, validate, resolve

Commit incrementally, one logical fix per commit, Conventional Commits with a
capitalized summary.
Do not push — the user reviews and pushes.

Run the narrowest test for what you touched as you go, then the repo's full
format/typecheck/test ladder once over the combined diff (in IRM, the `pre-pr-qa` skill
picks the right gates).
Report failures verbatim; never call a finding fixed on the strength of the edit alone.

Resolve a thread only after its fix is committed:

```sh
gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id="$THREAD_ID"
```

For a finding you deliberately skipped, leave the thread open and put the reason in the
final report so the user can reply in their own voice.
Use the `change-review` skill if they want the reply drafted.

## Report

Lead with the review id and a one-line-per-finding verdict table (fixed / stale / wrong
/ policy), then the broader fixes you added beyond the block, then anything left open
with its reason, then the gate results.
Keep it to the lines that change the user's next action.
