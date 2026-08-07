---

## name: summarize-chat description: Summarize a Claude.ai conversation export into structured human-readable notes. Use when the user has a saved conversation text file and wants a dated summary .md file written to the current directory.

# summarize-chat

Runs `summarize_chat.py` against a conversation text file and writes a dated summary
markdown file to the current working directory.

## Prerequisites

`ANTHROPIC_API_KEY` must be set. The script uses `uv run` with inline dependencies, so
no manual install step is needed beyond having `uv` available.

## Usage

```bash
uv run ~/.claude/skills/summarize-chat/summarize_chat.py <file>
```

Optional flags:

- `--model <id>` — override the Claude model (default: `claude-sonnet-4-6`)
- `--output <path>` — write to a specific path instead of the auto-named default

## Output

The script prints the output path on success.
The default filename is:

```
<cwd>/<YYYY-MM-DD>-<source-stem>-summary.md
```

For example, running against `chat-776d8ae5.txt` on 2026-06-30 produces:

```
<cwd>/2026-06-30-chat-776d8ae5-summary.md
```

## Output structure

```
## Summary
## Decisions and Outcomes
## Context and Reasoning
## Open Questions
## Links and References
## Observations
```

Sections with nothing real to say are omitted from the output.

## How to invoke as a skill

When the user runs `/summarize-chat` with a file path argument, run:

```bash
uv run ~/.claude/skills/summarize-chat/summarize_chat.py "<file-path>"
```

Print the output path on completion and offer to open the file.
