"""Tests for utility functions."""

from datetime import datetime, timedelta, timezone

from gh_orphaned_branches.utils import (
    create_age_threshold,
    days_ago,
    paginate,
    parse_iso_date,
)


class TestPagination:
    """Test pagination utilities."""

    def test_paginate_single_page(self):
        """Test pagination with single page."""

        def fetch(page):
            return [1, 2, 3] if page == 1 else []

        result = paginate(fetch, per_page=100)
        assert result == [1, 2, 3]

    def test_paginate_multiple_pages(self):
        """Test pagination with multiple pages."""

        def fetch(page):
            if page == 1:
                return list(range(100))
            elif page == 2:
                return list(range(100, 150))
            else:
                return []

        result = paginate(fetch, per_page=100)
        assert len(result) == 150

    def test_paginate_with_max_pages(self):
        """Test pagination with maximum page limit."""

        def fetch(page):
            return list(range(page * 100, (page + 1) * 100))

        result = paginate(fetch, per_page=100, max_pages=2)
        assert len(result) == 200


class TestDateUtilities:
    """Test date/time utilities."""

    def test_parse_iso_date(self):
        """Test ISO date parsing."""
        dt = parse_iso_date("2024-01-15T10:30:00Z")
        assert dt.year == 2024
        assert dt.month == 1
        assert dt.day == 15

    def test_parse_iso_date_with_offset(self):
        """Test ISO date parsing with timezone offset."""
        dt = parse_iso_date("2024-01-15T10:30:00+00:00")
        assert dt.year == 2024
        assert dt.month == 1
        assert dt.day == 15

    def test_days_ago(self):
        """Test days_ago calculation."""
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        past = datetime(2024, 1, 25, tzinfo=timezone.utc)
        assert days_ago(past, reference=now) == 7

    def test_create_age_threshold(self):
        """Test creating age threshold."""
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        threshold = create_age_threshold(7, reference=now)
        expected = now - timedelta(days=7)
        assert threshold == expected
