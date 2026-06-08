## General

- Avoid emojis

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT commit NOR push

## Design Principles

- Favor a functional-style; write small- to medium-sized composable functions with a single responsibility
- Favor composition over inheritance
- When adding code to a list-like structure, try to insert in alphabetical order while minimizing diff. Do not re-sort existing unordered lists — only insert new items alphabetically.
  ```yaml
  services: [api, db, redis, web] # Good: alphabetical insertion of 'redis'
  services: [api, db, redis, zebra, web] # Good: ignoring unordered zebra for a minimal diff
  services: [api, db, web, redis] # Bad: append to end
  services: [api, db, redis, web, zebra] # Bad: re-sorting existing list to alphabetize
  ```
- Follow the charm/bubbletea design philosophy: minimal color usage, single unified background, borders provide visual hierarchy, and color is reserved for actionable elements (badges, accents)
- Favor required over optional inputs for Pulumi and similar configuration unless truly optional

## Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: pathlib.Path, defaultdict, Literal[...], dataclass(frozen=True), StrEnum
- Prefer Python stdlib (eg NEVER use Typer-always use argparser)
- **Use pattern matching when appropriate:** Prefer `match`/`case` for destructuring complex structures or 3+ branches; simple `if`/`elif` remains fine for 1-2 conditions or if if/else conditions are complex (even if 3 or more)
- **Use walrus operator (:=):** `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- NEVER lazy import; DO place imports at top of file
- Only use `__all__` in `__init__.py`; DO refactor circular imports instead
- **Multiline strings:** Use `textwrap.dedent()` for readability, not implicit parenthesized string concatenation
  ```python
  # Good: dedent with trailing backslash, no .strip()
  msg = dedent("""\
      line 1
      line 2""")

  # Bad: implicit concatenation
  msg = ("line 1" "line 2")
  ```
## Code Changes

- When fixing bugs or making changes, limit modifications to what's necessary for the fix
- Do not "improve" or refactor adjacent code unless explicitly requested
- Do not add documentation, type hints, or tests to unmodified functions in the same file

## Mermaid Diagrams

- Keep each diagram under ~15 nodes; group related items into a single node with line breaks rather than enumerating individually
- Use the correct C4 diagram type: System Landscape (ecosystem), C1 Context (black box), C2 Container (services), C3 Component (internals of one container), Deployment (infrastructure mapping), Dynamic (sequence/flow)
- Prefer `flowchart` over `graph` for decision trees; use `sequenceDiagram` for request/failure flows
- Put detail in reference tables below the diagram, not in node labels

## Comments and Documentation

- NEVER add inline comments explaining what code does; code should be self-explanatory
- NEVER add docstrings to private/internal functions when self-explanatory
- Only add docstrings with args/returns/raises for public/exported functions
- Do not repeat type info in docstrings when type annotations exist
- Do not add numbered comments because they are difficult to maintain
- NEVER use numpy-style docstring sections (Parameters/Returns/Examples with dashed underlines)
- Docstrings should be one line when the function signature is self-explanatory
- When modifying files, do NOT add or update docstrings for functions you didn't change
- Prefer documenting non-obvious behavior (e.g., "Do not reuse after calling") over restating types

## Error Handling

- Let exceptions propagate unless you can handle them meaningfully
- Prefer specific exception types over bare `except:` and use 'err' instead of 'e' (eg `except Exception as err:` instead of `as e:`)
- Use custom exceptions for domain-specific errors
- Validate at system boundaries (user input, external APIs), trust internal code, follow parse-don't-validate

## Tools

- Do not run Docker commands without instruction
- If `./uv.lock`, use uv; if `./poetry.lock`, use poetry; if `./tox`, use tox when executing Python

## Tone and Voice

- **Direct & Action-Oriented**: Use clear, concise language focused on what was done or needs to be done
- **Technical Precision**: Be specific about implementation details and technical decisions
- **Organized Structure**: Use bullet points, sections, and a hierarchy
- **Professional but Personable**: Professional tone with genuine warmth (e.g., "I'm excited to see this implemented!")
- **No Filler**: Avoid unnecessary commentary—let the technical content speak
- Communication Patterns
    - **PR Descriptions:** Lead with summary, use bullet points, explain why not just what
    - **Code Reviews:** Be direct but constructive, focus on technical merit
    - **Comments:** If you must explain, be concise
- In tone, avoid: excessive enthusiasm, vague language, filler words
