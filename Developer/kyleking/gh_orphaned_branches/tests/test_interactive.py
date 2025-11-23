"""Tests for interactive CLI functionality."""

import pytest
from rich.console import Console

from gh_orphaned_branches.interactive import (
    _format_commit_summary,
    _select_branches_interactive,
    handle_batch_delete,
    handle_stacked_prs,
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


@pytest.mark.parametrize("selection,branches,expected", [
    ("", ["a", "b", "c"], []),
    ("1", ["a", "b", "c"], ["a"]),
    ("1,3", ["a", "b", "c"], ["a", "c"]),
    ("all", ["a", "b", "c"], ["a", "b", "c"]),
    ("1-3", ["a", "b", "c"], ["a", "b", "c"]),
])
def test_select_branches_interactive(monkeypatch, selection, branches, expected):
    """Test interactive branch selection."""
    monkeypatch.setattr("gh_orphaned_branches.interactive.Prompt.ask", lambda *args, **kwargs: selection)
    console = Console()
    result = _select_branches_interactive(branches, console)
    assert result == expected


def test_select_branches_interactive_invalid(monkeypatch):
    """Test invalid branch selection."""
    monkeypatch.setattr("gh_orphaned_branches.interactive.Prompt.ask", lambda *args, **kwargs: "invalid")
    console = Console()
    result = _select_branches_interactive(["a", "b", "c"], console)
    assert result == []


def test_handle_stacked_prs_too_few(monkeypatch):
    """Test stacked PRs with less than 2 branches."""
    console = Console()
    result = handle_stacked_prs("owner", "repo", ["branch1"], "main", console)
    assert result == 0


def test_handle_stacked_prs_cancelled(monkeypatch):
    """Test stacked PRs when user cancels."""
    def mock_calculate(owner, repo, branches, default):
        return [("main", "branch1"), ("branch1", "branch2")]

    monkeypatch.setattr("gh_orphaned_branches.interactive.calculate_stacked_pr_order", mock_calculate)
    monkeypatch.setattr("gh_orphaned_branches.interactive.Confirm.ask", lambda *args, **kwargs: False)

    console = Console()
    result = handle_stacked_prs("owner", "repo", ["branch1", "branch2"], "main", console)
    assert result == 0


def test_handle_stacked_prs_success(monkeypatch):
    """Test successful stacked PR creation."""
    def mock_calculate(owner, repo, branches, default):
        return [("main", "branch1"), ("branch1", "branch2")]

    created_prs = []

    def mock_create_pr(owner, repo, title, head, base, body, client=None):
        created_prs.append((base, head))
        return {"number": len(created_prs), "html_url": f"http://pr/{len(created_prs)}"}

    prompt_responses = iter(["yes", "PR1", "", "PR2", ""])

    def mock_prompt(*args, **kwargs):
        return next(prompt_responses)

    monkeypatch.setattr("gh_orphaned_branches.interactive.calculate_stacked_pr_order", mock_calculate)
    monkeypatch.setattr("gh_orphaned_branches.interactive.Confirm.ask", lambda *args, **kwargs: True)
    monkeypatch.setattr("gh_orphaned_branches.interactive.Prompt.ask", mock_prompt)
    monkeypatch.setattr("gh_orphaned_branches.interactive.create_pull_request", mock_create_pr)

    console = Console()
    result = handle_stacked_prs("owner", "repo", ["branch1", "branch2"], "main", console)
    assert result == 2
    assert created_prs == [("main", "branch1"), ("branch1", "branch2")]
