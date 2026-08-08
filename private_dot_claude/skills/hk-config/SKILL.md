---
name: hk-config
description: Audit or write an hk.pkl config (jdx/hk git hooks). Use when creating hk.pkl, upgrading the pinned hk version, adding a linter step, or when fixes made by a pre-commit hook are not being staged. Covers version pinning, staging semantics, builtins, and DRY structure.
---

# hk.pkl configuration

Reference: https://hk.jdx.dev. Schema of record is `pkl/Config.pkl` in the pinned
release, not the website — the two disagree (the site claims `check_first` defaults to
`false`; the schema says `true`).

## Audit procedure

```sh
pkl eval hk.pkl >/dev/null      # hk silently skips a config that fails to evaluate
grep -o 'hk@[0-9.]*' hk.pkl | head -1
curl -sL https://api.github.com/repos/jdx/hk/releases/latest | grep '"tag_name"'
hk check --all
```

## The two rules that bite most

Pin the version as a literal in all three places (`amends`, `import`, `min_hk_version`)
and change them together on upgrade.
Hoisting a `local hk_version` above `amends` is a hard evaluation error.

On hk >= 1.33.0, delete `stage` globs from fix steps; the default `<JOB_FILES>` stages
exactly what the step touched, while an explicit glob pulls unreviewed files into the
commit.
Below 1.33.0 fixes are silently never staged, so upgrade the pin.
Keep an explicit `stage` only for codegen whose outputs differ from its inputs.

## Everything else

Broader changes read [reference.md](reference.md): debugging with `--plan`/`--why`,
tracing and timing, the full staging and pinning detail, the builtins migration table,
DRY structure with spreads and Groups, skipping a hook for one command, and writing a
new config from scratch.
