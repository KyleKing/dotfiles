---
name: copier-template
description: Run and troubleshoot copier updates in a project generated from one of the user's templates, and maintain the templates themselves. Use when a task mentions copier, copier update, .copier-answers.yml, .rej files after an update, ctt or copier-template-tester, or one of calcipy_template, mdformat-plugin-template, my_go_template, or app-template.
---

# Copier

Reference: https://copier.readthedocs.io/en/stable/updating/

The user maintains four templates feeding roughly 23 repos, so most copier work is
fleet work rather than a one-off. Template-authoring side is in
[authoring.md](authoring.md).

| Template | `_subdirectory` |
|---|---|
| `gh:KyleKing/calcipy_template` | `package_template` |
| `gh:KyleKing/mdformat-plugin-template` | `package_template` |
| `gh:KyleKing/my_go_template` | `go_template` |
| `gh:kyleking/app-template` | `app_template` |

## Updating a project

His aliases, which differ from copier's defaults in one important way — he uses
`--conflict=rej`, not the default inline markers:

```sh
copier update --UNSAFE --conflict=rej            # copier-update
copier update --UNSAFE --conflict=rej --defaults # copier-auto-update
```

Fleet-wide: `mani run copier-auto-update --tags=calcipy-template`.

Procedure:

1. `git status` must be clean. Copier refuses on a dirty tree
   ("Destination repository is dirty; cannot continue"), and a dirty tree would mix
   uncommitted work into the diff copier re-applies.
2. `copier update --pretend` first when the update looks risky.
3. Run the alias above.
4. Review every `*.rej` by hand. Each holds diff hunks copier could not apply; the
   file itself already carries the new template content.
5. Delete the `.rej` files once resolved. A `language: fail` pre-commit hook
   (`copier-forbidden-files`, matching `\.rej$`) blocks the commit otherwise — that
   guard is intentional, do not bypass it.
6. Commit as `build: copier-auto-update`, or `build: partial copier-auto-update`
   when only some of it was taken.

`--UNSAFE` is required because his templates run Python in `_tasks`. Note that the
alias trusts every template it is ever pointed at, not just his own.

## How update actually works

It is a diff-and-reapply, not a git merge. Copier regenerates a fresh project from
the **old** template version using the recorded answers, diffs that against the
current project to extract local customization, re-renders with the **new** version,
then re-applies that diff. Conflicts are failed patch hunks.

That is why the answers file must be accurate: wrong answers mean a wrong baseline
and therefore a wrong diff.

## Local experimentation vs published tags

The answers file has two legitimate states, and the invariant that governs both:
`_commit` must name the template version the project actually reflects, reachable
from wherever `_src_path` points.

**Experimentation** — testing unpublished template changes against a real project.
Commit in the template repo first (copier reads it through git), point `_src_path`
at the local checkout, and update with `--vcs-ref=HEAD`. `_commit` lands on a
`git describe` ref or bare SHA that exists only locally. This state is fine on a
project branch or a throwaway tree, never on `main`.

**Published** — `_src_path` on the `gh:` form, `_commit` on a published tag. This is
the only state `main` and fleet runs (`mani run copier-auto-update`) may see, since
other machines cannot resolve a local path or an unpushed SHA.

Toggling back is a hand-edit both times, because `copier update` reads the source
from the answers file and offers no CLI override. Set `_src_path` to the `gh:` form
and `_commit` to the last published tag the project actually contains (usually the
tag the experiment branched from), then run a normal update once the template work
ships as a tag. Cleaner still: run the experiment on a branch, discard it with the
answers file when done, and let the real update come from `gh:` after the tag is
published — no answers-file archaeology.

## Footguns seen in these repos

**`_commit` left in the experimentation state.** Forgetting to toggle back leaves
`_commit` at a ref that was never pushed (`2.7.2-1-gb13734f`), and the next update
fails resolving it against the `gh:` source. `tlr/.copier-answers.yml` is sitting on
a bare SHA right now. Recover with the toggle-back procedure above.

**An untagged template.** Copier picks the target from PEP 440-sorted git tags, so
an untagged template gives `update` nothing to aim at. Use `--vcs-ref=HEAD`
explicitly, and expect no migrations to fire.

**Missing `.copier-answers.yml`.** Downstream tooling (calcipy) reads it and fails
with a bare "No such file or directory". Treat its absence as a real error, not a
default.

**Lowering `--context-lines` to dodge conflicts.** Fewer lines means fewer conflicts
and a real risk of a hunk landing in a similar-looking block elsewhere in the file.

**Version pinning.** `mise` pins `copier` and `copier-template-tester` to `latest`,
so behavior can change underfoot. Check the installed version before blaming a
config.

## update vs recopy

Use `update`. Reach for `recopy` only when the recorded `_commit` is unreachable,
the template restructured far enough that diff-apply produces garbage, or the
destination is not a git repo. `recopy` discards the update algorithm and overwrites
local edits by design, so run it from a clean tree and `git diff` afterward.

## Useful variants

```sh
copier update --defaults --data key="new"   # change exactly one answer
copier update --skip-answered               # -A, only ask never-answered questions
copier update --vcs-ref=v2.1.0              # pin an exact tag
copier update --vcs-ref=:current:           # re-answer, do not change version
copier check-update --quiet                 # exit 2 if a newer version exists
```
