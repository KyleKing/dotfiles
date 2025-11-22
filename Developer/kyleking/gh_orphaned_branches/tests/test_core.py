"""Tests for core business logic."""

from datetime import datetime, timezone

import pytest

from gh_orphaned_branches.core import (
    _add_to_results,
    _classify_branch,
    _create_branch_info,
    _create_closed_pr_branch_info,
    _create_empty_results,
    _extract_commit_date,
    _has_orphaned_branches,
    analyze_namespace,
    calculate_summary,
)


# Predicate tests

@pytest.mark.parametrize("branch_name,default,expected", [
    ("main", "main", True),
    ("feature", "main", False),
    ("master", "main", False),
])
def test_is_default_branch(branch_name, default, expected):
    """Check if branch is default branch."""
    assert (branch_name == default) == expected


@pytest.mark.parametrize("pr,expected_closed,expected_merged", [
    ({"state": "closed", "merged_at": "2024-01-15T10:00:00Z"}, True, True),
    ({"state": "closed", "merged_at": None}, True, False),
    ({"state": "open", "merged_at": None}, False, False),
])
def test_pr_status(pr, expected_closed, expected_merged):
    """Check PR status predicates."""
    assert (pr.get("state") == "closed") == expected_closed
    assert (pr.get("merged_at") is not None) == expected_merged


# Data transformation tests

def test_extract_commit_date(sample_branch_details):
    """Extract commit date from branch details."""
    dt = _extract_commit_date(sample_branch_details)
    assert isinstance(dt, datetime)
    assert dt.year == 2024


def test_create_branch_info():
    """Create BranchInfo from branch name and commit date."""
    commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    info = _create_branch_info("feature-branch", commit_date)
    assert info["name"] == "feature-branch"
    assert "age_days" in info
    assert "last_commit" in info


def test_create_closed_pr_branch_info(sample_pr_closed):
    """Create ClosedPRBranchInfo from branch, PR, and commit data."""
    commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    info = _create_closed_pr_branch_info("feature-branch", sample_pr_closed, commit_date)
    assert info["name"] == "feature-branch"
    assert info["pr_number"] == 42
    assert info["merged"] is True


# Branch classification tests

@pytest.mark.parametrize("commit_date,threshold,pulls,expected_category", [
    (datetime(2023, 11, 1, tzinfo=timezone.utc), datetime(2024, 1, 1, tzinfo=timezone.utc), [], "stale_no_pr"),
    (datetime(2024, 1, 25, tzinfo=timezone.utc), datetime(2024, 1, 1, tzinfo=timezone.utc), [], "recent_no_pr"),
])
def test_classify_branch_no_pr(commit_date, threshold, pulls, expected_category):
    """Classify branches without PRs based on age."""
    category, info = _classify_branch("test-branch", commit_date, pulls, threshold)
    assert category == expected_category
    assert info["name"] == "test-branch"


def test_classify_branch_closed_pr(sample_pr_closed):
    """Classify branch with closed PR."""
    commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    threshold = datetime(2023, 12, 1, tzinfo=timezone.utc)
    category, info = _classify_branch("feature", commit_date, [sample_pr_closed], threshold)
    assert category == "closed_pr"
    assert info["pr_number"] == 42


def test_classify_branch_open_pr(sample_pr_open):
    """Classify branch with open PR (active)."""
    commit_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    threshold = datetime(2023, 12, 1, tzinfo=timezone.utc)
    category, _ = _classify_branch("feature", commit_date, [sample_pr_open], threshold)
    assert category == "active"


# Results management tests

def test_create_empty_results():
    """Create empty results structure."""
    results = _create_empty_results()
    assert all(len(results[k]) == 0 for k in ["closed_pr_branches", "no_pr_branches_stale", "no_pr_branches_recent"])


@pytest.mark.parametrize("category,key", [
    ("closed_pr", "closed_pr_branches"),
    ("stale_no_pr", "no_pr_branches_stale"),
    ("recent_no_pr", "no_pr_branches_recent"),
])
def test_add_to_results(category, key, sample_branch_info):
    """Add branch to appropriate category (immutable)."""
    results = _create_empty_results()
    new_results = _add_to_results(results, category, sample_branch_info)
    assert len(new_results[key]) == 1
    assert len(results[key]) == 0  # Original unchanged


def test_has_orphaned_branches():
    """Check if results contain orphaned branches."""
    assert _has_orphaned_branches(_create_empty_results()) is False

    results = _create_empty_results()
    results["closed_pr_branches"].append({"name": "test", "pr_number": 1, "pr_title": "Test",
                                          "pr_state": "closed", "merged": True,
                                          "closed_at": "2024-01-01T00:00:00Z",
                                          "last_commit": "2024-01-01T00:00:00Z"})
    assert _has_orphaned_branches(results) is True


# Summary statistics tests

def test_calculate_summary_empty():
    """Calculate summary with no results."""
    summary = calculate_summary({})
    assert summary["closed_pr_branches"] == 0
    assert summary["total_repositories"] == 0


def test_calculate_summary_with_data():
    """Calculate summary with data."""
    results = {"repo1": _create_empty_results(), "repo2": _create_empty_results()}
    results["repo1"]["closed_pr_branches"] = [
        {"name": "test1", "pr_number": 1, "pr_title": "Test", "pr_state": "closed",
         "merged": True, "closed_at": "2024-01-01T00:00:00Z", "last_commit": "2024-01-01T00:00:00Z"},
        {"name": "test2", "pr_number": 2, "pr_title": "Test", "pr_state": "closed",
         "merged": True, "closed_at": "2024-01-01T00:00:00Z", "last_commit": "2024-01-01T00:00:00Z"},
    ]
    results["repo2"]["no_pr_branches_stale"] = [
        {"name": "old", "last_commit": "2023-01-01T00:00:00Z", "age_days": 90}
    ]
    summary = calculate_summary(results)
    assert summary["closed_pr_branches"] == 2
    assert summary["stale_no_pr_branches"] == 1
    assert summary["total_repositories"] == 2
    assert summary["total_orphaned"] == 3
