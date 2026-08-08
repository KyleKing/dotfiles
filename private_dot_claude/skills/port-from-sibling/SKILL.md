---
name: port-from-sibling
description: Carry a config, pattern, or workflow from a sibling repository into this one. Use whenever a request references another local repo by relative path ("like ../calcipy", "see ../yak-shears/hk.pkl", "the way ../my-go-template does it"), or when migrating a project onto tooling another project already uses.
---

# Port from a sibling repo

The user keeps many small repos plus two copier templates (`calcipy_template` for
Python, `my_go_template` for Go) and propagates changes in both directions.
The reusable part of that work is the checklist, not the copying.

## Procedure

1. **Read the reference in full.** Not just the file named — its config, its lockfile pins,
    and any AGENTS.md, CLAUDE.md, or ADR that explains why it is shaped that way.
    Reading the file alone reproduces the shape and loses the reason.

1. **Diff against local.** State what already exists here, what conflicts, and what is
    genuinely missing.
    A migration usually turns out to be smaller than it looked.

1. **Adapt, do not copy.** The reference repo has a different name, language version,
    dependency set, and CI.
    Strip what is specific to it. A pasted config that names the wrong package is worse than
    none.

1. **Note where the two have deliberately diverged.** If local does something differently
    on purpose, say so and ask before overwriting it.
    Do not silently converge them.

1. **Run it.** The pre-commit hook, the lint step, the test suite — whatever the ported
    config claims to do.
    A config that evaluates is not a config that works.

## Push it back upstream

The step most often forgotten. When the change is a general improvement rather than
project-specific, it belongs in the template so every future project gets it:

- Python tooling changes go to `../calcipy_template/package_template`
- Go tooling changes go to `../my_go_template`
- Web app scaffolding goes to `../app-template`, with rendered output regenerated under
    `.ctt/`

Say explicitly whether the change should propagate upstream, and ask if it is not clear.
Do not commit to the template repo without being asked.

## Direction matters

Porting **template to project** is a `copier update` — use the `copier-template` skill
rather than hand-copying, so `.copier-answers.yml` stays truthful.

Porting **project to template** is manual, and needs the specifics generalized back into
`{{ }}` placeholders.

Porting **project to project** is the plain case this skill covers.
