## General

- Avoid emojis

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT commit NOR push

## Design Principles

- Favor functional-style: small, composable, single-responsibility functions
- Favor composition over inheritance
- Insert new items alphabetically into list-like structures; don't re-sort existing unordered lists

## Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: `pathlib.Path`, `defaultdict`, `Literal[...]`, `dataclass(frozen=True)`, `StrEnum`
- Prefer Python stdlib (e.g. argparse, not Typer)
- Pattern matching: `match`/`case` for destructuring or 3+ branches; `if`/`elif` fine for 1-2 conditions or complex predicates
- Walrus operator: `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- Never lazy import; all imports at top of file
- `__all__` only in `__init__.py`; refactor circular imports instead
- Multiline strings: use `textwrap.dedent()`, not implicit parenthesized string concatenation

## Code Changes

- Limit modifications to what's necessary; don't refactor adjacent code or add docs/types/tests to unmodified functions

## Mermaid Diagrams

- Keep diagrams under ~15 nodes; group related items rather than enumerating individually
- Use the correct C4 type: System Landscape, C1 Context, C2 Container, C3 Component, Deployment, Dynamic
- `flowchart` for decision trees; `sequenceDiagram` for request/failure flows
- Put detail in reference tables below the diagram, not in node labels

## Comments and Documentation

- No inline comments; code should be self-explanatory
- No docstrings on private/internal self-explanatory functions
- Public API: one-line docstring when signature is clear; include args/returns/raises only when non-obvious; no type repetition; no numpy-style sections; no numbered comments
- Document non-obvious behavior (e.g. "Do not reuse after calling"), not types
- Don't add or update docstrings for functions you didn't change

## Error Handling

- Let exceptions propagate unless you can handle them meaningfully
- Specific exception types; use `err` not `e` (e.g. `except Exception as err:`)
- Use custom exceptions for domain-specific errors
- Validate at system boundaries; trust internal code; parse-don't-validate

## Tools

- Do not run Docker commands without instruction
- Python package manager: uv if `uv.lock`, poetry if `poetry.lock`, tox if `./tox`

## Tone and Voice

- Direct and action-oriented; no filler, no excessive enthusiasm, no vague language
- Technical precision: specific about implementation details and decisions
- Organized: bullet points, sections, hierarchy
- PR descriptions: summary first, bullets, explain why not just what
