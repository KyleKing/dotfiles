# Per-repo worker playbook

You own one repo end to end. You may commit and push to its default branch.
Read this once; the orchestrator's prompt gives you only the repo, its assessment
JSON, and any repo-specific dispositions.

## Commit rules

Conventional Commits in Kyle's voice: single readable subject, no body unless the
why is non-obvious. NEVER reference AI/Claude anywhere in a commit: no
Co-Authored-By, no session trailers, no "generated with".

Never pipe `git commit` (or chain it with `&&` into a push) through a filter like
`tail` — the pipe's exit code masks a hook failure, and the push then ships
without the commit. Run commit and push as separate commands and confirm with
`git log -1` that the commit actually landed. Hooks here rewrite files
(toml-sort, whitespace fixers); when a commit fails that way, `git add -A` the
hook's edits and commit again.

## Standard sequence

1. `git remote set-head origin -a` (repairs dangling origin/HEAD, which breaks
   the hk pre-push commitizen check)
2. Resolve local state per the approved disposition: pull if behind, commit
   dirty work, push if ahead. Pre-existing staged files ride along as-is, but a
   change set that looks mid-operation is assumed incomplete: verify intent and
   escalate rather than guessing
3. Gates: prefer a repo skill or CLAUDE.md instruction, else `mise tasks`; the
   usual pair is `mise run ci` and `mise exec -- golangci-lint run ./...`
4. Dependabot: merge a green Dependabot PR over duplicating its bump; otherwise
   `go get <module>@<first-patched> && go mod tidy`, one `fix(deps):` commit per
   advisory; transitive-only vulns with no reachable fix get a note, not a
   replace directive
5. Push, then run the bundled `wait-ci.sh <owner/repo> <sha>` (blocking; prints
   per-workflow conclusions and a filtered failure tail). Pushing fix/feat
   commits triggers Bump Version, which pushes a `bump:` commit back:
   `git pull --rebase` before every push and re-sync after workflows finish
6. CI failure: root-cause it from the wait-ci tail. Minimal correct fixes only:
   no skipped tests, no widened timeouts, no disabled linters. Three
   fix-and-push iterations without a new root cause means stop and report
7. Append a dated action log to .freshening.md in the repo root (globally
   gitignored; create if missing)
8. Leave follow-up items for Kyle in the repo's notes file (doing.txt under a
   dated heading, or NEXT_STEPS.md where that is the convention), one line each

## Copier children

- `copier update --UNSAFE --conflict=rej --defaults` on a clean tree; commit as
  `build: copier-auto-update`
- Each .rej holds LOCAL customizations that failed to re-apply: re-apply real
  local content by hand, discard hunks the new template supersedes, delete the
  .rej files (a hook blocks them)
- Files in the template's `_skip_if_exists` are never updated by copier. After
  every update, diff each one against the template checkout's `.ctt/default/`
  render and hand-sync intentional template changes
- Run `mise install` after the update; pins may have moved

## Transient CI failures

Network timeouts, registry outages, and runner infrastructure errors get one
`gh run rerun --failed` before any code change.
