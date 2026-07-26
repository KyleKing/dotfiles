---
name: hk-config
description: Audit or write an hk.pkl config (jdx/hk git hooks). Use when creating hk.pkl, upgrading the pinned hk version, adding a linter step, or when fixes made by a pre-commit hook are not being staged. Covers version pinning, staging semantics, builtins, and DRY structure.
---

# hk.pkl configuration

Reference: https://hk.jdx.dev. Schema of record is `pkl/Config.pkl` in the pinned
release, not the website — the two disagree (the site claims `check_first`
defaults to `false`; the schema says `true`).

## Audit procedure

Run these first. They find most real defects without reading the file closely.

```sh
# 1. Does it even evaluate? Silent failure mode — hk skips a broken config.
pkl eval hk.pkl >/dev/null

# 2. What version is pinned, and what is current?
grep -o 'hk@[0-9.]*' hk.pkl | head -1
curl -sL https://api.github.com/repos/jdx/hk/releases/latest | grep '"tag_name"'

# 3. Do the steps actually run?
hk check --all
```

Then check each item in Rules below.

## Rules

### 1. Pin the version as a literal, three times

`amends` and `import` must be the first members of the module and cannot
interpolate. Hoisting a `local hk_version` above them to DRY the string is a
hard evaluation error (`Keyword 'amends' is not allowed here`), and hk then
fails to load the config:

```pkl
// WRONG — does not evaluate
local hk_version = "1.53.0"
amends "package://github.com/jdx/hk/releases/download/v\(hk_version)/hk@\(hk_version)#/Config.pkl"
```

Repeat the literal instead, and keep `min_hk_version` equal to it:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.53.0/hk@1.53.0#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v1.53.0/hk@1.53.0#/Builtins.pkl"

min_hk_version = "1.53.0"
```

Three literals is the accepted cost. On upgrade, change all three together.

### 2. Staging: delete `stage` globs on hk >= 1.33.0

This is the setting most often wrong, and it fails quietly in both directions.

Since **1.33.0** (PR #632), a step with a `fix` command and no `stage` key
defaults to `stage = "<JOB_FILES>"` — hk stages exactly the files that step
processed. That is the correct behavior, so write nothing:

```pkl
["trailing-whitespace"] = Builtins.trailing_whitespace   // fixes are staged
```

Two failure modes to fix during an audit:

- **Pinned below 1.33.0 with fix-only steps and no `stage`.** The fixes are
  applied to the working tree and never staged, so the commit records unfixed
  content. Upgrading the pin repairs it. This is the usual cause of "the hook
  ran but my commit still has the problem."
- **Pinned at or above 1.33.0 with an explicit `stage` glob.** Redundant, and
  broader than `<JOB_FILES>`: `stage = List("**/*.py")` stages unrelated `.py`
  files the step never touched, pulling unreviewed work into the commit. Drop
  the key.

Keep an explicit `stage` only when a fix writes files it was not given — a
codegen step whose inputs and outputs differ:

```pkl
["regenerate-types"] {
  glob = List("api/schema/**/*.py")
  check = null
  fix = "make gentypes"
  stage = List("dashboard/src/common/v1.ts")   // outputs, not job files
}
```

Related keys: hook-level `stage: Boolean` (default `true`, added 1.24.0) is the
master on/off switch; `stage` in `hk.pkl` overrides it. A `stage` without a
`fix` is a validation error.

### 3. Prefer builtins over hand-rolled shell steps

Builtins carry a `check_diff`, so `check_first` (default `true`) skips the write
entirely when a file is already clean — no write lock, no spurious mtime change.
Hand-rolled fix-only steps cannot do this, which is why they get worked around
with `check_first = false`.

Migrate `pre-commit-hooks` shell-outs to their builtin:

| Hand-rolled step | Builtin |
|---|---|
| `check-added-large-files` | `Builtins.check_added_large_files` |
| `check-merge-conflict` | `Builtins.check_merge_conflict` |
| `check-symlinks` | `Builtins.check_symlinks` |
| `check-yaml` | `Builtins.yamllint` |
| `end-of-file-fixer` | `Builtins.newlines` |
| `mixed-line-ending` | `Builtins.mixed_line_ending` |
| `trailing-whitespace-fixer` | `Builtins.trailing_whitespace` |
| `toml-sort` | `Builtins.taplo` or `Builtins.tombi` |
| `pkl eval ... >/dev/null` | `Builtins.pkl`, `Builtins.pkl_format` |
| detect private keys | `Builtins.detect_private_key` |

There are 140+ builtins; check `hk builtins` before writing a step by hand.
Override with parenthesized amend rather than copying the definition:

```pkl
["shellcheck"] = (Builtins.shellcheck) {
  check = "shellcheck --severity=warning {{ files }}"
}
["mixed-line-ending"] = (Builtins.mixed_line_ending) { exclude = List("tests/**") }
```

When a builtin resolves the wrong binary (global `ruff` instead of the project's
pinned one), override the command rather than abandoning the builtin — or set
`prefix = "mise exec --"` / `"uv run"`.

### 4. Define steps once, spread into hooks

Bind step mappings to `local` values and spread them. The four-hook shape below
is the default; `check` and `fix` back the `hk check` / `hk fix` commands.

```pkl
local linters = new Mapping<String, Step> { /* ... */ }
local slow_checks = new Mapping<String, Step> { /* tests, typecheck */ }

hooks {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = linters
  }
  ["pre-push"] { steps = new { ...slow_checks; ...linters } }
  ["commit-msg"] { steps = commit_msg_checks }
  ["fix"]   { fix = true; steps = linters }
  ["check"] { steps = new { ...slow_checks; ...linters } }
}
```

For repeated step shapes across directories, use a function; for shared `dir`,
`prefix`, `shell`, or `exclude`, use a `Group`, which children inherit:

```pkl
local function ruffStep(project: String) = new Step {
  glob = "**/*.py"
  dir = project
  batch = true
  check = "uv run --project \(project) ruff check {{files}}"
  fix = "uv run --project \(project) ruff check --fix {{files}}"
}

local services = List("api", "common", "workers")
local python = new Mapping<String, Step> {
  for (s in services) { ["ruff:\(s)"] = ruffStep(s) }
}
```

Keep step keys alphabetical within a mapping so additions stay reviewable.

### 5. Other settings worth setting

- `stash = "git"` on `pre-commit` when `fix = true`, so unstaged work is not
  mixed into fixes. `"patch-file"` preserves untracked files; `"none"` (the
  default) is wrong for a fixing hook.
- `types = List("text")` instead of a hand-maintained extension glob for
  whitespace and newline checks — it detects by extension, shebang, filename,
  and content.
- `exclude` at config level for generated or vendored trees.
- `batch = true` for per-file tools; `batch = false` for whole-project commands
  (`tsc --noEmit`, `pyright`) so one commit does not spawn duplicate full runs.
- `depends` to order a formatter after its linter, or any step after a
  dependency-sync step.
- `check = null` marks a step fix-only; hk skips it in check mode.
- Put slow whole-suite steps on `pre-push`, not `pre-commit`.

## Writing a new config

Start from the current release, builtins only, four hooks, no `stage` keys.
Add project-specific steps after `hk check --all` passes on the base.

Install with `hk install --mise` so hook execution resolves mise-managed tools.
Escape hatches to mention in a header comment: `HK=0` and `git ... --no-verify`.
