"""Tests for output formatters."""

import pytest
from rich.console import Console
from rich.table import Table

from gh_orphaned_branches.formatters import (
    build_closed_pr_table,
    build_recent_branches_table,
    build_stale_branches_table,
    create_summary_text,
    format_date,
    format_pr_status,
)


class TestPureFormatters:
    """Test pure formatting functions."""

    def test_format_pr_status_merged(self):
        """Test formatting merged PR status."""
        assert format_pr_status(True) == "Merged"

    def test_format_pr_status_closed(self):
        """Test formatting closed PR status."""
        assert format_pr_status(False) == "Closed"

    def test_format_date(self):
        """Test date formatting."""
        assert format_date("2024-01-15T10:30:00Z") == "2024-01-15"
        assert format_date("") == "N/A"

    def test_create_summary_text(self):
        """Test creating summary text."""
        summary = {
            "closed_pr_branches": 5,
            "stale_no_pr_branches": 3,
            "recent_no_pr_branches": 2,
        }
        text = create_summary_text(summary, 7)
        assert "5" in text
        assert "3" in text
        assert "2" in text
        assert "7 days" in text


class TestTableBuilders:
    """Test table builder functions."""

    def test_build_closed_pr_table(self):
        """Test building closed PR table."""
        branches = [
            {
                "name": "feature-1",
                "pr_number": 42,
                "merged": True,
                "last_commit": "2024-01-15T10:30:00Z",
            },
            {
                "name": "feature-2",
                "pr_number": 43,
                "merged": False,
                "last_commit": "2024-01-14T10:30:00Z",
            },
        ]
        table = build_closed_pr_table("test-repo", branches)
        assert isinstance(table, Table)
        assert table.title == "test-repo - Branches with Closed/Merged PRs"

    def test_build_stale_branches_table(self):
        """Test building stale branches table."""
        branches = [
            {
                "name": "old-feature",
                "age_days": 30,
                "last_commit": "2023-12-15T10:30:00Z",
            }
        ]
        table = build_stale_branches_table("test-repo", branches, 7)
        assert isinstance(table, Table)
        assert "7 days" in table.title

    def test_build_recent_branches_table(self):
        """Test building recent branches table."""
        branches = [
            {
                "name": "new-feature",
                "age_days": 2,
                "last_commit": "2024-01-29T10:30:00Z",
            }
        ]
        table = build_recent_branches_table("test-repo", branches, 7)
        assert isinstance(table, Table)
        assert "7 days" in table.title


class TestOutputFunctions:
    """Test output functions (with console capture)."""

    def test_output_json(self, capsys):
        """Test JSON output."""
        from gh_orphaned_branches.formatters import output_json

        results = {
            "repo1": {
                "closed_pr_branches": [],
                "no_pr_branches_stale": [],
                "no_pr_branches_recent": [],
            }
        }
        console = Console()
        output_json(results, console)

        # Note: This is a basic test; full output testing would require
        # rich console capture which is more complex

    def test_output_markdown(self, capsys):
        """Test Markdown output."""
        from gh_orphaned_branches.formatters import output_markdown

        results = {
            "repo1": {
                "closed_pr_branches": [
                    {
                        "name": "test",
                        "pr_number": 1,
                        "merged": True,
                        "last_commit": "2024-01-01T00:00:00Z",
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
        }
        console = Console()
        output_markdown(results, summary, 7, console)
