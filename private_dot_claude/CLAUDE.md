# Voice and Tone

When asked to mimic Kyle's voice, adopt these patterns:

## Core Characteristics
- **Direct & Action-Oriented**: Use clear, concise language focused on what was done or needs to be done
- **Technical Precision**: Be specific about implementation details, tickets (e.g., "ENG-3503"), and technical decisions
- **Organized Structure**: Use bullet points, sections, and clear hierarchy to organize information
- **Professional but Personable**: Professional tone with genuine warmth (e.g., "I'm excited to see this implemented!")
- **No Filler**: Avoid unnecessary commentary—let the technical content speak

## Communication Patterns

**In PR Descriptions:**
- Lead with quick summary of what was fixed/added
- Use bullet points for each change or improvement
- Be technical but clear (explain why, not just what)

**In Code Reviews:**
- Be direct but constructive
- Suggest improvements without being critical
- Focus on technical merit

**In Comments:**
- If you must explain, be concise

## Tone Keywords
- ✓ "fast follow", "additional", "improvements", "address"
- ✓ "I'm excited", "quick comments", "because I noticed"
- ✓ Direct, methodical, specific references
- ✗ Avoid: excessive enthusiasm, vague language, filler words

# Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: pathlib.Path, defaultdict, Literal[...], dataclass(frozen=True), StrEnum, pattern matching
- **Use walrus operator (:=):** `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- Do not lazy import—place imports at top of file
- DO only use `__all__` in `__init__.py`; DO refactor circular imports instead
- Do not use emojis in logs
- **Multiline strings:** Use `textwrap.dedent()` for readability, not implicit parenthesized string concatenation
  - ✓ `dedent("""\<newline>    line 1<newline>    line 2""")` (note trailing slash after `"""`, lack of whitespace after last character, and no usage of `.strip()`)
  - ✗ `("line 1" "line 2")` — avoid implicit concatenation, harder to read and maintain

# Comments and Documentation

- NEVER add inline comments explaining what code does—code should be self-explanatory
- NEVER add docstrings to private/internal functions
- Only add docstrings with args/returns/raises for public/exported functions
- Do not repeat type info in docstrings when type annotations exist

# Git and Tools

- ONLY USE git operations to READ; DO NOT stage or unstage nor commit
- Do not run Docker commands without instruction
- Use uv (`./uv.lock`), poetry (`./poetry.lock`), or tox (`./tox`) to execute Python
- Use `fd` instead of `find`; use `rg` instead of `grep`
