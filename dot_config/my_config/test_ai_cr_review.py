"""Unit tests for ai-cr-review.py's checkbox sources and the `tick` body rewrite."""

import importlib.util
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location('ai_cr_review', Path(__file__).parent / 'executable_ai-cr-review.py')
ai_cr_review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai_cr_review)

DESCRIPTION_BODY = (
    'Intro text.\n\n- [ ] Decision A\n- [x] Already done\n\n'
    '```\n- [ ] fenced, not a real box\n```\n\n- [ ] Decision B\n'
)
SUMMARY_BODY = 'AI Summary:\n\n- [ ] Decision A\n- [ ] Decision B\n'


def test_description_checkboxes_skips_fenced_and_checked_boxes():
    pr = {'body': DESCRIPTION_BODY, 'url': 'https://github.com/o/r/pull/1'}
    boxes = ai_cr_review.description_checkboxes(pr)
    assert [b['text'] for b in boxes] == ['Decision A', 'Decision B']
    assert {b['source'] for b in boxes} == {'description'}
    assert all(b['url'] == pr['url'] for b in boxes)


@pytest.mark.parametrize('body', [DESCRIPTION_BODY, SUMMARY_BODY], ids=['description', 'summary'])
def test_ticked_body_flips_only_the_named_box(body):
    before, after = body.splitlines(), ai_cr_review.ticked_body(body, {'Decision A'}).splitlines()
    assert after == [line.replace('[ ] Decision A', '[x] Decision A') for line in before]


@pytest.mark.parametrize(('open_texts', 'expect_error'), [
    (['Decision A'], False),
    ([], True),
    (['Decision A', 'Decision A'], True),
])
def test_validate_ticks_requires_exactly_one_match_across_sources(open_texts, expect_error):
    errors = ai_cr_review.validate_ticks(
        [{'text': 'Decision A', 'how': 'auto', 'note': 'verified on main'}], open_texts)
    assert bool(errors) == expect_error


def test_tick_report_names_each_touched_location():
    ticks = [{'text': 'Decision A', 'how': 'auto', 'note': 'verified'}]
    report = ai_cr_review.tick_report(
        ticks, [('description', 'https://x/pull/1'), ('AI Summary', 'https://x/issues/comments/9')])
    assert '[description](https://x/pull/1)' in report
    assert '[AI Summary](https://x/issues/comments/9)' in report
