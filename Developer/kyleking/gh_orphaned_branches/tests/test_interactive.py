"""Tests for interactive CLI functionality."""

import pytest
from rich.console import Console

from gh_orphaned_branches.interactive import (
    _format_commit_summary,
    handle_batch_delete,
)


@pytest.mark.parametrize("commits,limit,expected_contains", [
    ([], 5, "No commits"),
    ([{"sha": "abc123", "commit": {"message": "Fix bug"}}], 5, "abc123"),
    ([{"sha": "abc123", "commit": {"message": "Fix bug\nLong description"}}], 5, "Fix bug"),
])
def test_format_commit_summary(commits, limit, expected_contains):
    """Test commit summary formatting."""
    result = _format_commit_summary(commits, limit)
    assert expected_contains in result


def test_format_commit_summary_with_limit():
    """Test commit summary respects limit."""
    commits = [
        {"sha": f"sha{i}", "commit": {"message": f"Commit {i}"}} for i in range(10)
    ]
    result = _format_commit_summary(commits, limit=3)
    assert "sha0" in result
    assert "sha1" in result
    assert "sha2" in result
    assert "and 7 more" in result


def test_handle_batch_delete_empty(monkeypatch):
    """Test batch delete with no branches."""
    console = Console()
    result = handle_batch_delete("owner", "repo", [], console)
    assert result == 0


def test_handle_batch_delete_cancelled(monkeypatch):
    """Test batch delete when user cancels."""
    monkeypatch.setattr("gh_orphaned_branches.interactive.Confirm.ask", lambda *args, **kwargs: False)
    console = Console()
    result = handle_batch_delete("owner", "repo", ["branch1", "branch2"], console)
    assert result == 0


def test_handle_batch_delete_success(monkeypatch):
    """Test successful batch delete."""
    deleted_branches = []

    def mock_delete(owner, repo, branch, client=None):
        deleted_branches.append(branch)
        return True

    monkeypatch.setattr("gh_orphaned_branches.interactive.Confirm.ask", lambda *args, **kwargs: True)
    monkeypatch.setattr("gh_orphaned_branches.interactive.delete_branch", mock_delete)

    console = Console()
    result = handle_batch_delete("owner", "repo", ["branch1", "branch2"], console)
    assert result == 2
    assert deleted_branches == ["branch1", "branch2"]


def test_handle_batch_delete_partial_failure(monkeypatch):
    """Test batch delete with some failures."""
    def mock_delete(owner, repo, branch, client=None):
        if branch == "branch2":
            raise RuntimeError("Failed")
        return True

    monkeypatch.setattr("gh_orphaned_branches.interactive.Confirm.ask", lambda *args, **kwargs: True)
    monkeypatch.setattr("gh_orphaned_branches.interactive.delete_branch", mock_delete)

    console = Console()
    result = handle_batch_delete("owner", "repo", ["branch1", "branch2", "branch3"], console)
    assert result == 2
