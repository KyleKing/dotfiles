"""Tests for branch graph analysis."""

import pytest
from rich.console import Console

from gh_orphaned_branches.graph import (
    _build_branch_relationships,
    _compare_branch_pair,
    _find_base_branch,
    calculate_stacked_pr_order,
    visualize_branch_graph,
    show_branch_comparison_matrix,
    export_to_dot,
)


def test_compare_branch_pair(monkeypatch):
    """Test comparing two branches."""
    def mock_compare(owner, repo, base, head, client=None):
        if base == "main" and head == "feature":
            return {
                "ahead_by": 5,
                "behind_by": 0,
                "status": "ahead",
            }
        return {"ahead_by": 0, "behind_by": 0, "status": "identical"}

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)

    result = _compare_branch_pair("owner", "repo", "main", "feature")
    assert result["ahead"] == 5
    assert result["behind"] == 0
    assert result["can_compare"] is True


def test_compare_branch_pair_error(monkeypatch):
    """Test comparing branches when API fails."""
    def mock_compare_error(owner, repo, base, head, client=None):
        raise RuntimeError("API error")

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare_error)

    result = _compare_branch_pair("owner", "repo", "main", "feature")
    assert result["can_compare"] is False
    assert result["status"] == "error"


def test_find_base_branch():
    """Test finding the best base branch for a branch."""
    dependencies = {
        "feature-c": [("main", 10), ("feature-a", 3), ("feature-b", 5)],
        "feature-b": [("main", 7)],
        "feature-a": [("main", 4)],
    }

    assert _find_base_branch("feature-c", dependencies) == "feature-a"
    assert _find_base_branch("feature-b", dependencies) == "main"
    assert _find_base_branch("feature-unknown", dependencies) is None


def test_calculate_stacked_pr_order_empty():
    """Test stacked PR calculation with no branches."""
    result = calculate_stacked_pr_order("owner", "repo", [], "main")
    assert result == []


def test_calculate_stacked_pr_order(monkeypatch):
    """Test calculating stacked PR order."""
    def mock_compare(owner, repo, base, head, client=None):
        comparisons = {
            ("main", "feature-a"): {"ahead_by": 4, "behind_by": 0, "status": "ahead"},
            ("main", "feature-b"): {"ahead_by": 7, "behind_by": 0, "status": "ahead"},
            ("main", "feature-c"): {"ahead_by": 10, "behind_by": 0, "status": "ahead"},
            ("feature-a", "feature-b"): {"ahead_by": 3, "behind_by": 0, "status": "ahead"},
            ("feature-b", "feature-c"): {"ahead_by": 3, "behind_by": 0, "status": "ahead"},
            ("feature-a", "feature-c"): {"ahead_by": 6, "behind_by": 0, "status": "ahead"},
            ("feature-b", "feature-a"): {"ahead_by": 0, "behind_by": 3, "status": "behind"},
            ("feature-c", "feature-a"): {"ahead_by": 0, "behind_by": 6, "status": "behind"},
            ("feature-c", "feature-b"): {"ahead_by": 0, "behind_by": 3, "status": "behind"},
        }
        return comparisons.get((base, head), {"ahead_by": 0, "behind_by": 0, "status": "identical"})

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)

    result = calculate_stacked_pr_order(
        "owner", "repo", ["feature-a", "feature-b", "feature-c"], "main"
    )

    assert len(result) == 3
    assert ("main", "feature-a") in result
    assert ("feature-a", "feature-b") in result
    assert ("feature-b", "feature-c") in result


def test_build_branch_relationships(monkeypatch):
    """Test building branch relationships."""
    def mock_compare(owner, repo, base, head, client=None):
        if head == "feature-a":
            return {"ahead_by": 5, "behind_by": 0, "commits": []}
        return {"ahead_by": 0, "behind_by": 1, "commits": []}

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)

    result = _build_branch_relationships(
        "owner", "repo", ["main", "feature-a", "feature-b"], "main"
    )

    assert "feature-a" in result
    assert result["feature-a"]["ahead_of_base"] == 5
    assert result["feature-a"]["behind_base"] == 0

    assert "feature-b" in result
    assert result["feature-b"]["ahead_of_base"] == 0
    assert result["feature-b"]["behind_base"] == 1

    assert "main" not in result


def test_visualize_branch_graph(monkeypatch):
    """Test branch graph visualization."""
    def mock_compare(owner, repo, base, head, client=None):
        return {"ahead_by": 5, "behind_by": 0, "commits": []}

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)

    console = Console()
    visualize_branch_graph("owner", "repo", ["feature-a"], "main", console)


def test_show_branch_comparison_matrix(monkeypatch):
    """Test branch comparison matrix."""
    def mock_compare(owner, repo, base, head, client=None):
        if base == head:
            return {"ahead_by": 0, "behind_by": 0, "status": "identical"}
        return {"ahead_by": 3, "behind_by": 0, "status": "ahead"}

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)

    console = Console()
    show_branch_comparison_matrix("owner", "repo", ["main", "feature-a"], console)


def test_export_to_dot(monkeypatch, tmp_path):
    """Test exporting graph to DOT format."""
    def mock_compare(owner, repo, base, head, client=None):
        return {"ahead_by": 5, "behind_by": 0, "commits": []}

    def mock_merge(owner, repo, base, head, client=None):
        return {"can_merge": True, "status": "ahead", "ahead_by": 5, "behind_by": 0}

    def mock_fetch_details(owner, repo, branch, client=None):
        return {
            "commit": {
                "commit": {
                    "committer": {
                        "date": "2024-01-01T12:00:00Z"
                    }
                }
            }
        }

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)
    monkeypatch.setattr("gh_orphaned_branches.graph.check_merge_conflict", mock_merge)
    monkeypatch.setattr("gh_orphaned_branches.graph.fetch_branch_details", mock_fetch_details)

    output_file = tmp_path / "test.dot"
    result = export_to_dot("owner", "repo", ["feature-a"], "main", str(output_file))

    assert "digraph branches" in result
    assert "main" in result
    assert "feature-a" in result
    assert output_file.exists()

    content = output_file.read_text()
    assert "digraph branches" in content
    assert "lightgreen" in content or "lightblue" in content


def test_build_branch_relationships_with_merge_status(monkeypatch):
    """Test building relationships with merge status."""
    def mock_compare(owner, repo, base, head, client=None):
        return {"ahead_by": 5, "behind_by": 2, "commits": []}

    def mock_merge(owner, repo, base, head, client=None):
        return {"can_merge": False, "status": "diverged", "ahead_by": 5, "behind_by": 2}

    def mock_fetch_details(owner, repo, branch, client=None):
        return {
            "commit": {
                "commit": {
                    "committer": {
                        "date": "2024-01-01T12:00:00Z"
                    }
                }
            }
        }

    monkeypatch.setattr("gh_orphaned_branches.graph.compare_commits", mock_compare)
    monkeypatch.setattr("gh_orphaned_branches.graph.check_merge_conflict", mock_merge)
    monkeypatch.setattr("gh_orphaned_branches.graph.fetch_branch_details", mock_fetch_details)

    result = _build_branch_relationships("owner", "repo", ["feature-a"], "main", include_merge_status=True)

    assert "feature-a" in result
    assert result["feature-a"]["can_merge"] is False
    assert result["feature-a"]["merge_status"] == "diverged"
    assert "age_days" in result["feature-a"]
