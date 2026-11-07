"""Unit tests for ai-gh-pr.py's stack linking."""

import importlib.util
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location('ai_gh_pr', Path(__file__).parent / 'ai-gh-pr.py')
ai_gh_pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai_gh_pr)

PRS = {'feat/base': 2663, 'feat/new': 2665}


def fake_gh(stack, calls):
    def run_json(*cmd):
        if cmd[:3] == ('gh', 'pr', 'list'):
            branch = cmd[cmd.index('--head') + 1]
            return [{'number': PRS[branch], 'headRefName': branch}]
        return {'stack': stack}

    def run_process(cmd, **_):
        calls.append(cmd)
        return type('Result', (), {'returncode': 0, 'stdout': '', 'stderr': ''})()

    return run_json, run_process


@pytest.mark.parametrize(
    ('stack', 'expected'),
    [({'number': 2664, 'position': 2, 'size': 5}, ['2664', '2665']), (None, ['2663', '2665'])],
)
def test_link_stack_uses_pr_numbers_and_prefers_the_stack_number(monkeypatch, stack, expected):
    calls = []
    run_json, run_process = fake_gh(stack, calls)
    monkeypatch.setattr(ai_gh_pr, 'run_json', run_json)
    monkeypatch.setattr(ai_gh_pr.subprocess, 'run', run_process)

    ai_gh_pr._link_stack('feat/base', 'feat/new')

    assert calls == [['gh', 'stack', 'link', *expected]]


def test_pr_pass_blockers_stay_outside_the_summary():
    head, written, footer = ai_gh_pr._split_description(
        '<!-- pr-pass:blockers -->\n- decide y\n<!-- /pr-pass:blockers -->\n\n'
        'AI Summary: x\n<!-- codesmith:footer -->\nfoot'
    )
    assert head.startswith('<!-- pr-pass:blockers -->')
    assert written == 'AI Summary: x'
    assert ai_gh_pr._ai_owned(written)
    assert footer.startswith('<!-- codesmith:footer -->')
