# /// script
# requires-python = ">=3.11"
# dependencies = ["anthropic>=0.40.0"]
# ///

import argparse
import sys
from datetime import date
from pathlib import Path

import anthropic

_SYSTEM_PROMPT = """\
You summarize AI conversations into structured notes for human review. The reader may return days later
and needs to pick up cold — write as if they weren't in the session.

Output exactly this structure, with each section header as shown:

## Summary
2-4 sentences covering what was decided, built, or resolved. Lead with the outcome, not the process.

## Decisions and Outcomes
What was chosen and why. Each bullet names the decision and the reason behind it.
Omit this section if the conversation had no clear decisions.

## Context and Reasoning
Prose (not bullets) covering options considered, constraints, and tradeoffs. This is the "why"
behind the decisions — include it when the reasoning is non-obvious or would be lost otherwise.
Omit this section if there is nothing non-obvious to capture.

## Open Questions
Unresolved items, follow-ups, or things explicitly deferred. Omit if there are none.

## Links and References
File paths, URLs, or identifiers surfaced during the conversation that are relevant to the
decisions or follow-ups. Format each as:
- path/or/url — one phrase explaining why it matters
Omit if none were mentioned.

## Observations
Non-obvious things worth remembering: edge cases called out, patterns noted, risks flagged,
or anything that would surprise someone reading the code or docs without having been in the session.
Omit if there is nothing genuinely non-obvious.

Voice and formatting rules — apply to every section:
- Direct and action-oriented. Cut filler phrases like "it's worth noting", "importantly",
  "essentially", and "in summary"
- Name specific files, functions, decisions, and values rather than speaking in generalities
- Each bullet is a natural sentence. Do not start a bullet with a bolded lead-in phrase
  followed by a colon ("**Thing:** description" is forbidden)
- No trailing period at the end of a bullet item
- No em dashes or en dashes. Use parentheses for asides, and "because", "which", or "where"
  for relative clauses
- No semicolons joining independent clauses. Split into two sentences, or move a short aside
  into parentheses
- Prefer a short paragraph over a bare bulleted list when the content is discursive
- Omit sections that have nothing real to say. A section with placeholder content is worse
  than no section at all
"""


def _build_user_message(text: str) -> str:
    return f"<conversation>\n{text}\n</conversation>\n\nSummarize this conversation."


def _resolve_output_path(source: Path, output: Path | None) -> Path:
    if output:
        return output
    stem = source.stem.replace(' ', '-').lower()
    filename = f"{date.today()}-{stem}-summary.md"
    return Path.cwd() / filename


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Summarize a Claude.ai conversation export into structured notes.'
    )
    parser.add_argument('file', type=Path, help='Path to the conversation text file')
    parser.add_argument(
        '--model',
        default='claude-sonnet-4-6',
        help='Claude model ID (default: claude-sonnet-4-6)',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=None,
        help='Output path (default: <cwd>/<date>-<source-stem>-summary.md)',
    )
    parsed = parser.parse_args()

    source: Path = parsed.file
    if not source.exists():
        print(f"error: file not found: {source}", file=sys.stderr)
        sys.exit(1)

    text = source.read_text(encoding='utf-8')
    if not text.strip():
        print('error: file is empty', file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic()
    message = client.messages.create(
        model=parsed.model,
        max_tokens=4096,
        system=_SYSTEM_PROMPT,
        messages=[{'role': 'user', 'content': _build_user_message(text)}],
    )

    summary = message.content[0].text

    output_path = _resolve_output_path(source, parsed.output)
    output_path.write_text(summary, encoding='utf-8')
    print(output_path)


if __name__ == '__main__':
    main()
