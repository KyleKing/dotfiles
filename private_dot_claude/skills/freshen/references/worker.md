# Per-repo worker playbook

You own one repo end to end. You may commit and push to its default branch.
Read this once; the orchestrator's prompt gives you only the repo, its assessment JSON,
and any repo-specific dispositions.

## Commit rules

Conventional Commits in Kyle's voice: single readable subject, no body unless the why is
non-obvious.
NEVER reference AI/Claude anywhere in a commit: no Co-Authored-By, no session trailers,
no "generated with".

Every commit you make sets the committer name to `freshen-bot`, so a pass is greppable
later.
Set it per command and change nothing else — author, author email, and committer email
all stay as configured, which keeps the ssh signature valid and the committer email
verified on Kyle's GitHub account:

```
GIT_COMMITTER_NAME=freshen-bot git commit -m "fix(deps): bump x/net to 0.38.0"
```

Confirm it landed with `git log -1 --format='%an / %cn / %G?'`; expect
`Kyle King / freshen-bot / G`.

Never pipe `git commit` (or chain it with `&&` into a push) through a filter like `tail`
— the pipe's exit code masks a hook failure, and the push then ships without the commit.
Run commit and push as separate commands and confirm with `git log -1` that the commit
actually landed.
Hooks here rewrite files (toml-sort, whitespace fixers); when a commit fails that way,
`git add -A` the hook's edits and commit again.

## Standard sequence

1. `git remote set-head origin -a` (repairs dangling origin/HEAD, which breaks the hk
    pre-push commitizen check)
1. Resolve local state per the approved disposition: pull if behind, commit dirty work,
    push if ahead.
    Pre-existing staged files ride along as-is, but a change set that looks mid-operation is
    assumed incomplete: verify intent and escalate rather than guessing
1. Gates: prefer a repo skill or CLAUDE.md instruction, else `mise tasks`; the usual pair
    is `mise run ci` and `mise exec -- golangci-lint run ./...`
1. Dependabot: merge a green Dependabot PR over duplicating its bump; otherwise
    `go get <module>@<first-patched> && go mod tidy`, one `fix(deps):` commit per advisory;
    transitive-only vulns with no reachable fix get a note, not a replace directive
1. Push, then run the bundled `wait-ci.sh <owner/repo> <sha>` (blocking; prints
    per-workflow conclusions and a filtered failure tail).
    Pushing fix/feat commits triggers Bump Version, which pushes a `bump:` commit back:
    `git pull --rebase` before every push and re-sync after workflows finish
1. CI failure: root-cause it from the wait-ci tail.
    Minimal correct fixes only: no skipped tests, no widened timeouts, no disabled linters.
    Three fix-and-push iterations without a new root cause means stop and report
1. Before pushing that fix, spend one round anticipating the next failure (see "Anticipate
    the rest of the class" below).
    Each round trip you avoid costs one full CI cycle
1. Append the pass's actions to .freshen.md in the repo root (globally gitignored; create
    if missing) under a `## <YYYY-MM-DD> · session <id>` heading, newest section first,
    using the pass id from the orchestrator's prompt.
    Never rewrite or truncate older sections
1. Leave follow-up items for Kyle in the repo's notes file (doing.txt under a dated
    heading, or NEXT_STEPS.md where that is the convention), one line each

## Anticipate the rest of the class

A red job stops at its first failure, so its log shows one instance of a problem that
usually has siblings.
Fixing only the reported line buys a second red run that names the next one.
Before every fix push:

1. Reproduce locally with the command CI ran, not something close to it.
    Read the workflow step to get the real flags (`golangci-lint run ./...` with the repo
    config, `go test ./...` with the same tags, the same Go/Python version).
    A local run that passes while CI fails means you are running a different command
1. Run it to completion instead of stopping at the first error.
    Most tools have a flag for this
    (`golangci-lint --max-issues-per-linter=0 --max-same-issues=0`, `go vet ./...` over the
    whole module, `pytest` without `-x`, `prek run --all-files`).
    Fix everything it reports
1. Grep for the same class beyond that tool's reach: the renamed API at its other call
    sites, the same lint suppression in sibling packages, the same missing pin or permission
    in the other workflow files, the same pattern in `.ctt/` renders and template sources
1. Re-run the full local gate suite, not just the command that failed.
    A fix that satisfies the linter often breaks a test

Fold the whole sweep into one commit. Mention in the body only what the sweep found
beyond the reported error, and only when it is non-obvious.

## Copier children

- `copier update --UNSAFE --conflict=rej --defaults` on a clean tree; commit as
    `build: copier-auto-update`
- Each .rej holds LOCAL customizations that failed to re-apply: re-apply real local
    content by hand, discard hunks the new template supersedes, delete the .rej files (a
    hook blocks them)
- Files in the template's `_skip_if_exists` are never updated by copier.
    After every update, diff each one against the template checkout's `.ctt/default/` render
    and hand-sync intentional template changes
- Run `mise install` after the update; pins may have moved

## Transient CI failures

Network timeouts, registry outages, and runner infrastructure errors get one
`gh run rerun --failed` before any code change.
