"""Tests for utility functions."""

from datetime import datetime, timedelta, timezone

import pytest

from gh_orphaned_branches.utils import create_age_threshold, days_ago, paginate, parse_iso_date


# Pagination tests

def test_paginate_single_page():
    """Pagination returns all items when single page."""
    def fetch(page):
        return [1, 2, 3] if page == 1 else []
    assert paginate(fetch, per_page=100) == [1, 2, 3]


def test_paginate_multiple_pages():
    """Pagination combines items from multiple pages."""
    def fetch(page):
        if page == 1:
            return list(range(100))
        elif page == 2:
            return list(range(100, 150))
        return []
    assert len(paginate(fetch, per_page=100)) == 150


def test_paginate_with_max_pages():
    """Pagination respects max_pages limit."""
    def fetch(page):
        return list(range(page * 100, (page + 1) * 100))
    assert len(paginate(fetch, per_page=100, max_pages=2)) == 200


# Date parsing tests

@pytest.mark.parametrize("date_str,expected", [
    ("2024-01-15T10:30:00Z", (2024, 1, 15)),
    ("2024-01-15T10:30:00+00:00", (2024, 1, 15)),
    ("2023-12-31T23:59:59Z", (2023, 12, 31)),
])
def test_parse_iso_date(date_str, expected):
    """Parse ISO 8601 date strings correctly."""
    dt = parse_iso_date(date_str)
    assert (dt.year, dt.month, dt.day) == expected


def test_days_ago(fixed_datetime):
    """Calculate days between datetime and reference."""
    past = datetime(2024, 1, 25, tzinfo=timezone.utc)
    assert days_ago(past, reference=fixed_datetime) == 7


def test_create_age_threshold(fixed_datetime):
    """Create datetime threshold for age comparisons."""
    threshold = create_age_threshold(7, reference=fixed_datetime)
    expected = fixed_datetime - timedelta(days=7)
    assert threshold == expected
