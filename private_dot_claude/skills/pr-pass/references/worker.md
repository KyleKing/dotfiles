# Per-PR worker playbook

You own one PR in one checkout for one pass.
You may commit and push its branch.
The coordinator's prompt gives you the PR's status entry, the directory, the repo
profile, and the pass number.
Work only in that directory, and only on that PR's branch.
Never create a git worktree, a scratch database, or an ad-hoc container, and never
`git stash`.

Move fast. The coordinator runs up to four passes, and CI is the full-suite backstop.
Do not wait on CI: never `gh pr checks --watch`, never a poll loop, never a Monitor.
Read the checks as they stand now and move on.

## 1. Sync with the base

Run `<skill-dir>/scripts/sync.sh <pr>` from the directory.
It checks the tree is clean, switches to the branch, fast-forwards it from origin, and
merges the PR's base as GitHub reports it (the only safe direction in a stack).

- Exit 0: continue
- Exit 2: a precondition failed. Stop and report it verbatim
- Exit 1: conflicts are in the tree. Resolve each file by reading both sides' intent
    from the markers and the commits that produced them (`git log -p --merge -- <file>`),
    never by preferring a side wholesale.
    Commit the merge once it is correct against the base.
    If the base has since landed something that duplicates this branch's code, drop the
    duplicate in a separate follow-up commit, so a reviewer can see which half broke
    anything.
    When the right resolution depends on intent you cannot recover from the code, the
    PR, or the linked ticket, leave the merge uncommitted, stop, and return the question

After any merge that brought in new commits, reseat ordered artifacts the base move made
stale: use the repo profile's skill for them (a migration-rebase skill, for instance)
and
confirm the ordering is single-headed before moving on.

## 2. Action the reviews

Invoke `change-review-apply` for this PR, with three overrides:

- Its step 3 escalations and any reply to a human's review come back to the coordinator
    in your report instead of an AskUserQuestion.
    Do everything else first
- Its step 5 full ladder is replaced by the targeted tests below
- Do not wait for a new review to land after pushing; the next pass picks it up

When a finding's validity turns on product intent, read the ticket named in the branch
or PR title (Linear, or whichever tracker the repo uses) and the thread it came from
before deciding.
Then read the PR's summary comment and description: a decision recorded there after the
ticket was written outranks the ticket text a bot quotes back.
When the two disagree and nothing records which one won, that is a question, not a
verdict.

Post a reply that points at a fix only once that fix is pushed, including a fix that
lands on another PR in the stack.

## 3. Fix CI failures and warnings

Take the failed checks and warning annotations from the status entry.
The run predates this pass's base merge, so first re-run any failing check that is cheap
locally (a lint or AST guard, one test file): a failure inherited from a stale base
often
disappears with the merge.
For each, pull the failure with `gh-lazydispatch export diagnose <run-id>` (the run id
is in the check's link), not `gh run view --log`.

- Fix the class, not the first instance: a red job stops at its first error, so sweep
    the diff for the siblings before pushing
- Warnings count when this PR's diff introduced them or touches the flagged line.
    Pre-existing warnings elsewhere are an escalation, not a same-PR fix
- A failure that looks transient (network, runner, registry) gets one
    `gh run rerun <run-id> --failed` and no code change
- A failure inherited from the base shows the same way on the PR below; fix it at the
    lowest PR that owns the file, and say so in the report if that is not this PR
- Pending checks are not yours this pass

## 4. Validate narrowly

Hooks already cover format, lint, and types per commit, so trust them.
Run only the tests covering files you touched, with the profile's targeted-test command.
Starting the dev stack for a UI check is fine when it proves something CI cannot.
Never run a full suite: CI runs it on push.
A test that only runs in a dedicated CI job (behind a marker or an env var naming a
service) skips silently in a plain local run, so a skip is not a pass: start the
service it needs in-process or on a spare port and run it for real.

## 5. Commit and push

Conventional Commits in the user's voice, one readable subject, no body unless the why
is non-obvious, and nothing that references AI or a model.
Run commit and push as separate commands, and confirm with `git log -1` that the commit
landed before pushing, because a hook failure piped through a filter can look like
success.
Push with plain `git push`; never force.

Refresh the PR summary through the profile's PR-writeup path only when something the
summary claims changed.
Fetch the current text first and edit it in place; never draft a fresh one, and never
touch a PR body the user wrote.

## Report

Return a short structured report, not logs:

- `pr`, `pushed_sha`, and whether the base merge brought commits or conflicts
- findings actioned per review, as verdict counts
- CI items fixed, rerun, or left, each with one line of cause
- `escalations`: real defects outside this PR's diff, each with file, one-line claim,
    and any existing ticket
- `questions`: decisions only the user can make, including human-review replies
    drafted in full and waiting for approval
- anything you could not finish and why
