# Inconsistent state from regenerating files

chezmoi applies `.chezmoiignore` when adding and applying targets, but never
purges source entries that already exist.
A file tracked before its ignore
rule existed stays in the source state until `chezmoi forget` removes it.

The failure mode is a regenerating file — bytecode caches, build output —
whose executable bit changes between runs.
`chezmoi add` records the mode in
the source filename (`executable_` prefix), so re-adding under a different
mode leaves two source entries mapping to one target.
Every chezmoi command
then fails with `inconsistent state`, including `forget`, so the stale entry
has to be deleted by hand before `forget --force` can run.

Prevention:

- Ignore regenerating directories before running `chezmoi add` on a broad
    parent.
- Keep `.gitignore` aligned with `.chezmoiignore`.
    Source entries that are
    git-ignored never sync, so each machine's checkout accumulates its own
    untracked debris — audit the other machines' source dirs when an ignore
    rule is added.
