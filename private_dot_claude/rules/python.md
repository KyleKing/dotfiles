---
paths:
  - '**/*.py'
  - '**/*.pyi'
  - '**/pyproject.toml'
---

# Python

Async work has its own rules with real failure modes behind them.
Load the
`python-async` skill before writing or reviewing `async def`, `await`,
`asyncio.to_thread`, or any executor code.

## Structure

Functions over classes. Default to pure functions for data transforms and business
logic, keep side effects at the edges (I/O, environment), and pass dependencies as
parameters rather than reaching for globals.

Depend on a `Protocol` rather than a concrete type so tests can wire a fake.

Prefix functions with an underscore if they are only used within one file.

`__all__` only in `__init__.py`. Refactor circular imports instead of working around
them.
Never lazy import; all imports at the top of the file.

## Data

Prefer Pydantic, then dataclasses, then dictionaries.
Pass validated Pydantic models
through application and domain logic; expose dicts only where reading from or
writing to the database.

Avoid a bare `object` type, which validates nothing.
Name the concrete model.

Reach for the right stdlib structure: `collections.deque` for FIFO, LRU, and log
tails; `heapq` for top-N; `bisect` for sorted inserts; `array` and `memoryview` for
large numeric buffers.

Distinguish an omitted field from an explicit null in update payloads with a
sentinel (`CLEAR_TO_NULL`) rather than conflating them.

Prefer `@computed_field` with `@property` for a derived or response field over
`model_validator(mode="after")` when the value comes from other model fields.
Simpler, no mutation, same serialization.

## Modern Python

Use `pathlib.Path`, `defaultdict`, `Literal[...]`, `dataclass(frozen=True)`,
`StrEnum`.

Import callables and iterables from `collections.abc`, not `typing`.
Same for
`dict`, `list`, and `X | None` over `typing.Dict`, `typing.List`,
`typing.Optional`.

Put `from __future__ import annotations` first and guard type-only imports behind
`if TYPE_CHECKING:` so forward references need no quoting.
One known exception: a
framework that validates types at runtime (Dagster) breaks on it.

Pattern matching: `match`/`case` for destructuring or three or more branches.
`if`/`elif` is fine for one or two conditions, or for complex predicates.

Walrus where it reads well: `if (m := re.search(...)):`,
`while (line := f.readline()):`.

Make boolean parameters keyword-only in helpers and fixtures.
It reads better and
avoids Ruff's FBT warnings.

Wrap multi-line ternaries in parentheses rather than using a backslash continuation:
`value = (some_transform(x) if condition else None)`.

Use `timedelta` arithmetic rather than `datetime.replace` when synthesizing
datetimes, so the result stays in a valid range.

Multiline strings use `textwrap.dedent()`, never implicit parenthesized string
concatenation.

Prefer the stdlib (argparse, not Typer).

## Errors

Let exceptions propagate unless you can handle them meaningfully.

Catch specific exception types and name the variable `err`, not `e`:
`except Exception as err:`.

Use custom exceptions for domain-specific errors.

Validate at system boundaries, trust internal code, parse rather than validate.

One `try` equals one failure mode. Do not wrap success-path side effects (dispatch,
notify, commit) in the same `try` as the failure handler — a downstream failure then
marks a completed operation as failed.

Reject speculative error tolerance. A best-effort skip-loop that swallows invalid
data hides integrity bugs.
Fail loud.

Fail fast on startup: crash immediately with a clear error when required
configuration, files, or connections are missing.
A loud failure during deployment
beats silent misbehavior in production.

A new config default must preserve existing behavior — a new cap or filter defaults
to a no-op.

Env flags typed as `int` bite: `bool(0)` is False, so set it to `1`, not `"0"`.

## Logging

Prefer structured fields over embedding values in the message string.
With
`structlog` pass fields as keyword arguments; with stdlib `logging` pass them via
`extra={...}`.

## Tests

Assert the specific exception subtype, not a base-class message.

`assertFalse(d.get(key))` passes when the key is absent.
Assert presence and
`is False` separately.

Watch module-level memoization (`lru_cache`, a `global`) leaking mutable state
across tests.
Raising `pytest -n` parallelism surfaces cross-test interference that
serial runs hide.

A new invariant guard is not done until you have confirmed it fails when the
invariant is broken.

## Tooling

Package manager follows the lockfile: uv if `uv.lock`, poetry if `poetry.lock`, tox
if `./tox`.

Ruff posture: `select = ['ALL']` with `preview = true`, then named ignores each
carrying a one-line rationale comment.
