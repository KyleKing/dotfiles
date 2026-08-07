# hk.pkl reference

Read this for broader changes: debugging a step that will not run, migrating hand-rolled
steps to builtins, restructuring hooks, or writing a config from scratch.
The audit procedure and the two highest-frequency rules are in [SKILL.md](SKILL.md).

## Debugging and validating a config

Before running steps for real, ask hk what it *would* do:

```sh
# Which steps would run, and why each was included or skipped
hk check --plan
hk check --why              # same as --plan, plus the skip/include reason per step
hk check --why <step>       # focus on one step
hk check --plan --json      # machine-readable plan, for scripting or diffing
```

`--why` implies `--plan` — neither one executes a step.
Reasons include things like `filter_no_match` (glob/exclude/type didn't match any
changed file), `disabled via HK_SKIP_STEPS`, or a failed `condition`.
Use this instead of adding temporary `echo` debugging to a step's `check`/`fix` command.

### Timing and tracing

- `--trace` (or `HK_TRACE=1` / `HK_TRACE=text`) prints a hierarchical span tree with
    per-step timing to the console.
- `HK_TRACE=json` (or `--trace --json`) emits newline-delimited JSON spans instead, for
    feeding into other tooling.
- `HK_TIMING_JSON=/path/to/file.json` writes a summary report (total wall time, per-step
    wall time with overlapping intervals merged, and which profiles each step ran under)
    without the verbosity of `--trace`.
- `HK_LOG=debug` / `HK_LOG=trace` (or `-v` / `-vv`) control general log verbosity,
    independent of `--trace`; `HK_LOG_FILE` / `HK_LOG_FILE_LEVEL` redirect and re-level the
    log file hk always writes to `~/.local/state/hk/hk.log`.

Reach for `--plan`/`--why` when a step isn't running or isn't skipping when expected;
reach for `--trace`/`HK_TIMING_JSON` when steps run but are slow.

## Version pinning in detail

`amends` and `import` must be the first members of the module and cannot interpolate.
Hoisting a `local hk_version` above them to DRY the string is a hard evaluation error
(`Keyword 'amends' is not allowed here`), and hk then fails to load the config:

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

## Staging in detail

Since **1.33.0** (PR #632), a step with a `fix` command and no `stage` key defaults to
`stage = "<JOB_FILES>"` — hk stages exactly the files that step processed.
That is the correct behavior, so write nothing:

```pkl
["trailing-whitespace"] = Builtins.trailing_whitespace   // fixes are staged
```

Two failure modes to fix during an audit:

- **Pinned below 1.33.0 with fix-only steps and no `stage`.** The fixes are applied to the
    working tree and never staged, so the commit records unfixed content.
    Upgrading the pin repairs it. This is the usual cause of "the hook ran but my commit
    still has the problem."
- **Pinned at or above 1.33.0 with an explicit `stage` glob.** Redundant, and broader than
    `<JOB_FILES>`: `stage = List("**/*.py")` stages unrelated `.py` files the step never
    touched, pulling unreviewed work into the commit.
    Drop the key.

Keep an explicit `stage` only when a fix writes files it was not given — a codegen step
whose inputs and outputs differ:

```pkl
["regenerate-types"] {
  glob = List("api/schema/**/*.py")
  check = null
  fix = "make gentypes"
  stage = List("dashboard/src/common/v1.ts")   // outputs, not job files
}
```

Related keys: hook-level `stage: Boolean` (default `true`, added 1.24.0) is the master
on/off switch; `stage` in `hk.pkl` overrides it.
A `stage` without a `fix` is a validation error.

## Prefer builtins over hand-rolled shell steps

Builtins carry a `check_diff`, so `check_first` (default `true`) skips the write
entirely when a file is already clean — no write lock, no spurious mtime change.
Hand-rolled fix-only steps cannot do this, which is why they get worked around with
`check_first = false`.

Migrate `pre-commit-hooks` shell-outs to their builtin:

| Hand-rolled step            | Builtin                               |
| --------------------------- | ------------------------------------- |
| `check-added-large-files`   | `Builtins.check_added_large_files`    |
| `check-merge-conflict`      | `Builtins.check_merge_conflict`       |
| `check-symlinks`            | `Builtins.check_symlinks`             |
| `check-yaml`                | `Builtins.yamllint`                   |
| `end-of-file-fixer`         | `Builtins.newlines`                   |
| `mixed-line-ending`         | `Builtins.mixed_line_ending`          |
| `trailing-whitespace-fixer` | `Builtins.trailing_whitespace`        |
| `toml-sort`                 | `Builtins.taplo` or `Builtins.tombi`  |
| `pkl eval ... >/dev/null`   | `Builtins.pkl`, `Builtins.pkl_format` |
| detect private keys         | `Builtins.detect_private_key`         |

There are 140+ builtins; check `hk builtins` before writing a step by hand.
Override with parenthesized amend rather than copying the definition:

```pkl
["shellcheck"] = (Builtins.shellcheck) {
  check = "shellcheck --severity=warning {{ files }}"
}
["mixed-line-ending"] = (Builtins.mixed_line_ending) { exclude = List("tests/**") }
```

When a builtin resolves the wrong binary (global `ruff` instead of the project's pinned
one), override the command rather than abandoning the builtin — or set
`prefix = "mise exec --"` / `"uv run"`.

## Define steps once, spread into hooks

Bind step mappings to `local` values and spread them.
The four-hook shape below is the default; `check` and `fix` back the `hk check` /
`hk fix` commands.

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

For repeated step shapes across directories, use a function; for shared `dir`, `prefix`,
`shell`, or `exclude`, use a `Group`, which children inherit:

```pkl
local function ruffStep(project: String) = new Step {
  glob = "**/*.py"     // matched relative to `dir`, not repo root
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

## Other settings worth setting

- `stash = "git"` on `pre-commit` when `fix = true`, so unstaged work is not mixed into
    fixes.
    `"patch-file"` preserves untracked files; `"none"` (the default) is wrong for a fixing
    hook.
- `types = List("text")` instead of a hand-maintained extension glob for whitespace and
    newline checks — it detects by extension, shebang, filename, and content.
- `exclude` at config level for generated or vendored trees.
- `batch = true` for per-file tools; `batch = false` for whole-project commands
    (`tsc --noEmit`, `pyright`) so one commit does not spawn duplicate full runs.
- `depends` to order a formatter after its linter, or any step after a dependency-sync
    step.
- `check = null` marks a step fix-only; hk skips it in check mode.
- Put slow whole-suite steps on `pre-push`, not `pre-commit`.

## Skip a hook for one command (e.g. a merge)

hk has no separate `pre-merge-commit` hook, and neither does the config need one: git
only calls `pre-merge-commit` for a merge commit, but it falls back to `pre-commit` when
`pre-merge-commit` isn't installed, and hk installs only `pre-commit`.
So a merge commit runs the same `pre-commit` hook as a normal `git commit` — there's no
separate label to target one and not the other.

To skip hk for a merge without disabling `pre-commit` for regular commits afterward,
scope `HK_SKIP_HOOK` to that single invocation instead of exporting it:

```sh
HK_SKIP_HOOK=pre-commit git merge --no-ff feature-branch
```

Prefixing the variable keeps the skip local to that one command; a later plain
`git commit` in the same shell still runs `pre-commit` normally.
`skip_hooks` (config: `HK_SKIP_HOOK` / `HK_SKIP_HOOKS`, git config `hk.skipHook`, or
`skip_hooks` in `.hkrc.pkl`) skips the entire hook and every step in it — for skipping
one step instead, use `skip_steps` / `HK_SKIP_STEPS`.

## Writing a new config

Start from the current release, builtins only, four hooks, no `stage` keys.
Add project-specific steps after `hk check --all` passes on the base.

Install with `hk install --mise` so hook execution resolves mise-managed tools.
Escape hatches to mention in a header comment: `HK=0` and `git ... --no-verify`.
