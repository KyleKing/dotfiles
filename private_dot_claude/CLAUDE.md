## General

- Avoid emojis

## Git

- ONLY USE git operations to READ; DO NOT stage NOR unstage; DO NOT commit NOR push

## Design Principles

- Favor a functional-style; write small- to medium-sized composable functions with a single responsibility
- Favor composition over inheritance

## Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: pathlib.Path, defaultdict, Literal[...], dataclass(frozen=True), StrEnum, pattern matching
- **Use walrus operator (:=):** `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- Do not lazy import; Do place imports at top of file
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

## Comments and Documentation

- NEVER add inline comments explaining what code does; code should be self-explanatory
- NEVER add docstrings to private/internal functions when self-explanatory
- Only add docstrings with args/returns/raises for public/exported functions
- Do not repeat type info in docstrings when type annotations exist
- Do not add numbered comments because they are difficult to maintain

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
