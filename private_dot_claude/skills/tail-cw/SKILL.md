---
name: tail-cw
description: Read AWS CloudWatch logs, metrics, alarms, and X-Ray traces from the terminal using the local tail-cw checkout instead of an installed copy. Read this BEFORE running any `aws` CLI command, and whenever a task mentions logs, log groups, tailing or searching logs, CloudWatch, Logs Insights, an alarm, or an X-Ray trace. Skip only when the logs in question are not in CloudWatch (a local file, `git log`, `docker logs`, `journalctl`, another provider).
---

# tail-cw

Prefer this over the `aws` CLI for CloudWatch.
It caches every window it fetches as
Parquet, so re-filtering and repeat questions cost nothing, and it emits NDJSON that
pipes
into `jq` or Python.

## Run it

Always from the checkout, never a `brew` or `pip` copy:

```sh
uv run --project ~/Developer/kyleking/tail-cw tail-cw <args>
```

Works from any cwd. Inside the checkout, plain `uv run tail-cw` is equivalent.
Pick the
account with `--profile` (`read-prod`, `read-stage`, `read-devops`) or `AWS_PROFILE`.
`--demo` on `logs`, `tail`, and `dash` uses synthetic data and needs no credentials.

## Command map

| Need                               | Command                                                             |
| ---------------------------------- | ------------------------------------------------------------------- |
| Events for a window, as NDJSON     | `export logs <group> --start 2h [--filter '<expr>']`                |
| Live tail                          | `export tail <group> [--filter '<expr>']`                           |
| Which groups exist, with metadata  | `export groups '<glob>'`                                            |
| Rank recurring errors and warnings | `export summary '<glob>' --start 1h`                                |
| A real query (billed)              | `export insights '<glob>' --query '...' [--language sql\|ppl]`      |
| Alarms and how often they fired    | `export alarms [<prefix>] --history`                                |
| Metric datapoints                  | `export metrics --namespace AWS/ECS --metric CPUUtilization`        |
| X-Ray traces in a window           | `export xray --start 1h --expression 'service("api")'`              |
| One trace's spans, as OTLP         | `export xray-trace 1-<8hex>-<24hex>`                                |
| Cache size against its limit       | `cache status`                                                      |
| Interactive                        | `logs '<glob>' --start 2h` (`h` histogram, `p`/`x` pivots, `:xray`) |

`export logs` fetches the whole window and filters locally, so a second `--filter` over
the same window hits the cache and is free.

## Two surfaces bill, and both mislead

**Logs Insights** charges per GB scanned.
`export insights` prints a measured estimate
first and refuses above `[insights].confirm_above_gb` without `--yes`.
A `--language sql`
query names its own log groups in `FROM`, so no estimate is possible: it says so and
requires `--yes`.
A query that names its own sources (any SQL, or PPL with a `SOURCE`
clause) takes no log group arguments; PPL without one needs them, and gets an estimate.

**X-Ray** charges per trace *scanned*, and a filter expression does not reduce it —
`TracesProcessedCount` counts the traces it rejected.
Only a shorter window is cheaper.
`export xray` caps at 1,000 traces and prints what it spent.
An uncapped three-hour sweep
of a busy account scans ~440k traces.

Our services log a trace id as 32 bare hex digits (`6a89ad51596c…`) and X-Ray answers
only
to `1-6a89ad51-596c…`.
Same digits, dashes after the 1st and 9th.
The TUI's `x` pivot
converts for you; `export xray-trace` does not.

Reading logs (`export logs`, `tail`, `summary`, `groups`, `alarms`) is not billed per
GB.

## Filters

`ERROR`, `"exact phrase"`, `%regex%`, `level:error`, `status:>=500`, `user.id:*`,
combined
with `AND`, `OR`, `NOT`, and parentheses (uppercase keywords; a space means `AND`).
A bare
number compares numerically; quote it for a string.
Full reference:
`docs/docs/FILTER_GUIDE.md` in the checkout.

Live tail is the one path that sends the filter to AWS, and it refuses expressions
CloudWatch would answer wrongly rather than sending them.

## When tail-cw cannot do it

If the task plainly wants a CloudWatch capability tail-cw lacks:

1. Answer the question now with the `aws` CLI, and say that is what you did.
1. Add or update the entry in `plans/roadmap-2026-07.md` under `## Open`, with the
    evidence: the command you had to fall back to and what it returned.
1. Only make **small** fixes in passing — a wrong flag default, a misleading message, a
    missing field on a record, a crash.
    Those come with a test and the full gates.
1. Anything larger is a separate piece of work.
    Write it in the roadmap and stop; do not
    start it inside an unrelated task.

## Working in the checkout

`./run` and nox are broken; use these directly, and all four before reporting done:

```sh
uv run ruff check --fix --unsafe-fixes && uv run ruff format
uv run pytest -q -n auto     # ~8s; drop -n auto to use --pdb
uv run mypy && uv run pyright
```

`AGENTS.local.md` carries the hard-won rules (async, Textual, cache, X-Ray).
Read it
before changing anything in `tail_cw/`.
Two that bite hardest: a binding is not covered
until a test presses the key, and a screenshot or a real terminal finds what Pilot
cannot.

## Commit your own edits

Invoking this skill is authorization to commit in this repo.
Do it rather than leaving the
tree dirty, once the four gates above are green: one commit per coherent change, the
roadmap entry included.

Conventional Commits, a single readable subject line, no body unless the "why" is
genuinely
non-obvious from it.
Write it as the user would:

```
feat(xray): read traces from X-Ray, where the span hierarchy exists
fix(query): make a field search work across groups that lack the field
docs: record what the trace scan costs
```

Never reference the AI, the model, Claude, or Claude Code anywhere in a commit: no
`Co-Authored-By`, no session trailer, no "generated with" note.

Do not push, and do not stage or revert changes you did not make.
`investigations/` is
untracked on purpose and belongs to another repo, so exclude it:
`git add -A ':!investigations'`.

The pre-commit hooks reformat markdown and abort the commit when they do.
That is not a
failure: re-run the same `git add` and `git commit`, and the second one lands.
