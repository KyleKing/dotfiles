#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Export what the user asked for in a Claude Code session transcript as markdown."""

import argparse
import json
import re
import sys
from pathlib import Path

PROJECTS = Path.home() / '.claude' / 'projects'


def find_transcript(target: str | None) -> Path:
    if target and Path(target).is_file():
        return Path(target)
    if target:
        hits = sorted(PROJECTS.glob(f"*/{target}*.jsonl"), key=lambda p: p.stat().st_mtime)
        if not hits:
            sys.exit(f"no transcript matches {target!r}")
        return hits[-1]
    project = PROJECTS / re.sub(r'[^A-Za-z0-9-]', '-', str(Path.cwd()))
    hits = sorted(project.glob('*.jsonl'), key=lambda p: p.stat().st_mtime)
    if not hits:
        sys.exit(f"no transcripts in {project}; pass a session id or path")
    return hits[-1]


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    return '\n'.join(b.get('text', '') for b in content if b.get('type') == 'text')


def is_human(entry: dict) -> bool:
    return entry.get('origin', {}).get('kind') == 'human'


def question_lines(result: dict) -> list[str]:
    answers = result.get('answers', {})
    notes = result.get('annotations', {})
    lines = []
    for q in result['questions']:
        text = q['question']
        options = ' | '.join(o['label'] for o in q['options'])
        lines.append(f"- Q: {text}\n  - options: {options}\n  - answer: {answers.get(text, '(none)')}")
        if note := notes.get(text, {}).get('notes'):
            lines.append(f"  - notes: {note}")
    return lines


def extract(path: Path) -> list[tuple[str, str, str]]:
    rows = []
    for raw in path.read_text().splitlines():
        entry = json.loads(raw)
        stamp = entry.get('timestamp', '')
        if entry.get('type') == 'user' and not entry.get('isSidechain'):
            result = entry.get('toolUseResult')
            if isinstance(result, dict) and 'answers' in result and 'questions' in result:
                rows.append((stamp, 'question-tool answer', '\n'.join(question_lines(result))))
            elif is_human(entry) and (body := text_of(entry['message']['content']).strip()):
                rows.append((stamp, 'message', body))
        elif entry.get('type') == 'attachment':
            att = entry['attachment']
            if att.get('type') == 'queued_command' and att.get('origin', {}).get('kind') == 'human':
                rows.append((att.get('timestamp', stamp), 'message (sent mid-turn)', att['prompt'].strip()))
    return rows


def render(path: Path, rows: list[tuple[str, str, str]]) -> str:
    out = [f"# User requests: {path.stem}", f"transcript: `{path}`", '']
    for i, (stamp, kind, body) in enumerate(rows, 1):
        out += [f"## {i}. {kind} ({stamp})", '', body, '']
    return '\n'.join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('session', nargs='?', help="session id (prefix ok) or transcript path; default is newest in this cwd's project")
    parser.add_argument('--output', '-o', help='write here instead of stdout')
    args = parser.parse_args()
    path = find_transcript(args.session)
    text = render(path, extract(path))
    if args.output:
        Path(args.output).write_text(text)
        print(args.output)
    else:
        print(text)


if __name__ == '__main__':
    main()
