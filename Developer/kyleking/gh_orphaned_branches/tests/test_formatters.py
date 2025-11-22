"""Tests for output formatters."""

import pytest
from rich.console import Console
from rich.table import Table

from gh_orphaned_branches.formatters import (
    _format_date,
    _create_summary_text,
    _build_table,
    output_json,
    output_markdown,
    output_table,
)


@pytest.mark.parametrize("date_str,expected", [
    ("2024-01-15T10:30:00Z", "2024-01-15"),
    ("2023-12-31T23:59:59Z", "2023-12-31"),
    ("", "N/A"),
    (None, "N/A"),
])
def test_format_date(date_str, expected):
    """Test date formatting."""
    assert _format_date(date_str) == expected


def test_create_summary_text():
    """Test creating summary markup text."""
    summary = {
        "closed_pr_branches": 5,
        "stale_no_pr_branches": 3,
        "recent_no_pr_branches": 2,
    }
    text = _create_summary_text(summary, 7)
    assert "[bold]Summary[/bold]" in text
    assert "5" in text
    assert "3" in text
    assert "2" in text
    assert ">7 days" in text
    assert "≤7 days" in text
    assert "Suggested Actions" in text


def test_build_table():
    """Test generic table builder."""
    columns = [("Name", "cyan"), ("Value", "yellow")]
    rows = [("row1", "val1"), ("row2", "val2")]
    table = _build_table("test-repo", "Test Table", columns, rows, "bold red")
    assert isinstance(table, Table)
    assert table.title == "test-repo - Test Table"


def test_output_json():
    """Test JSON output."""
    results = {
        "repo1": {
            "closed_pr_branches": [
                {
                    "name": "test",
                    "pr_number": 1,
                    "pr_title": "Test",
                    "pr_state": "closed",
                    "merged": True,
                    "closed_at": "2024-01-01T00:00:00Z",
                    "last_commit": "2024-01-01T00:00:00Z",
                }
            ],
            "no_pr_branches_stale": [],
            "no_pr_branches_recent": [],
        }
    }
    console = Console()
    output_json(results, console)


def test_output_markdown():
    """Test Markdown output."""
    results = {
        "repo1": {
            "closed_pr_branches": [
                {
                    "name": "feature-1",
                    "pr_number": 42,
                    "merged": True,
                    "last_commit": "2024-01-15T10:00:00Z",
                }
            ],
            "no_pr_branches_stale": [
                {
                    "name": "old-branch",
                    "age_days": 30,
                    "last_commit": "2023-12-01T00:00:00Z",
                }
            ],
            "no_pr_branches_recent": [
                {
                    "name": "new-branch",
                    "age_days": 2,
                    "last_commit": "2024-01-30T00:00:00Z",
                }
            ],
        }
    }
    summary = {
        "closed_pr_branches": 1,
        "stale_no_pr_branches": 1,
        "recent_no_pr_branches": 1,
        "total_repositories": 1,
        "total_orphaned": 3,
    }
    console = Console()
    output_markdown(results, summary, 7, console)


def test_output_table():
    """Test table output."""
    results = {
        "repo1": {
            "closed_pr_branches": [
                {
                    "name": "feature-1",
                    "pr_number": 42,
                    "merged": True,
                    "last_commit": "2024-01-15T10:00:00Z",
                }
            ],
            "no_pr_branches_stale": [],
            "no_pr_branches_recent": [],
        }
    }
    summary = {
        "closed_pr_branches": 1,
        "stale_no_pr_branches": 0,
        "recent_no_pr_branches": 0,
        "total_repositories": 1,
        "total_orphaned": 1,
    }
    console = Console()
    output_table(results, summary, 7, console)
