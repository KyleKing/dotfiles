---
name: resolve-conflicts
description: Resolve git merge, rebase, or cherry-pick conflicts. Use when asked to resolve merge conflicts, review git conflicts, finish an in-progress merge or rebase, or when git status shows unmerged paths. Covers the ours/theirs inversion between merge and rebase, zdiff3 markers, and mergiraf.
---

# Resolving conflicts

Git first. A jj repo (`.jj/` present, `.git/` absent) is a different model — see the
end.

## Read the environment before touching anything

Two settings in this environment change what you are looking at:

- `~/.gitattributes_global` applies `* merge=mergiraf` to **every** file. Mergiraf
  has already attempted a syntax-aware resolve before you see the conflict, so what
  remains is genuinely ambiguous. Do not assume a whole-file take is safe just
  because the conflict looks small.
- `merge.conflictStyle = zdiff3`, so markers include the common ancestor between
  `|||||||` and `=======`. Read it. Without the base you cannot tell an addition on
  one side from a deletion on the other, and they look identical.

`rerere.enabled = false`, deliberately, with the recorded reason that it "can
auto-stage stale resolutions if left unchecked". Do not turn it on. If it seems
worth revisiting, say so and let the user decide — the risk they describe is really
`rerere.autoUpdate`, which defaults to false anyway.

## ours and theirs invert between merge and rebase

Get this right before running any `--ours` / `--theirs`.

| | `--ours` | `--theirs` |
|---|---|---|
| `git merge` | HEAD, your branch | the branch being merged in |
| `git rebase` / `git cherry-pick` | upstream, the branch you are rebasing **onto** | **your own** commit being replayed |

The rule that survives both: `--theirs` always means the patch currently being
applied. Taking `--ours` on every file during a rebase silently discards the commit
you are rebasing.

## Procedure

```sh
git status --short                     # UU / AA / DU
git diff --name-only --diff-filter=U

git diff                               # combined diff against both parents
git log --merge -p -- <path>           # commits touching <path> on only one side
git show :1:<path>                     # common ancestor
git show :2:<path>                     # ours
git show :3:<path>                     # theirs
```

Resolve by editing. Reach for a whole-file take only when you have confirmed the
other side changed nothing else in that file — `git checkout --ours -- <path>` takes
the entire stage-2 file, dropping every non-conflicting change the other side made.

Made a mess of a file? Put the markers back rather than starting over:

```sh
git checkout -m -- <path>
git restore --merge <path>
git restore --conflict=diff3 <path>    # markers back, with the base shown
```

Finish with `git add <path>`, then `git merge --continue` or `git rebase --continue`.

`git add` marks a path resolved whether or not you actually removed the markers.
Grep for `<<<<<<<` across the resolved files before continuing.

## Verify, do not assume

A resolution that compiles is not a resolution that is correct. Run the tests. When
the conflict involved a feature the user named (a sorting rule, a dedup check),
confirm that feature still behaves — a conflict resolution is the easiest place to
silently revert one.

## -X ours is not -s ours

`-X ours` auto-resolves conflicting hunks in your favor while keeping the other
side's non-conflicting changes. `-s ours` never looks at the other tree at all: it
keeps your tree wholesale and records a merge commit claiming you integrated the
other branch, so those changes will never be re-attempted. During a rebase, `-s ours`
empties every patch and makes no sense; use `-X ours` / `-X theirs`, inverted per the
table above.

## Dry run

```sh
git merge-tree --write-tree main feature   # exit 0 clean, 1 conflicts; nothing touched
git merge-tree --write-tree --name-only main feature
```

Needs git 2.38+. `git merge --no-commit --no-ff` also works but dirties the index and
worktree, so it needs a mandatory `git merge --abort` afterward.

## Backing out

`git merge --abort`, `git rebase --abort` / `--skip`, `git cherry-pick --abort`.
`git reset --hard ORIG_HEAD` returns to the pre-operation state, and `git reflog`
plus `git reset --hard HEAD@{N}` is the real safety net.

## jj repos

jj records conflicts inside commits, so a rebase always succeeds and there is no
`--continue`. Conflicted commits show a red `x` in `jj log`; watch for it, because
nothing blocks on a conflict and one can ride along unnoticed.

```sh
jj new <conflicted-commit>
jj resolve --list
jj resolve
jj squash          # descendants re-rebase automatically
```

Markers are diff-based by default, not git's two-block form: `+++++++` opens a full
snapshot of one side and `%%%%%%%` opens a diff to apply to it. Resolving means
applying each diff to the snapshot by hand. `jj resolve` handles two sides plus a
base; multi-sided conflicts must be edited directly. Undo with `jj undo` or
`jj op restore <id>`.

If the repo is non-colocated (no `.git` directory at all), git commands do not apply.
Confirm before running any.
