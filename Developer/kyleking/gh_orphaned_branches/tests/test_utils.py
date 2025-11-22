"""Tests for utility functions."""

from datetime import datetime, timedelta, timezone

import pytest

from gh_orphaned_branches.utils import (
    compose,
    count_by_key,
    create_age_threshold,
    days_ago,
    extract_fields,
    filter_map,
    flatten,
    group_by,
    is_older_than,
    paginate,
    parse_iso_date,
    partition,
    pipe,
    pluck,
    safe_get,
)


class TestFunctionalUtilities:
    """Test functional programming utilities."""

    def test_compose(self):
        """Test function composition (right to left)."""
        f = compose(str.upper, str.strip)
        assert f("  hello  ") == "HELLO"

    def test_pipe(self):
        """Test function pipeline (left to right)."""
        f = pipe(str.strip, str.upper)
        assert f("  hello  ") == "HELLO"

    def test_filter_map(self):
        """Test filter and map in one pass."""
        items = [1, 2, 3, 4, 5]
        result = filter_map(
            lambda x: x % 2 == 0,  # Filter even numbers
            lambda x: x * 2,  # Double them
            items,
        )
        assert result == [4, 8]

    def test_partition(self):
        """Test partitioning a list."""
        items = [1, 2, 3, 4, 5]
        evens, odds = partition(lambda x: x % 2 == 0, items)
        assert evens == [2, 4]
        assert odds == [1, 3, 5]

    def test_flatten(self):
        """Test flattening nested lists."""
        nested = [[1, 2], [3, 4], [5]]
        assert flatten(nested) == [1, 2, 3, 4, 5]

    def test_group_by(self):
        """Test grouping items by a key function."""
        items = [
            {"type": "A", "value": 1},
            {"type": "B", "value": 2},
            {"type": "A", "value": 3},
        ]
        groups = group_by(lambda x: x["type"], items)
        assert len(groups["A"]) == 2
        assert len(groups["B"]) == 1

    def test_pluck(self):
        """Test extracting a field from dictionaries."""
        items = [{"name": "Alice"}, {"name": "Bob"}]
        names = pluck("name", items)
        assert names == ["Alice", "Bob"]


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

    def test_days_ago(self):
        """Test days_ago calculation."""
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        past = datetime(2024, 1, 25, tzinfo=timezone.utc)
        assert days_ago(past, reference=now) == 7

    def test_is_older_than(self):
        """Test is_older_than predicate."""
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        past = datetime(2024, 1, 20, tzinfo=timezone.utc)
        assert is_older_than(past, 7, reference=now) is True
        assert is_older_than(past, 20, reference=now) is False

    def test_create_age_threshold(self):
        """Test creating age threshold."""
        now = datetime(2024, 2, 1, tzinfo=timezone.utc)
        threshold = create_age_threshold(7, reference=now)
        expected = now - timedelta(days=7)
        assert threshold == expected


class TestDataExtraction:
    """Test data extraction helpers."""

    def test_safe_get_simple(self):
        """Test safe_get with simple path."""
        obj = {"name": "Alice"}
        assert safe_get(obj, "name") == "Alice"
        assert safe_get(obj, "age", 0) == 0

    def test_safe_get_nested(self):
        """Test safe_get with nested path."""
        obj = {"user": {"profile": {"name": "Alice"}}}
        assert safe_get(obj, "user.profile.name") == "Alice"
        assert safe_get(obj, "user.profile.age", 0) == 0

    def test_extract_fields(self):
        """Test extracting multiple fields."""
        obj = {"user": {"name": "Alice", "age": 30}}
        fields = {
            "username": "user.name",
            "user_age": "user.age",
            "city": ("user.city", "Unknown"),
        }
        result = extract_fields(obj, fields)
        assert result["username"] == "Alice"
        assert result["user_age"] == 30
        assert result["city"] == "Unknown"


class TestResultAggregation:
    """Test result aggregation functions."""

    def test_count_by_key(self):
        """Test counting by key."""
        items = [
            {"type": "A"},
            {"type": "B"},
            {"type": "A"},
            {"type": "A"},
        ]
        counts = count_by_key(items, "type")
        assert counts["A"] == 3
        assert counts["B"] == 1
