# Python Style

- Prefer Pydantic, dataclasses, then dictionaries
- Use modern Python: pathlib.Path, defaultdict, Literal[...], dataclass(frozen=True), StrEnum, pattern matching
- **Use walrus operator (:=):** `if (m := re.search(...)):` or `while (line := f.readline()):`
- Prefix functions with underscore if only used within a file
- Do not lazy import—place imports at top of file
- Only use `__all__` in `__init__.py`; refactor circular imports instead

# Comments and Documentation

- NEVER add inline comments explaining what code does—code should be self-explanatory
- NEVER add docstrings to private/internal functions
- Only add docstrings with args/returns/raises for public/exported functions
- Do not repeat type info in docstrings when type annotations exist

# Git and Tools

- ONLY USE git operations to READ; NEVER modify staged files or commit
- Do not run Docker commands without instruction
- Use uv (./uv.lock), poetry (./poetry.lock), or tox (./tox) to execute Python
- Use fd instead of find; use rg instead of grep

# Batch Changes: fd/sad vs GritQL

**fd + sad (text-based, fast):** Simple string/name replacements
```bash
fd --glob="*.py" | sad --pager=never --commit --exact 'old' 'new'
fd --glob="*.rs" --hidden | sad --pager=never --commit --regex 'pattern' 'replace'
```

**GritQL (syntax-aware, precise):** Use for code refactoring that understands structure
- Rename functions/variables with proper scope
- Change signatures, update imports
- Pattern-based migrations
- Dry-run: `grit apply pattern.gql` | Apply: `grit apply --fix pattern.gql`

### GritQL Syntax (Essential)

| Pattern | Meaning |
|---------|---------|
| `` `code_snippet` `` | Match this syntax |
| `$var` | Capture and reuse |
| `$_` | Match anything (unnamed) |
| `pattern => replacement` | Transform matched code |
| `pattern => .` | Delete matched code |
| `` or { `a`, `b` } `` | Match pattern a OR b |
| `pattern where { $x <: "text" }` | Match with condition |
| `contains`, `within`, `after` | Navigate syntax tree |

### Common GritQL Patterns

```gql
# Rename function
`old_name` => `new_name`

# Change function call
`deprecated_fn($args)` => `new_fn($args)`

# Update import
`from old_module import $x` => `from new_module import $x`

# Remove calls
`console.log($_)` => .

# Match multiple patterns
or {
  `old_fn()`,
  `legacy_fn()`
} => `new_fn()`
```
