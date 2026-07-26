# Authoring a copier template

Reference: https://copier.readthedocs.io/en/stable/configuring/

## Local dev loop

From the template repo. The commit is needed because copier reads the template
through git:

```sh
git add . && git commit -m "tmp"
copier . ../test_template --UNSAFE --conflict=rej --vcs-ref=HEAD
cd ../test_template
copier update . --UNSAFE --conflict=rej --defaults
```

Each template also carries a `sync_with_ctt.sh` that copies generated `.ctt/default/*`
files back up to the template repo's own root config, so the template repo dogfoods
its own output.

## Testing with ctt

Docs: https://github.com/KyleKing/copier-template-tester

ctt only exercises `copier copy`. It does **not** test `update` or version-specific
logic, so a green ctt run says nothing about whether an update works.

```toml
[defaults]
project_name = "placeholder"

[output.".ctt/defaults"]

[output.".ctt/no_all"]
include_all = false
```

Hooks: `_pre_tasks`, `_post_tasks` (preferred over the older `_extra_tasks`),
`_skip_tasks`. Usable in `[defaults]` or per-output.

```sh
ctt --list          # discover case keys
ctt -t no_all       # run matching cases, repeatable
```

The real assertion is in CI, because rendered output is committed:

```yaml
- run: uvx --from copier-template-tester ctt --continue-on-error
- run: git diff --exit-code -- .ctt
```

ctt imports copier private APIs (`copier._template.load_template_config`, `Worker`),
deprecated since copier 9.11.0. Check the installed copier version before debugging
a ctt failure.

Historical hazard worth remembering: running ctt as a pre-commit hook against a
dirty local template once corrupted the repository index and object store, because
copier's `Worker(vcs_ref="HEAD")` staged the live work tree into a throwaway git-dir
mid-commit. ctt now snapshots via `git stash create` plus `git archive` into a
tempdir so copier sees a non-git source.

## Settings in use

`_min_copier_version: 9.0.0`, `_answers_file`, `_subdirectory`, `_skip_if_exists`,
`_tasks`, `_message_after_copy`.

`_exclude` set in `copier.yml` **replaces** the built-in defaults (`copier.yml`,
`~*`, `*.py[co]`, `__pycache__`, `.git`, `.DS_Store`, `.svn`); the CLI `-x` flag
extends them instead. Forgetting `.git` there lets copier walk into the git
directory.

`_templates_suffix` defaults to `.jinja`. A `README.md` sitting next to
`README.md.jinja` is silently ignored.

Handy: `_exclude` accepts Jinja, so
`"{% if _copier_operation == 'update' %}src/*_example.py{% endif %}"` renders a file
on first copy and never touches it again on update.

## Migrations — the open improvement

These templates use **no `_migrations`**. Version-to-version fixups are hand-rolled
Python scripts inside `_tasks` that self-detect and self-delete. That is the source
of a recurring bug class ("the migration file isn't being deleted after running, may
not be running, or may be erroring"), because `_tasks` run on *every* copy and
update with no version context.

`_migrations` is the mechanism built for this. It runs only on update, never on first
copy, and receives the version range:

```yaml
_migrations:
  - version: v1.0.0
    command: rm ./old-folder
    when: "{{ _stage == 'before' }}"
```

Keys: `command`, `version` (optional, PEP 440), `when` (optional — the default stage
is *after* upgrade), `working_directory`. With `version`, a migration fires only when
new >= declared > old.

Available vars: `_stage` / `$STAGE` (`before` or `after`), `_version_from`,
`_version_to`, `_version_current`, plus PEP 440-normalized `_version_pep440_*` and
`$VERSION_PEP440_*`. Compare with the PEP 440 forms.

Migrations require copier >= 9.3.0 and force the template to be treated as unsafe.
`-T/--skip-tasks` skips tasks but **not** migrations.

Raise this as a suggestion when touching migration logic. Do not rewrite an existing
`_tasks` script into `_migrations` without asking — it changes when the code runs.

## Questions

`type` is one of bool, float, int, json, path, str, yaml (default yaml). Plus `help`,
`default`, `choices` (templatable), `multiselect`, `validator` (Jinja — a non-empty
render means invalid and the rendered string is the error message), `when`, `secret`,
`placeholder`, `multiline`.

Answers to `secret: true` questions are not written to the answers file, so they are
re-prompted on every update.
