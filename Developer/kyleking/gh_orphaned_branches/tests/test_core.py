"""Tests for core business logic."""

from datetime import datetime, timezone

import pytest

from gh_orphaned_branches.core import (
    add_to_results,
    calculate_summary,
    classify_branch,
    create_branch_info,
    create_closed_pr_branch_info,
    create_empty_results,
    extract_commit_date,
    filter_non_empty_results,
    has_orphaned_branches,
    is_default_branch,
    is_pr_closed,
    is_pr_merged,
)


class TestPurePredicates:
    """Test pure predicate functions."""

    def test_is_default_branch(self):
        """Test default branch checking."""
        assert is_default_branch("main", "main") is True
        assert is_default_branch("feature", "main") is False

    def test_is_pr_closed(self, sample_pr_closed, sample_pr_open):
        """Test PR closed checking."""
        assert is_pr_closed(sample_pr_closed) is True
        assert is_pr_closed(sample_pr_open) is False

    def test_is_pr_merged(self, sample_pr_closed, sample_pr_open):
        """Test PR merged checking."""
        assert is_pr_merged(sample_pr_closed) is True
        assert is_pr_merged(sample_pr_open) is False


class TestDataTransformation:
    """Test data transformation functions."""

    def test_extract_commit_date(self, sample_branch_details):
        """Test extracting commit date."""
        dt = extract_commit_date(sample_branch_details)
        assert isinstance(dt, datetime)
        assert dt.year == 2024

    def test_create_branch_info(self):
        """Test creating branch info."""
        commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
        info = create_branch_info("feature-branch", commit_date)
        assert info["name"] == "feature-branch"
        assert "age_days" in info
        assert "last_commit" in info

    def test_create_closed_pr_branch_info(self, sample_pr_closed):
        """Test creating closed PR branch info."""
        commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
        info = create_closed_pr_branch_info("feature-branch", sample_pr_closed, commit_date)
        assert info["name"] == "feature-branch"
        assert info["pr_number"] == 42
        assert info["merged"] is True


class TestBranchClassification:
    """Test branch classification logic."""

    def test_classify_branch_no_pr_stale(self):
        """Test classifying a stale branch with no PR."""
        # Old date (90 days ago)
        commit_date = datetime(2023, 11, 1, tzinfo=timezone.utc)
        threshold = datetime(2024, 1, 1, tzinfo=timezone.utc)
        pulls = []

        category, info = classify_branch("old-feature", commit_date, pulls, threshold)
        assert category == "stale_no_pr"
        assert info["name"] == "old-feature"

    def test_classify_branch_no_pr_recent(self):
        """Test classifying a recent branch with no PR."""
        # Recent date
        commit_date = datetime(2024, 1, 25, tzinfo=timezone.utc)
        threshold = datetime(2024, 1, 1, tzinfo=timezone.utc)
        pulls = []

        category, info = classify_branch("new-feature", commit_date, pulls, threshold)
        assert category == "recent_no_pr"
        assert info["name"] == "new-feature"

    def test_classify_branch_closed_pr(self, sample_pr_closed):
        """Test classifying a branch with closed PR."""
        commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
        threshold = datetime(2023, 12, 1, tzinfo=timezone.utc)
        pulls = [sample_pr_closed]

        category, info = classify_branch("feature", commit_date, pulls, threshold)
        assert category == "closed_pr"
        assert info["pr_number"] == 42

    def test_classify_branch_open_pr(self, sample_pr_open):
        """Test classifying a branch with open PR (active)."""
        commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
        threshold = datetime(2023, 12, 1, tzinfo=timezone.utc)
        pulls = [sample_pr_open]

        category, info = classify_branch("feature", commit_date, pulls, threshold)
        assert category == "active"


class TestResultsManagement:
    """Test results management functions."""

    def test_create_empty_results(self):
        """Test creating empty results."""
        results = create_empty_results()
        assert len(results["closed_pr_branches"]) == 0
        assert len(results["no_pr_branches_stale"]) == 0
        assert len(results["no_pr_branches_recent"]) == 0

    def test_add_to_results_closed_pr(self):
        """Test adding a closed PR branch to results."""
        results = create_empty_results()
        branch_info = {
            "name": "feature",
            "pr_number": 42,
            "pr_title": "Test",
            "pr_state": "closed",
            "merged": True,
            "closed_at": "2024-01-15T10:00:00Z",
            "last_commit": "2024-01-01T12:00:00Z",
        }
        new_results = add_to_results(results, "closed_pr", branch_info)
        assert len(new_results["closed_pr_branches"]) == 1
        # Original should be unchanged (immutability)
        assert len(results["closed_pr_branches"]) == 0

    def test_has_orphaned_branches_empty(self):
        """Test has_orphaned_branches with empty results."""
        results = create_empty_results()
        assert has_orphaned_branches(results) is False

    def test_has_orphaned_branches_with_data(self):
        """Test has_orphaned_branches with data."""
        results = create_empty_results()
        results["closed_pr_branches"].append(
            {
                "name": "test",
                "pr_number": 1,
                "pr_title": "Test",
                "pr_state": "closed",
                "merged": True,
                "closed_at": "2024-01-01T00:00:00Z",
                "last_commit": "2024-01-01T00:00:00Z",
            }
        )
        assert has_orphaned_branches(results) is True

    def test_filter_non_empty_results(self):
        """Test filtering non-empty results."""
        all_results = {
            "repo1": create_empty_results(),
            "repo2": create_empty_results(),
        }
        all_results["repo2"]["closed_pr_branches"].append(
            {
                "name": "test",
                "pr_number": 1,
                "pr_title": "Test",
                "pr_state": "closed",
                "merged": True,
                "closed_at": "2024-01-01T00:00:00Z",
                "last_commit": "2024-01-01T00:00:00Z",
            }
        )

        filtered = filter_non_empty_results(all_results)
        assert "repo1" not in filtered
        assert "repo2" in filtered


class TestSummaryStatistics:
    """Test summary calculation."""

    def test_calculate_summary_empty(self):
        """Test calculating summary with no results."""
        results = {}
        summary = calculate_summary(results)
        assert summary["closed_pr_branches"] == 0
        assert summary["total_repositories"] == 0

    def test_calculate_summary_with_data(self):
        """Test calculating summary with data."""
        results = {
            "repo1": create_empty_results(),
            "repo2": create_empty_results(),
        }

        # Add some data
        results["repo1"]["closed_pr_branches"] = [
            {
                "name": "test1",
                "pr_number": 1,
                "pr_title": "Test",
                "pr_state": "closed",
                "merged": True,
                "closed_at": "2024-01-01T00:00:00Z",
                "last_commit": "2024-01-01T00:00:00Z",
            },
            {
                "name": "test2",
                "pr_number": 2,
                "pr_title": "Test",
                "pr_state": "closed",
                "merged": True,
                "closed_at": "2024-01-01T00:00:00Z",
                "last_commit": "2024-01-01T00:00:00Z",
            },
        ]
        results["repo2"]["no_pr_branches_stale"] = [
            {"name": "old", "last_commit": "2023-01-01T00:00:00Z", "age_days": 90}
        ]

        summary = calculate_summary(results)
        assert summary["closed_pr_branches"] == 2
        assert summary["stale_no_pr_branches"] == 1
        assert summary["total_repositories"] == 2
        assert summary["total_orphaned"] == 3
